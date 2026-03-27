#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib.sh"

MODE="${1:-youtube}"
OUTPUT_PATH="${2:-}"
INPUT_SOURCE_MODE="${3:-rtsp}"
FILTER_MODE="${4:-normal}"
CALIBRATION_VIEW="${5:-equirect}"

load_config
require_cmd ffmpeg ffprobe timeout sed awk grep date
check_required_settings "${MODE}"

if ! acquire_process_lock "${STREAM_LOCK_DIR}" "stream" "$$"; then
  holder_pid="$(cat "${STREAM_LOCK_DIR}/pid" 2>/dev/null || true)"
  log ERROR "No se puede lanzar ffmpeg: stream lock activo por PID ${holder_pid:-desconocido}"
  exit 1
fi

cleanup_stream_lock() {
  release_process_lock "${STREAM_LOCK_DIR}" "$$"
}

trap cleanup_stream_lock EXIT

mapfile -t RTSP_TIMEOUT_ARGS < <(ffmpeg_rtsp_timeout_args)

RUN_ID="$(timestamp)"
if [[ "${MODE}" == "local" ]]; then
  LOG_FILE="${TEST_LOG_DIR}/stream_${MODE}_${RUN_ID}.log"
else
  LOG_FILE="${OPS_LOG_DIR}/stream_${MODE}_${RUN_ID}.log"
fi

rm -f "${PROGRESS_FILE}" "${PID_FILE}" "${CURRENT_LOG_FILE}"
printf '%s\n' "${LOG_FILE}" > "${CURRENT_LOG_FILE}"

log_project_process_counts "Estado previo de run_ffmpeg_once" "$$" | tee -a "${LOG_FILE}"
log INFO "Parando instancia previa relacionada con este stream" | tee -a "${LOG_FILE}"
terminate_project_stream_processes "pre-lanzamiento run_ffmpeg_once"
if ! wait_for_project_ffmpeg_stop 20 "pre-lanzamiento run_ffmpeg_once"; then
  exit 1
fi
log_project_process_counts "Estado tras saneamiento de run_ffmpeg_once" "$$" | tee -a "${LOG_FILE}"
log_active_stream_pid "PID activo tras saneamiento" | tee -a "${LOG_FILE}"

if ! verify_single_ffmpeg_or_fail "pre-lanzamiento run_ffmpeg_once"; then
  exit 1
fi

if [[ "${MODE}" == "youtube" ]]; then
  if [[ ("${OUTPUT_MODE}" == "dual" || "${OUTPUT_MODE}" == "stream") && (-z "${STREAM_KEY}" || "${STREAM_KEY}" == "REEMPLAZAR_CON_TU_STREAM_KEY") ]]; then
    echo "STREAM_KEY no configurada" >&2
    exit 1
  fi
  TARGET="$(build_tee_target)"
elif [[ "${MODE}" == "local" ]]; then
  if [[ -z "${OUTPUT_PATH}" ]]; then
    OUTPUT_PATH="${ARTIFACTS_TEST_DIR}/local_test_${RUN_ID}.mp4"
  fi
  TARGET="${OUTPUT_PATH}"
else
  echo "Modo no soportado: ${MODE}" >&2
  exit 1
fi

log INFO "Lanzando ffmpeg en modo ${MODE}"
print_pipeline_summary | tee -a "${LOG_FILE}"
if [[ "${FILTER_MODE}" == "calibration" ]]; then
  log INFO "Modo calibracion activo (${CALIBRATION_VIEW})" | tee -a "${LOG_FILE}"
fi
prepare_runtime_crops "${INPUT_SOURCE_MODE}" "${FILTER_MODE}" "${CALIBRATION_VIEW}" \
  > >(tee -a "${LOG_FILE}") \
  2> >(tee -a "${LOG_FILE}" >&2)

if [[ "${INPUT_SOURCE_MODE}" == "mock" ]]; then
  cmd=(
    ffmpeg
    -hide_banner
    -loglevel info
    -stats_period 10
    -progress "${PROGRESS_FILE}"
    -f lavfi
    -i "testsrc2=size=3840x2160:rate=${FPS}"
    -f lavfi
    -i "testsrc2=size=3840x2160:rate=${FPS},hue=s=0"
    -f lavfi
    -i "anullsrc=channel_layout=${AUDIO_CHANNEL_LAYOUT}:sample_rate=${AUDIO_SAMPLE_RATE}"
    -filter_complex "${FILTER_COMPLEX}"
    -map "[v]"
    -map 2:a
    -c:v "${VIDEO_CODEC}"
    -pix_fmt "${PIX_FMT}"
    -r "${FPS}"
    -g "${GOP}"
    -keyint_min "${GOP}"
    -profile:v "${X264_PROFILE}"
    -level:v "${X264_LEVEL}"
    -b:v "${BITRATE_VIDEO}"
    -minrate "${MINRATE_VIDEO}"
    -maxrate "${MAXRATE_VIDEO}"
    -bufsize "${BUFSIZE_VIDEO}"
    -c:a aac
    -ar "${AUDIO_SAMPLE_RATE}"
    -b:a "${BITRATE_AUDIO}"
    -ac 2
  )
else
  cmd=(
    ffmpeg
    -hide_banner
    -loglevel info
    -stats_period 10
    -progress "${PROGRESS_FILE}"
  )

  append_rtsp_input() {
    local url="$1"
    cmd+=(
      -thread_queue_size "${THREAD_QUEUE_SIZE}"
      -rtsp_transport "${RTSP_TRANSPORT}"
      "${RTSP_TIMEOUT_ARGS[@]}"
      -analyzeduration "${INPUT_ANALYZE_DURATION_US}"
      -probesize "${INPUT_PROBE_SIZE}"
      -fflags +genpts+discardcorrupt
      -i "${url}"
    )
  }

  audio_map_index=2
  if [[ "${FILTER_MODE}" == "calibration" && "${CALIBRATION_VIEW}" == "cam1" ]]; then
    append_rtsp_input "${URL_RTSP_CAM1}"
    audio_map_index=1
  elif [[ "${FILTER_MODE}" == "calibration" && "${CALIBRATION_VIEW}" == "cam2" ]]; then
    append_rtsp_input "${URL_RTSP_CAM2}"
    audio_map_index=1
  else
    append_rtsp_input "${URL_RTSP_CAM1}"
    append_rtsp_input "${URL_RTSP_CAM2}"
  fi

  cmd+=(
    -f lavfi
    -i "anullsrc=channel_layout=${AUDIO_CHANNEL_LAYOUT}:sample_rate=${AUDIO_SAMPLE_RATE}"
    -filter_complex "${FILTER_COMPLEX}"
    -map "[v]"
    -map "${audio_map_index}:a"
    -c:v "${VIDEO_CODEC}"
    -pix_fmt "${PIX_FMT}"
    -r "${FPS}"
    -g "${GOP}"
    -keyint_min "${GOP}"
    -profile:v "${X264_PROFILE}"
    -level:v "${X264_LEVEL}"
    -b:v "${BITRATE_VIDEO}"
    -minrate "${MINRATE_VIDEO}"
    -maxrate "${MAXRATE_VIDEO}"
    -bufsize "${BUFSIZE_VIDEO}"
    -c:a aac
    -ar "${AUDIO_SAMPLE_RATE}"
    -b:a "${BITRATE_AUDIO}"
    -ac 2
  )
fi

if [[ "${VIDEO_CODEC}" == "libx264" ]]; then
  cmd+=(
    -preset "${X264_PRESET}"
    -crf "${X264_CRF}"
    -bf "${X264_BFRAMES}"
    -refs "${X264_REF}"
    -x264-params "scenecut=0:open-gop=0"
  )
fi

if [[ "${MODE}" == "youtube" ]]; then
  cmd+=(
    -f tee
    "${TARGET}"
  )
else
  cmd+=(
    -t "${LOCAL_TEST_DURATION_SECONDS}"
    -y
    -movflags +faststart
    "${TARGET}"
  )
fi

{
  printf 'Comando ffmpeg:\n'
  printf '%q ' "${cmd[@]}"
  printf '\n\n'
} | while IFS= read -r line; do
  sanitize_log_text "${line}"
done >> "${LOG_FILE}"

"${cmd[@]}" >> "${LOG_FILE}" 2>&1 &
FFMPEG_PID=$!
printf '%s\n' "${FFMPEG_PID}" > "${PID_FILE}"
log INFO "ffmpeg lanzado con PID ${FFMPEG_PID}" | tee -a "${LOG_FILE}"

active_count="$(count_active_project_ffmpeg)"
if (( active_count != 1 )); then
  log ERROR "Conteo inesperado tras lanzamiento: ffmpeg_activos=${active_count}" | tee -a "${LOG_FILE}"
  pgrep -af -- "ffmpeg .*${PROGRESS_FILE}" 2>/dev/null | tee -a "${LOG_FILE}" || true
  terminate_project_stream_processes "post-lanzamiento inconsistente"
  wait_for_project_stream_stop 20 "post-lanzamiento inconsistente" || true
  exit 1
fi

log_active_stream_pid "PID activo actual" | tee -a "${LOG_FILE}"
pgrep -af -- "ffmpeg .*${PROGRESS_FILE}" 2>/dev/null | tee -a "${LOG_FILE}" || true

set +e
wait "${FFMPEG_PID}"
EXIT_CODE=$?
set -e
log INFO "ffmpeg finalizo con codigo ${EXIT_CODE}" | tee -a "${LOG_FILE}"
rm -f "${PID_FILE}"
rm -f "${CURRENT_LOG_FILE}"

if [[ "${MODE}" == "local" ]]; then
  printf '%s\n' "${TARGET}"
fi

exit "${EXIT_CODE}"
