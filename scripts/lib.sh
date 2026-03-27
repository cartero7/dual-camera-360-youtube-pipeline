#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE_DEFAULT="${PROJECT_DIR}/config/youtube360.env"

CONFIG_FILE="${YOUTUBE360_ENV_FILE:-$CONFIG_FILE_DEFAULT}"

sanitize_rtsp_url() {
  local url="${1:-}"
  printf '%s\n' "${url}" | sed -E 's#^([a-z]+://)([^:@/]+):([^@/]+)@#\1\2:***@#'
}

sanitize_rtmp_target() {
  local value="${1:-}"
  if [[ -n "${STREAM_KEY:-}" ]]; then
    value="${value//${STREAM_KEY}/***}"
  fi
  printf '%s\n' "${value}"
}

sanitize_log_text() {
  local value="${1:-}"

  if [[ -n "${URL_RTSP_CAM1:-}" ]]; then
    value="${value//${URL_RTSP_CAM1}/$(sanitize_rtsp_url "${URL_RTSP_CAM1}")}"
  fi
  if [[ -n "${URL_RTSP_CAM2:-}" ]]; then
    value="${value//${URL_RTSP_CAM2}/$(sanitize_rtsp_url "${URL_RTSP_CAM2}")}"
  fi
  value="$(sanitize_rtmp_target "${value}")"
  printf '%s\n' "${value}"
}

load_config() {
  if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "Config no encontrada: ${CONFIG_FILE}" >&2
    exit 1
  fi

  # shellcheck disable=SC1090
  source "${CONFIG_FILE}"

  AUTO_ADJUST_CROP="${AUTO_ADJUST_CROP:-false}"
  CALIBRATION_DRAW_CIRCLE="${CALIBRATION_DRAW_CIRCLE:-true}"
  CALIBRATION_DRAW_GRID="${CALIBRATION_DRAW_GRID:-true}"
  CALIBRATION_CIRCLE_RADIUS_PERCENT="${CALIBRATION_CIRCLE_RADIUS_PERCENT:-48}"
  CALIBRATION_LINE_THICKNESS="${CALIBRATION_LINE_THICKNESS:-4}"
  CALIBRATION_FONT_SIZE="${CALIBRATION_FONT_SIZE:-36}"
  CALIBRATION_GRID_DIVISIONS="${CALIBRATION_GRID_DIVISIONS:-6}"
  CALIBRATION_CENTER_MARK_SIZE="${CALIBRATION_CENTER_MARK_SIZE:-18}"
  CAM1_FISHEYE_CENTER_OFFSET_X="${CAM1_FISHEYE_CENTER_OFFSET_X:-0}"
  CAM1_FISHEYE_CENTER_OFFSET_Y="${CAM1_FISHEYE_CENTER_OFFSET_Y:-0}"
  CAM2_FISHEYE_CENTER_OFFSET_X="${CAM2_FISHEYE_CENTER_OFFSET_X:-0}"
  CAM2_FISHEYE_CENTER_OFFSET_Y="${CAM2_FISHEYE_CENTER_OFFSET_Y:-0}"
  CALIBRATION_EQUIRECT_SEAM_GUIDE="${CALIBRATION_EQUIRECT_SEAM_GUIDE:-true}"
  CALIBRATION_SWEEP_DURATION_SECONDS="${CALIBRATION_SWEEP_DURATION_SECONDS:-5}"
  CALIBRATION_SWEEP_X_OFFSETS="${CALIBRATION_SWEEP_X_OFFSETS:--20,0,20}"
  CALIBRATION_SWEEP_Y_OFFSETS="${CALIBRATION_SWEEP_Y_OFFSETS:--20,0,20}"
  CALIBRATION_SWEEP_FOVS="${CALIBRATION_SWEEP_FOVS:-180,185,190}"
  CAM1_PRE_ROTATE="${CAM1_PRE_ROTATE:-0}"
  CAM2_PRE_ROTATE="${CAM2_PRE_ROTATE:-0}"
  CAM1_HFLIP="${CAM1_HFLIP:-false}"
  CAM2_HFLIP="${CAM2_HFLIP:-false}"
  CAM1_VFLIP="${CAM1_VFLIP:-false}"
  CAM2_VFLIP="${CAM2_VFLIP:-false}"
  PRE_HSTACK_RADIAL_MASK="${PRE_HSTACK_RADIAL_MASK:-false}"
  PRE_HSTACK_RADIAL_MASK_INNER_RATIO="${PRE_HSTACK_RADIAL_MASK_INNER_RATIO:-0.92}"
  PRE_HSTACK_RADIAL_MASK_OUTER_RATIO="${PRE_HSTACK_RADIAL_MASK_OUTER_RATIO:-0.98}"

  RUNTIME_DIR="${RUNTIME_DIR:-./runtime}"
  ARTIFACTS_DIR="${ARTIFACTS_DIR:-./artifacts}"
  LOGS_CURRENT_DIR="${LOGS_CURRENT_DIR:-${RUNTIME_DIR}/logs/current}"
  LOGS_ARCHIVE_DIR="${LOGS_ARCHIVE_DIR:-${RUNTIME_DIR}/logs/archive}"
  OPS_LOG_DIR="${OPS_LOG_DIR:-${LOG_DIR:-${LOGS_CURRENT_DIR}/ops}}"
  VALIDATION_LOG_DIR="${VALIDATION_LOG_DIR:-${LOGS_CURRENT_DIR}/validation}"
  CALIBRATION_LOG_DIR="${CALIBRATION_LOG_DIR:-${LOGS_CURRENT_DIR}/calibration}"
  DIAGNOSTIC_LOG_DIR="${DIAGNOSTIC_LOG_DIR:-${LOGS_CURRENT_DIR}/diagnostics}"
  TEST_LOG_DIR="${TEST_LOG_DIR:-${LOGS_CURRENT_DIR}/test}"
  STATE_DIR="${STATE_DIR:-${RUNTIME_DIR}/state}"
  RUNTIME_TMP_DIR="${RUNTIME_TMP_DIR:-${RUNTIME_DIR}/tmp}"
  ARTIFACTS_CALIBRATION_DIR="${ARTIFACTS_CALIBRATION_DIR:-${ARTIFACTS_DIR}/calibration}"
  ARTIFACTS_DIAGNOSTICS_DIR="${ARTIFACTS_DIAGNOSTICS_DIR:-${ARTIFACTS_DIR}/diagnostics}"
  ARTIFACTS_TEST_DIR="${ARTIFACTS_TEST_DIR:-${ARTIFACTS_DIR}/test}"
  TMP_DIR="${TMP_DIR:-${ARTIFACTS_TEST_DIR}}"
  RECORDINGS_DIR="${RECORDINGS_DIR:-${RECORDINGS_PATH:-${RUNTIME_DIR}/recordings}}"
  PROGRESS_FILE="${PROGRESS_FILE:-${STATE_DIR}/progress.last}"
  PID_FILE="${PID_FILE:-${STATE_DIR}/ffmpeg.pid}"
  CURRENT_LOG_FILE="${CURRENT_LOG_FILE:-${STATE_DIR}/current_ffmpeg_log.txt}"
  WATCHDOG_LOCK_DIR="${WATCHDOG_LOCK_DIR:-${STATE_DIR}/watchdog.lock}"
  STREAM_LOCK_DIR="${STREAM_LOCK_DIR:-${STATE_DIR}/stream.lock}"

  normalize_project_path() {
    local value="$1"
    if [[ "${value}" == /* ]]; then
      printf '%s\n' "${value}"
    else
      printf '%s\n' "${PROJECT_DIR}/${value#./}"
    fi
  }

  RUNTIME_DIR="$(normalize_project_path "${RUNTIME_DIR}")"
  ARTIFACTS_DIR="$(normalize_project_path "${ARTIFACTS_DIR}")"
  LOGS_CURRENT_DIR="$(normalize_project_path "${LOGS_CURRENT_DIR}")"
  LOGS_ARCHIVE_DIR="$(normalize_project_path "${LOGS_ARCHIVE_DIR}")"
  OPS_LOG_DIR="$(normalize_project_path "${OPS_LOG_DIR}")"
  VALIDATION_LOG_DIR="$(normalize_project_path "${VALIDATION_LOG_DIR}")"
  CALIBRATION_LOG_DIR="$(normalize_project_path "${CALIBRATION_LOG_DIR}")"
  DIAGNOSTIC_LOG_DIR="$(normalize_project_path "${DIAGNOSTIC_LOG_DIR}")"
  TEST_LOG_DIR="$(normalize_project_path "${TEST_LOG_DIR}")"
  STATE_DIR="$(normalize_project_path "${STATE_DIR}")"
  RUNTIME_TMP_DIR="$(normalize_project_path "${RUNTIME_TMP_DIR}")"
  ARTIFACTS_CALIBRATION_DIR="$(normalize_project_path "${ARTIFACTS_CALIBRATION_DIR}")"
  ARTIFACTS_DIAGNOSTICS_DIR="$(normalize_project_path "${ARTIFACTS_DIAGNOSTICS_DIR}")"
  ARTIFACTS_TEST_DIR="$(normalize_project_path "${ARTIFACTS_TEST_DIR}")"
  TMP_DIR="$(normalize_project_path "${TMP_DIR}")"
  RECORDINGS_DIR="$(normalize_project_path "${RECORDINGS_DIR}")"
  PROGRESS_FILE="$(normalize_project_path "${PROGRESS_FILE}")"
  PID_FILE="$(normalize_project_path "${PID_FILE}")"
  CURRENT_LOG_FILE="$(normalize_project_path "${CURRENT_LOG_FILE}")"
  WATCHDOG_LOCK_DIR="$(normalize_project_path "${WATCHDOG_LOCK_DIR}")"
  STREAM_LOCK_DIR="$(normalize_project_path "${STREAM_LOCK_DIR}")"
  LOG_DIR="${OPS_LOG_DIR}"

  mkdir -p \
    "${RUNTIME_DIR}" \
    "${ARTIFACTS_DIR}" \
    "${LOGS_CURRENT_DIR}" \
    "${LOGS_ARCHIVE_DIR}" \
    "${OPS_LOG_DIR}" \
    "${VALIDATION_LOG_DIR}" \
    "${CALIBRATION_LOG_DIR}" \
    "${DIAGNOSTIC_LOG_DIR}" \
    "${TEST_LOG_DIR}" \
    "${STATE_DIR}" \
    "${RUNTIME_TMP_DIR}" \
    "${ARTIFACTS_CALIBRATION_DIR}" \
    "${ARTIFACTS_DIAGNOSTICS_DIR}" \
    "${ARTIFACTS_TEST_DIR}" \
    "${RECORDINGS_DIR}"
}

timestamp() {
  date +"%Y%m%d_%H%M%S"
}

log() {
  local level="$1"
  shift
  printf '[%s] [%s] %s\n' "$(date +'%F %T')" "${level}" "$*"
}

require_cmd() {
  local cmd
  for cmd in "$@"; do
    command -v "${cmd}" >/dev/null 2>&1 || {
      echo "Falta dependencia: ${cmd}" >&2
      exit 1
    }
  done
}

ffmpeg_rtsp_timeout_args() {
  local timeout_us="${RTSP_STIMEOUT_US:-0}"
  local ffmpeg_help=""
  local rtsp_demuxer_help=""

  if [[ -z "${timeout_us}" || "${timeout_us}" == "0" ]]; then
    return 0
  fi

  rtsp_demuxer_help="$(ffmpeg -hide_banner -h demuxer=rtsp 2>&1 || true)"
  if grep -q -- '-timeout' <<<"${rtsp_demuxer_help}"; then
    printf '%s\n' "-timeout" "${timeout_us}"
    return 0
  fi

  if grep -q -- '-stimeout' <<<"${rtsp_demuxer_help}"; then
    printf '%s\n' "-stimeout" "${timeout_us}"
    return 0
  fi

  ffmpeg_help="$(ffmpeg -hide_banner -h full 2>&1 || true)"

  if grep -q -- '-rw_timeout' <<<"${ffmpeg_help}"; then
    printf '%s\n' "-rw_timeout" "${timeout_us}"
    return 0
  fi

  if grep -q -- '-stimeout' <<<"${ffmpeg_help}"; then
    printf '%s\n' "-stimeout" "${timeout_us}"
    return 0
  fi

  if grep -q -- '-timeout' <<<"${ffmpeg_help}"; then
    printf '%s\n' "-timeout" "${timeout_us}"
  fi
}

check_required_settings() {
  local execution_mode="${1:-youtube}"
  local missing=0
  local key
  for key in URL_RTSP_CAM1 URL_RTSP_CAM2 FPS OUTPUT_WIDTH OUTPUT_HEIGHT BITRATE_VIDEO BITRATE_AUDIO GOP CAM1_CROP CAM2_CROP OUTPUT_MODE; do
    if [[ -z "${!key:-}" ]]; then
      echo "Falta variable obligatoria: ${key}" >&2
      missing=1
    fi
  done
  if [[ "${execution_mode}" != "local" && ( "${OUTPUT_MODE}" == "dual" || "${OUTPUT_MODE}" == "stream" ) ]]; then
    for key in YOUTUBE_RTMP_URL STREAM_KEY; do
      if [[ -z "${!key:-}" ]]; then
        echo "Falta variable obligatoria: ${key}" >&2
        missing=1
      fi
    done
  fi
  if [[ "${OUTPUT_MODE}" == "dual" || "${OUTPUT_MODE}" == "record" ]]; then
    if [[ "${RECORDINGS_ENABLED}" != "true" ]]; then
      echo "RECORDINGS_ENABLED debe ser true para OUTPUT_MODE=${OUTPUT_MODE}" >&2
      missing=1
    fi
  fi
  if [[ "${AUTO_ADJUST_CROP}" != "true" && "${AUTO_ADJUST_CROP}" != "false" ]]; then
    echo "AUTO_ADJUST_CROP debe ser true o false" >&2
    missing=1
  fi
  if [[ "${CALIBRATION_DRAW_CIRCLE}" != "true" && "${CALIBRATION_DRAW_CIRCLE}" != "false" ]]; then
    echo "CALIBRATION_DRAW_CIRCLE debe ser true o false" >&2
    missing=1
  fi
  if [[ "${CALIBRATION_DRAW_GRID}" != "true" && "${CALIBRATION_DRAW_GRID}" != "false" ]]; then
    echo "CALIBRATION_DRAW_GRID debe ser true o false" >&2
    missing=1
  fi
  if ! is_positive_integer "${CALIBRATION_CIRCLE_RADIUS_PERCENT}"; then
    echo "CALIBRATION_CIRCLE_RADIUS_PERCENT debe ser > 0" >&2
    missing=1
  fi
  if ! is_positive_integer "${CALIBRATION_LINE_THICKNESS}"; then
    echo "CALIBRATION_LINE_THICKNESS debe ser > 0" >&2
    missing=1
  fi
  if ! is_positive_integer "${CALIBRATION_FONT_SIZE}"; then
    echo "CALIBRATION_FONT_SIZE debe ser > 0" >&2
    missing=1
  fi
  if ! is_positive_integer "${CALIBRATION_GRID_DIVISIONS}"; then
    echo "CALIBRATION_GRID_DIVISIONS debe ser > 0" >&2
    missing=1
  fi
  if ! is_positive_integer "${CALIBRATION_CENTER_MARK_SIZE}"; then
    echo "CALIBRATION_CENTER_MARK_SIZE debe ser > 0" >&2
    missing=1
  fi
  if ! is_integer "${CAM1_FISHEYE_CENTER_OFFSET_X}"; then
    echo "CAM1_FISHEYE_CENTER_OFFSET_X debe ser entero" >&2
    missing=1
  fi
  if ! is_integer "${CAM1_FISHEYE_CENTER_OFFSET_Y}"; then
    echo "CAM1_FISHEYE_CENTER_OFFSET_Y debe ser entero" >&2
    missing=1
  fi
  if ! is_integer "${CAM2_FISHEYE_CENTER_OFFSET_X}"; then
    echo "CAM2_FISHEYE_CENTER_OFFSET_X debe ser entero" >&2
    missing=1
  fi
  if ! is_integer "${CAM2_FISHEYE_CENTER_OFFSET_Y}"; then
    echo "CAM2_FISHEYE_CENTER_OFFSET_Y debe ser entero" >&2
    missing=1
  fi
  if [[ "${CALIBRATION_EQUIRECT_SEAM_GUIDE}" != "true" && "${CALIBRATION_EQUIRECT_SEAM_GUIDE}" != "false" ]]; then
    echo "CALIBRATION_EQUIRECT_SEAM_GUIDE debe ser true o false" >&2
    missing=1
  fi
  if ! is_positive_integer "${CALIBRATION_SWEEP_DURATION_SECONDS}"; then
    echo "CALIBRATION_SWEEP_DURATION_SECONDS debe ser > 0" >&2
    missing=1
  fi
  if ! is_supported_rotate_value "${CAM1_PRE_ROTATE}"; then
    echo "CAM1_PRE_ROTATE debe ser 0, 90, 180 o 270" >&2
    missing=1
  fi
  if ! is_supported_rotate_value "${CAM2_PRE_ROTATE}"; then
    echo "CAM2_PRE_ROTATE debe ser 0, 90, 180 o 270" >&2
    missing=1
  fi
  if ! is_bool_string "${CAM1_HFLIP}"; then
    echo "CAM1_HFLIP debe ser true o false" >&2
    missing=1
  fi
  if ! is_bool_string "${CAM2_HFLIP}"; then
    echo "CAM2_HFLIP debe ser true o false" >&2
    missing=1
  fi
  if ! is_bool_string "${CAM1_VFLIP}"; then
    echo "CAM1_VFLIP debe ser true o false" >&2
    missing=1
  fi
  if ! is_bool_string "${CAM2_VFLIP}"; then
    echo "CAM2_VFLIP debe ser true o false" >&2
    missing=1
  fi
  if ! is_bool_string "${PRE_HSTACK_RADIAL_MASK}"; then
    echo "PRE_HSTACK_RADIAL_MASK debe ser true o false" >&2
    missing=1
  fi
  if ! is_decimal_number "${PRE_HSTACK_RADIAL_MASK_INNER_RATIO}"; then
    echo "PRE_HSTACK_RADIAL_MASK_INNER_RATIO debe ser decimal >= 0" >&2
    missing=1
  fi
  if ! is_decimal_number "${PRE_HSTACK_RADIAL_MASK_OUTER_RATIO}"; then
    echo "PRE_HSTACK_RADIAL_MASK_OUTER_RATIO debe ser decimal >= 0" >&2
    missing=1
  fi
  if is_decimal_number "${PRE_HSTACK_RADIAL_MASK_INNER_RATIO}" && \
     is_decimal_number "${PRE_HSTACK_RADIAL_MASK_OUTER_RATIO}" && \
     ! decimal_gt "${PRE_HSTACK_RADIAL_MASK_OUTER_RATIO}" "${PRE_HSTACK_RADIAL_MASK_INNER_RATIO}"; then
    echo "PRE_HSTACK_RADIAL_MASK_OUTER_RATIO debe ser mayor que PRE_HSTACK_RADIAL_MASK_INNER_RATIO" >&2
    missing=1
  fi
  if [[ "${missing}" -ne 0 ]]; then
    exit 1
  fi
}

rtsp_host_from_url() {
  local url="$1"
  printf '%s\n' "${url}" | sed -E 's#^[a-z]+://([^/@]+@)?([^:/]+).*#\2#'
}

ping_host_if_possible() {
  local host="$1"
  if command -v ping >/dev/null 2>&1; then
    ping -c 1 -W 1 "${host}" >/dev/null 2>&1
  else
    return 0
  fi
}

ffprobe_rtsp() {
  local url="$1"
  timeout 12 ffprobe \
    -v error \
    -rtsp_transport "${RTSP_TRANSPORT}" \
    -show_entries stream=index,codec_name,codec_type,width,height,r_frame_rate,avg_frame_rate,pix_fmt \
    -show_entries format=format_name \
    -of default=noprint_wrappers=1 \
    "${url}"
}

is_non_negative_integer() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

is_positive_integer() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

is_integer() {
  [[ "$1" =~ ^-?[0-9]+$ ]]
}

is_bool_string() {
  [[ "$1" == "true" || "$1" == "false" ]]
}

is_supported_rotate_value() {
  [[ "$1" == "0" || "$1" == "90" || "$1" == "180" || "$1" == "270" ]]
}

is_decimal_number() {
  [[ "$1" =~ ^([0-9]+([.][0-9]+)?|[.][0-9]+)$ ]]
}

decimal_gt() {
  awk -v left="$1" -v right="$2" 'BEGIN { exit !(left > right) }'
}

parse_crop_spec() {
  local crop_spec="$1"
  local extra=""

  PARSED_CROP_W=""
  PARSED_CROP_H=""
  PARSED_CROP_X=""
  PARSED_CROP_Y=""
  PARSED_CROP_ERROR=""

  IFS=':' read -r PARSED_CROP_W PARSED_CROP_H PARSED_CROP_X PARSED_CROP_Y extra <<< "${crop_spec}"

  if [[ -n "${extra}" || -z "${PARSED_CROP_W}" || -z "${PARSED_CROP_H}" || -z "${PARSED_CROP_X}" || -z "${PARSED_CROP_Y}" ]]; then
    PARSED_CROP_ERROR="formato invalido '${crop_spec}', se esperaba ancho:alto:x:y"
    return 1
  fi

  if ! is_positive_integer "${PARSED_CROP_W}"; then
    PARSED_CROP_ERROR="crop_w='${PARSED_CROP_W}' debe ser > 0"
    return 1
  fi

  if ! is_positive_integer "${PARSED_CROP_H}"; then
    PARSED_CROP_ERROR="crop_h='${PARSED_CROP_H}' debe ser > 0"
    return 1
  fi

  if ! is_non_negative_integer "${PARSED_CROP_X}"; then
    PARSED_CROP_ERROR="x='${PARSED_CROP_X}' debe ser >= 0"
    return 1
  fi

  if ! is_non_negative_integer "${PARSED_CROP_Y}"; then
    PARSED_CROP_ERROR="y='${PARSED_CROP_Y}' debe ser >= 0"
    return 1
  fi
}

probe_rtsp_video_dimensions() {
  local url="$1"
  local dims=""
  local attempt=1
  local debug_dims=""

  while (( attempt <= 3 )); do
    dims="$(
      timeout 12 ffprobe \
        -v error \
        -rtsp_transport "${RTSP_TRANSPORT}" \
        -select_streams v:0 \
        -show_entries stream=width,height \
        -of csv=p=0:s=x \
        "${url}" | tr -d '\r' | sed -n '1p'
    )"

    if [[ "${dims}" =~ ^[0-9]+x[0-9]+$ ]]; then
      printf '%s\n' "${dims}"
      return 0
    fi

    sleep 1
    attempt=$((attempt + 1))
  done

  debug_dims="$(
    timeout 15 ffprobe \
      -v debug \
      -rtsp_transport "${RTSP_TRANSPORT}" \
      "${url}" 2>&1 \
      | sed -nE 's/.*Video:[^,]*, [^,]*, ([0-9]+x[0-9]+)( .*)?/\1/p' \
      | sed -n '1p'
  )"

  if [[ "${debug_dims}" =~ ^[0-9]+x[0-9]+$ ]]; then
    log WARN "Fallback de sonda RTSP usado para detectar resolucion: ${url} -> ${debug_dims}"
    printf '%s\n' "${debug_dims}"
    return 0
  fi

  echo "No se pudo detectar la resolucion del stream RTSP: ${url}" >&2
  return 1
}

validate_crop_bounds() {
  local crop_spec="$1"
  local input_w="$2"
  local input_h="$3"
  local issues=()

  CROP_VALIDATION_ERROR=""

  if ! parse_crop_spec "${crop_spec}"; then
    CROP_VALIDATION_ERROR="${PARSED_CROP_ERROR}"
    return 1
  fi

  if (( PARSED_CROP_X + PARSED_CROP_W > input_w )); then
    issues+=("x+crop_w=$((PARSED_CROP_X + PARSED_CROP_W)) excede input_w=${input_w}")
  fi

  if (( PARSED_CROP_Y + PARSED_CROP_H > input_h )); then
    issues+=("y+crop_h=$((PARSED_CROP_Y + PARSED_CROP_H)) excede input_h=${input_h}")
  fi

  if [[ "${#issues[@]}" -ne 0 ]]; then
    CROP_VALIDATION_ERROR="$(printf '%s; ' "${issues[@]}")"
    CROP_VALIDATION_ERROR="${CROP_VALIDATION_ERROR%; }"
    return 1
  fi
}

build_centered_square_crop() {
  local input_w="$1"
  local input_h="$2"
  local side="$input_w"
  local offset_x=0
  local offset_y=0

  if (( input_h < side )); then
    side="${input_h}"
  fi

  offset_x=$(( (input_w - side) / 2 ))
  offset_y=$(( (input_h - side) / 2 ))

  printf '%s\n' "${side}:${side}:${offset_x}:${offset_y}"
}

calibration_color_rgb() {
  case "$1" in
    lime)
      printf '%s\n' "0 255 0"
      ;;
    cyan)
      printf '%s\n' "0 255 255"
      ;;
    yellow)
      printf '%s\n' "255 255 0"
      ;;
    *)
      printf '%s\n' "255 255 255"
      ;;
  esac
}

camera_fisheye_center_offsets() {
  case "$1" in
    CAM1)
      printf '%s %s\n' "${CAM1_FISHEYE_CENTER_OFFSET_X}" "${CAM1_FISHEYE_CENTER_OFFSET_Y}"
      ;;
    CAM2)
      printf '%s %s\n' "${CAM2_FISHEYE_CENTER_OFFSET_X}" "${CAM2_FISHEYE_CENTER_OFFSET_Y}"
      ;;
    *)
      printf '%s\n' "0 0"
      ;;
  esac
}

camera_pre_transform_values() {
  case "$1" in
    CAM1)
      printf '%s %s %s\n' "${CAM1_PRE_ROTATE}" "${CAM1_HFLIP}" "${CAM1_VFLIP}"
      ;;
    CAM2)
      printf '%s %s %s\n' "${CAM2_PRE_ROTATE}" "${CAM2_HFLIP}" "${CAM2_VFLIP}"
      ;;
    *)
      printf '%s\n' "0 false false"
      ;;
  esac
}

camera_transform_summary() {
  local rotate=0
  local hflip=false
  local vflip=false

  read -r rotate hflip vflip <<< "$(camera_pre_transform_values "$1")"
  printf 'rot=%s hflip=%s vflip=%s\n' "${rotate}" "${hflip}" "${vflip}"
}

camera_pre_transform_filters() {
  local camera_name="$1"
  local rotate=0
  local hflip=false
  local vflip=false
  local filters=()

  read -r rotate hflip vflip <<< "$(camera_pre_transform_values "${camera_name}")"

  case "${rotate}" in
    90)
      filters+=("transpose=clock")
      ;;
    180)
      filters+=("hflip" "vflip")
      ;;
    270)
      filters+=("transpose=cclock")
      ;;
  esac

  if [[ "${hflip}" == "true" && "${rotate}" != "180" ]]; then
    filters+=("hflip")
  fi
  if [[ "${vflip}" == "true" && "${rotate}" != "180" ]]; then
    filters+=("vflip")
  fi

  if [[ "${#filters[@]}" -eq 0 ]]; then
    printf '\n'
    return 0
  fi

  printf ',%s' "$(IFS=,; printf '%s' "${filters[*]}")"
}

camera_transformed_dimensions() {
  local camera_name="$1"
  local input_w="$2"
  local input_h="$3"
  local rotate=0
  local hflip=false
  local vflip=false

  read -r rotate hflip vflip <<< "$(camera_pre_transform_values "${camera_name}")"

  if [[ "${rotate}" == "90" || "${rotate}" == "270" ]]; then
    printf '%s\n' "${input_h}x${input_w}"
    return 0
  fi

  printf '%s\n' "${input_w}x${input_h}"
}

build_calibration_circle_segment() {
  local input_label="$1"
  local output_label="$2"
  local circle_label="$3"
  local crop_w="$4"
  local crop_h="$5"
  local color_name="$6"
  local center_x="$7"
  local center_y="$8"
  local min_dim="${crop_w}"
  local radius=0
  local rgb=""
  local color_r=255
  local color_g=255
  local color_b=255

  if (( crop_h < min_dim )); then
    min_dim="${crop_h}"
  fi

  radius=$(( min_dim * CALIBRATION_CIRCLE_RADIUS_PERCENT / 100 ))
  if (( radius >= min_dim / 2 )); then
    radius=$(( (min_dim / 2) - CALIBRATION_LINE_THICKNESS ))
  fi
  if (( radius < CALIBRATION_LINE_THICKNESS )); then
    radius="${CALIBRATION_LINE_THICKNESS}"
  fi

  rgb="$(calibration_color_rgb "${color_name}")"
  read -r color_r color_g color_b <<< "${rgb}"

  cat <<EOF
color=c=black@0.0:s=${crop_w}x${crop_h},format=rgba,geq=r='${color_r}':g='${color_g}':b='${color_b}':a='if(lte(abs(hypot(X-${center_x}\\,Y-${center_y})-${radius})\\,${CALIBRATION_LINE_THICKNESS})\\,255\\,0)'[${circle_label}];
[${input_label}][${circle_label}]overlay=x=0:y=0[${output_label}]
EOF
}

build_equirect_calibration_overlay() {
  local input_label="$1"
  local output_label="$2"
  local seam_x=$(( (OUTPUT_WIDTH / 2) - (CALIBRATION_LINE_THICKNESS / 2) ))
  local equator_y=$(( (OUTPUT_HEIGHT / 2) - (CALIBRATION_LINE_THICKNESS / 2) ))

  cat <<EOF
[${input_label}]drawtext=text='EQUIRECT PREVIEW  FOV=${V360_IH_FOV}/${V360_IV_FOV}':x=20:y=20:fontsize=${CALIBRATION_FONT_SIZE}:fontcolor=white:box=1:boxcolor=black@0.6[${output_label}_base]
EOF

  if [[ "${CALIBRATION_EQUIRECT_SEAM_GUIDE}" == "true" ]]; then
    cat <<EOF
;
[${output_label}_base]drawgrid=w=iw/8:h=ih/6:color=white@0.12:t=1,drawbox=x=${seam_x}:y=0:w=${CALIBRATION_LINE_THICKNESS}:h=ih:color=yellow@0.90:t=fill,drawbox=x=0:y=${equator_y}:w=iw:h=${CALIBRATION_LINE_THICKNESS}:color=white@0.45:t=fill,drawtext=text='SEAM':x=(w-text_w)/2:y=40:fontsize=${CALIBRATION_FONT_SIZE}:fontcolor=yellow:box=1:boxcolor=black@0.55[${output_label}]
EOF
    return 0
  fi

  printf ';\n[%s]null[%s]\n' "${output_label}_base" "${output_label}"
}

build_calibration_preview_branch() {
  local input_label="$1"
  local output_label="$2"
  local camera_label="$3"
  local crop_spec="$4"
  local border_color="$5"

  parse_crop_spec "${crop_spec}"

  local crop_w="${PARSED_CROP_W}"
  local crop_h="${PARSED_CROP_H}"
  local center_size="${CALIBRATION_CENTER_MARK_SIZE}"
  local center_half=$(( center_size / 2 ))
  local cross_half=$(( CALIBRATION_LINE_THICKNESS / 2 ))
  local exact_center_x=$(( crop_w / 2 ))
  local exact_center_y=$(( crop_h / 2 ))
  local exact_center_draw_x=$(( exact_center_x - center_half ))
  local exact_center_draw_y=$(( exact_center_y - center_half ))
  local rgb=""
  local color_r=255
  local color_g=255
  local color_b=255
  local offset_x=0
  local offset_y=0
  local estimated_x=0
  local estimated_y=0
  local estimated_draw_x=0
  local estimated_draw_y=0
  local line_left=0
  local line_top=0
  local line_w=0
  local line_h=0
  local base_label="${output_label}_base"
  local dx_sign="+"
  local dy_sign="+"

  rgb="$(calibration_color_rgb "${border_color}")"
  read -r color_r color_g color_b <<< "${rgb}"
  read -r offset_x offset_y <<< "$(camera_fisheye_center_offsets "${camera_label}")"

  estimated_x=$(( exact_center_x + offset_x ))
  estimated_y=$(( exact_center_y + offset_y ))
  estimated_draw_x=$(( estimated_x - center_half ))
  estimated_draw_y=$(( estimated_y - center_half ))

  if (( offset_x < 0 )); then
    dx_sign=""
  fi
  if (( offset_y < 0 )); then
    dy_sign=""
  fi

  line_left="${exact_center_x}"
  line_w=$(( offset_x ))
  if (( line_w < 0 )); then
    line_left="${estimated_x}"
    line_w=$(( -line_w ))
  fi
  line_w=$(( line_w + CALIBRATION_LINE_THICKNESS ))

  line_top="${exact_center_y}"
  line_h=$(( offset_y ))
  if (( line_h < 0 )); then
    line_top="${estimated_y}"
    line_h=$(( -line_h ))
  fi
  line_h=$(( line_h + CALIBRATION_LINE_THICKNESS ))

  cat <<EOF
[${input_label}]drawbox=x=0:y=0:w=iw:h=ih:color=${border_color}@0.95:t=${CALIBRATION_LINE_THICKNESS}$( [[ "${CALIBRATION_DRAW_GRID}" == "true" ]] && printf ',drawgrid=w=iw/%s:h=ih/%s:color=white@0.10:t=1' "${CALIBRATION_GRID_DIVISIONS}" "${CALIBRATION_GRID_DIVISIONS}" ),drawbox=x=$((exact_center_x - cross_half)):y=0:w=${CALIBRATION_LINE_THICKNESS}:h=ih:color=white@0.85:t=fill,drawbox=x=0:y=$((exact_center_y - cross_half)):w=iw:h=${CALIBRATION_LINE_THICKNESS}:color=white@0.85:t=fill,drawbox=x=${exact_center_draw_x}:y=${exact_center_draw_y}:w=${center_size}:h=${center_size}:color=yellow@0.95:t=fill,drawbox=x=${estimated_draw_x}:y=${estimated_draw_y}:w=${center_size}:h=${center_size}:color=${border_color}@0.95:t=fill,drawbox=x=${line_left}:y=$((exact_center_y - cross_half)):w=${line_w}:h=${CALIBRATION_LINE_THICKNESS}:color=${border_color}@0.70:t=fill,drawbox=x=$((estimated_x - cross_half)):y=${line_top}:w=${CALIBRATION_LINE_THICKNESS}:h=${line_h}:color=${border_color}@0.70:t=fill,drawtext=text='${camera_label} crop=${crop_w}x${crop_h} @${PARSED_CROP_X},${PARSED_CROP_Y}':x=20:y=20:fontsize=${CALIBRATION_FONT_SIZE}:fontcolor=white:box=1:boxcolor=black@0.6,drawtext=text='exact=%{eif\\:${exact_center_x}\\:d},%{eif\\:${exact_center_y}\\:d}  fisheye=%{eif\\:${estimated_x}\\:d},%{eif\\:${estimated_y}\\:d}  dx=${dx_sign}${offset_x} dy=${dy_sign}${offset_y}':x=20:y=$((20 + CALIBRATION_FONT_SIZE + 16)):fontsize=$((CALIBRATION_FONT_SIZE - 4)):fontcolor=${border_color}:box=1:boxcolor=black@0.55[${base_label}]
EOF

  if [[ "${CALIBRATION_DRAW_CIRCLE}" == "true" ]]; then
    printf ';\n'
    build_calibration_circle_segment "${base_label}" "${output_label}" "${output_label}_circle_mask" "${crop_w}" "${crop_h}" "${border_color}" "${estimated_x}" "${estimated_y}"
  fi
}

resolve_crop_for_input() {
  local camera_name="$1"
  local crop_spec="$2"
  local input_w="$3"
  local input_h="$4"
  local adjusted_crop=""

  RESOLVED_CROP_VALUE=""
  RESOLVED_CROP_STATUS=""
  RESOLVED_CROP_MESSAGE=""

  if validate_crop_bounds "${crop_spec}" "${input_w}" "${input_h}"; then
    RESOLVED_CROP_VALUE="${crop_spec}"
    RESOLVED_CROP_STATUS="valid"
    return 0
  fi

  if [[ "${AUTO_ADJUST_CROP}" == "true" ]]; then
    adjusted_crop="$(build_centered_square_crop "${input_w}" "${input_h}")"
    RESOLVED_CROP_VALUE="${adjusted_crop}"
    RESOLVED_CROP_STATUS="adjusted"
    RESOLVED_CROP_MESSAGE="${camera_name}: crop ${crop_spec} no cabe en ${input_w}x${input_h}; se ajusta a ${adjusted_crop}"
    return 0
  fi

  RESOLVED_CROP_STATUS="invalid"
  RESOLVED_CROP_MESSAGE="${camera_name}: crop ${crop_spec} no cabe en ${input_w}x${input_h}; ${CROP_VALIDATION_ERROR}"
  return 1
}

build_filter_complex_with_crops() {
  local cam1_crop="$1"
  local cam2_crop="$2"
  local filter_mode="${3:-normal}"
  local calibration_view="${4:-equirect}"
  local cam1_pre_filters=""
  local cam2_pre_filters=""

  cam1_pre_filters="$(camera_pre_transform_filters "CAM1")"
  cam2_pre_filters="$(camera_pre_transform_filters "CAM2")"

  if [[ "${filter_mode}" != "calibration" ]]; then
    if [[ "${PRE_HSTACK_RADIAL_MASK}" == "true" ]]; then
      cat <<EOF
[0:v]setpts=PTS-STARTPTS${cam1_pre_filters},crop=${cam1_crop}[cam1_base];
[1:v]setpts=PTS-STARTPTS${cam2_pre_filters},crop=${cam2_crop}[cam2_base];
$(build_radial_mask_segment "cam1_base" "left");
$(build_radial_mask_segment "cam2_base" "right");
[left][right]hstack=inputs=2[stacked];
[stacked]v360=input=${V360_INPUT}:output=${V360_OUTPUT}:ih_fov=${V360_IH_FOV}:iv_fov=${V360_IV_FOV},crop=iw*0.96:ih-60:iw*0.02:48,fps=${FPS},scale=${OUTPUT_WIDTH}:${OUTPUT_HEIGHT},format=${PIX_FMT}[v]
EOF
    else
      cat <<EOF
[0:v]setpts=PTS-STARTPTS${cam1_pre_filters},crop=${cam1_crop}[left];
[1:v]setpts=PTS-STARTPTS${cam2_pre_filters},crop=${cam2_crop}[right];
[left][right]hstack=inputs=2[stacked];
[stacked]v360=input=${V360_INPUT}:output=${V360_OUTPUT}:ih_fov=${V360_IH_FOV}:iv_fov=${V360_IV_FOV},crop=iw*0.96:ih-60:iw*0.02:48,fps=${FPS},scale=${OUTPUT_WIDTH}:${OUTPUT_HEIGHT},format=${PIX_FMT}[v]
EOF
    fi
    return 0
  fi

  case "${calibration_view}" in
    cam1)
      cat <<EOF
[0:v]setpts=PTS-STARTPTS${cam1_pre_filters},crop=${cam1_crop}[cam1_raw];
$(build_calibration_preview_branch "cam1_raw" "v" "CAM1" "${cam1_crop}" "lime")
EOF
      ;;
    cam2)
      cat <<EOF
[1:v]setpts=PTS-STARTPTS${cam2_pre_filters},crop=${cam2_crop}[cam2_raw];
$(build_calibration_preview_branch "cam2_raw" "v" "CAM2" "${cam2_crop}" "cyan")
EOF
      ;;
    equirect)
      cat <<EOF
[0:v]setpts=PTS-STARTPTS${cam1_pre_filters},crop=${cam1_crop}[cam1_raw];
[1:v]setpts=PTS-STARTPTS${cam2_pre_filters},crop=${cam2_crop}[cam2_raw];
$(build_calibration_preview_branch "cam1_raw" "cam1_preview" "CAM1" "${cam1_crop}" "lime");
$(build_calibration_preview_branch "cam2_raw" "cam2_preview" "CAM2" "${cam2_crop}" "cyan");
[cam1_preview][cam2_preview]hstack=inputs=2[stacked];
[stacked]v360=input=${V360_INPUT}:output=${V360_OUTPUT}:ih_fov=${V360_IH_FOV}:iv_fov=${V360_IV_FOV},fps=${FPS},scale=${OUTPUT_WIDTH}:${OUTPUT_HEIGHT},format=${PIX_FMT}[equirect_base];
$(build_equirect_calibration_overlay "equirect_base" "v")
EOF
      ;;
    *)
      echo "CALIBRATION_VIEW no soportado: ${calibration_view}" >&2
      return 1
      ;;
  esac
}

build_radial_mask_segment() {
  local input_label="$1"
  local output_label="$2"
  local gain_expr=""

  gain_expr="if(lte(hypot(X-W/2,Y-H/2),min(W,H)*${PRE_HSTACK_RADIAL_MASK_INNER_RATIO}/2),1,if(gte(hypot(X-W/2,Y-H/2),min(W,H)*${PRE_HSTACK_RADIAL_MASK_OUTER_RATIO}/2),0,(min(W,H)*${PRE_HSTACK_RADIAL_MASK_OUTER_RATIO}/2-hypot(X-W/2,Y-H/2))/((min(W,H)*(${PRE_HSTACK_RADIAL_MASK_OUTER_RATIO}-${PRE_HSTACK_RADIAL_MASK_INNER_RATIO}))/2)))"

  cat <<EOF
[${input_label}]format=yuv444p,geq=lum='lum(X,Y)*${gain_expr}':cb='128+(cb(X,Y)-128)*${gain_expr}':cr='128+(cr(X,Y)-128)*${gain_expr}',format=${PIX_FMT}[${output_label}]
EOF
}

build_filter_complex() {
  build_filter_complex_with_crops "${CAM1_CROP}" "${CAM2_CROP}"
}

log_crop_resolution() {
  local camera_name="$1"
  local input_w="$2"
  local input_h="$3"
  local configured_crop="$4"
  local effective_crop="$5"
  local status="$6"
  local message="$7"

  log INFO "${camera_name}: entrada detectada ${input_w}x${input_h}"

  case "${status}" in
    valid)
      log INFO "${camera_name}: crop validado ${effective_crop}"
      ;;
    adjusted)
      log WARN "${message}"
      ;;
    *)
      log INFO "${camera_name}: crop configurado ${configured_crop}"
      ;;
  esac
}

prepare_runtime_crops() {
  local input_source_mode="${1:-rtsp}"
  local filter_mode="${2:-normal}"
  local calibration_view="${3:-equirect}"
  local need_cam1="true"
  local need_cam2="true"
  local cam1_dims=""
  local cam2_dims=""
  local cam1_w=""
  local cam1_h=""
  local cam2_w=""
  local cam2_h=""

  EFFECTIVE_CAM1_CROP=""
  EFFECTIVE_CAM2_CROP=""

  if [[ "${filter_mode}" == "calibration" ]]; then
    case "${calibration_view}" in
      cam1)
        need_cam2="false"
        ;;
      cam2)
        need_cam1="false"
        ;;
    esac
  fi

  if [[ "${input_source_mode}" == "mock" ]]; then
    if [[ "${need_cam1}" == "true" ]]; then
      cam1_dims="3840x2160"
    fi
    if [[ "${need_cam2}" == "true" ]]; then
      cam2_dims="3840x2160"
    fi
  else
    log INFO "Detectando resolucion real de los streams RTSP"
    if [[ "${need_cam1}" == "true" ]]; then
      cam1_dims="$(probe_rtsp_video_dimensions "${URL_RTSP_CAM1}")"
    fi
    if [[ "${need_cam2}" == "true" ]]; then
      cam2_dims="$(probe_rtsp_video_dimensions "${URL_RTSP_CAM2}")"
    fi
  fi

  if [[ "${need_cam1}" == "true" ]]; then
    IFS='x' read -r cam1_w cam1_h <<< "${cam1_dims}"
    IFS='x' read -r cam1_w cam1_h <<< "$(camera_transformed_dimensions "CAM1" "${cam1_w}" "${cam1_h}")"
  fi
  if [[ "${need_cam2}" == "true" ]]; then
    IFS='x' read -r cam2_w cam2_h <<< "${cam2_dims}"
    IFS='x' read -r cam2_w cam2_h <<< "$(camera_transformed_dimensions "CAM2" "${cam2_w}" "${cam2_h}")"
  fi

  if [[ "${need_cam1}" == "true" ]]; then
    resolve_crop_for_input "cam1" "${CAM1_CROP}" "${cam1_w}" "${cam1_h}" || {
      log ERROR "${RESOLVED_CROP_MESSAGE}"
      return 1
    }
    EFFECTIVE_CAM1_CROP="${RESOLVED_CROP_VALUE}"
    log_crop_resolution "cam1" "${cam1_w}" "${cam1_h}" "${CAM1_CROP}" "${EFFECTIVE_CAM1_CROP}" "${RESOLVED_CROP_STATUS}" "${RESOLVED_CROP_MESSAGE}"
    if [[ "$(camera_transform_summary "CAM1")" != "rot=0 hflip=false vflip=false" ]]; then
      log INFO "cam1: pre-transform $(camera_transform_summary "CAM1")"
    fi
  fi

  if [[ "${need_cam2}" == "true" ]]; then
    resolve_crop_for_input "cam2" "${CAM2_CROP}" "${cam2_w}" "${cam2_h}" || {
      log ERROR "${RESOLVED_CROP_MESSAGE}"
      return 1
    }
    EFFECTIVE_CAM2_CROP="${RESOLVED_CROP_VALUE}"
    log_crop_resolution "cam2" "${cam2_w}" "${cam2_h}" "${CAM2_CROP}" "${EFFECTIVE_CAM2_CROP}" "${RESOLVED_CROP_STATUS}" "${RESOLVED_CROP_MESSAGE}"
    if [[ "$(camera_transform_summary "CAM2")" != "rot=0 hflip=false vflip=false" ]]; then
      log INFO "cam2: pre-transform $(camera_transform_summary "CAM2")"
    fi
  fi

  FILTER_COMPLEX="$(build_filter_complex_with_crops "${EFFECTIVE_CAM1_CROP}" "${EFFECTIVE_CAM2_CROP}" "${filter_mode}" "${calibration_view}")"
}

build_tee_target() {
  local outputs=()
  local record_pattern="${RECORDINGS_DIR}/%Y/%m/%d/%Y%m%d_%H%M%S.${SEGMENT_FORMAT}"
  local segment_muxer_format="${SEGMENT_FORMAT}"

  prepare_recording_output_dirs() {
    local day_path=""
    day_path="${RECORDINGS_DIR}/$(date +%Y/%m/%d)"
    mkdir -p "${day_path}"
    day_path="${RECORDINGS_DIR}/$(date -d '+1 day' +%Y/%m/%d 2>/dev/null || date +%Y/%m/%d)"
    mkdir -p "${day_path}"
  }

  prepare_recording_output_dirs

  if [[ "${SEGMENT_FORMAT}" == "mkv" ]]; then
    segment_muxer_format="matroska"
  fi

  case "${OUTPUT_MODE}" in
    dual)
      outputs+=("[f=flv]${YOUTUBE_RTMP_URL}/${STREAM_KEY}")
      outputs+=("[f=segment:onfail=ignore:strftime=1:segment_time=${SEGMENT_TIME}:reset_timestamps=1:segment_format=${segment_muxer_format}]${record_pattern}")
      ;;
    stream)
      outputs+=("[f=flv]${YOUTUBE_RTMP_URL}/${STREAM_KEY}")
      ;;
    record)
      outputs+=("[f=segment:onfail=ignore:strftime=1:segment_time=${SEGMENT_TIME}:reset_timestamps=1:segment_format=${segment_muxer_format}]${record_pattern}")
      ;;
    *)
      echo "OUTPUT_MODE no soportado: ${OUTPUT_MODE}" >&2
      return 1
      ;;
  esac

  if [[ "${#outputs[@]}" -eq 0 ]]; then
    echo "No hay salidas configuradas para tee" >&2
    return 1
  fi

  local joined=""
  local item
  for item in "${outputs[@]}"; do
    if [[ -n "${joined}" ]]; then
      joined="${joined}|"
    fi
    joined="${joined}${item}"
  done

  printf '%s\n' "${joined}"
}

find_recording_files() {
  find "${RECORDINGS_DIR}" -type f -name "*.${SEGMENT_FORMAT}" | sort
}

print_pipeline_summary() {
  cat <<EOF
Modo: ${PIPELINE_MODE}
Cam1: $(sanitize_rtsp_url "${URL_RTSP_CAM1}")
Cam2: $(sanitize_rtsp_url "${URL_RTSP_CAM2}")
Salida: ${OUTPUT_WIDTH}x${OUTPUT_HEIGHT} @ ${FPS} fps
Video: ${VIDEO_CODEC} ${BITRATE_VIDEO}
Audio: AAC ${BITRATE_AUDIO} ${AUDIO_CHANNEL_LAYOUT}
GOP: ${GOP}
Crop cam1: ${CAM1_CROP}
Crop cam2: ${CAM2_CROP}
Auto adjust crop: ${AUTO_ADJUST_CROP}
v360: ${V360_INPUT} -> ${V360_OUTPUT} (${V360_IH_FOV}/${V360_IV_FOV})
Salidas: ${OUTPUT_MODE}
Grabacion: ${RECORDINGS_ENABLED} -> ${RECORDINGS_DIR} (${SEGMENT_TIME}s, ${SEGMENT_FORMAT})
EOF
}

recording_output_enabled() {
  [[ "${OUTPUT_MODE}" == "dual" || "${OUTPUT_MODE}" == "record" ]]
}

strict_rtsp_watchdog_enabled() {
  [[ "${STRICT_RTSP_WATCHDOG:-false}" == "true" ]]
}

strict_rtmp_watchdog_enabled() {
  [[ "${STRICT_RTMP_WATCHDOG:-false}" == "true" ]]
}

restart_loop_protection_enabled() {
  [[ "${RESTART_LOOP_THRESHOLD:-0}" =~ ^[1-9][0-9]*$ ]] && [[ "${RESTART_LOOP_WINDOW_SECONDS:-0}" =~ ^[1-9][0-9]*$ ]]
}

watchdog_match_rtsp_error_line() {
  local line="${1:-}"
  printf '%s\n' "${line}" | grep -Eiq 'timeout|connection refused|could not find codec parameters|max delay reached|error while decoding|invalid data found|method describe failed|connection timed out|server returned 404|server returned 500|status[:= ]+404|status[:= ]+500|404 not found|500 internal'
}

watchdog_match_rtmp_error_line() {
  local line="${1:-}"
  printf '%s\n' "${line}" | grep -Eiq 'error in the push function|io error: broken pipe|broken pipe, continuing with|slave muxer #[0-9]+ failed|av_interleaved_write_frame.*broken pipe|failed to update header|connection reset by peer|input/output error'
}

process_state() {
  local pid="$1"
  ps -o stat= -p "${pid}" 2>/dev/null | awk '{print $1}'
}

process_exists() {
  local pid="$1"
  [[ -n "${pid}" ]] && ps -p "${pid}" >/dev/null 2>&1
}

process_is_zombie() {
  local pid="$1"
  local state=""

  state="$(process_state "${pid}")"
  [[ "${state}" == Z* ]]
}

acquire_process_lock() {
  local lock_dir="$1"
  local lock_name="$2"
  local owner_pid="$3"
  local holder_pid=""

  while true; do
    if mkdir "${lock_dir}" 2>/dev/null; then
      printf '%s\n' "${owner_pid}" > "${lock_dir}/pid"
      printf '%s\n' "$(date +%s)" > "${lock_dir}/created_at"
      return 0
    fi

    holder_pid="$(cat "${lock_dir}/pid" 2>/dev/null || true)"
    if [[ -n "${holder_pid}" ]] && process_exists "${holder_pid}" && ! process_is_zombie "${holder_pid}"; then
      return 1
    fi

    log WARN "Lock ${lock_name} stale detectado; limpiando ${lock_dir}"
    rm -rf "${lock_dir}"
  done
}

release_process_lock() {
  local lock_dir="$1"
  local owner_pid="$2"
  local holder_pid=""

  holder_pid="$(cat "${lock_dir}/pid" 2>/dev/null || true)"
  if [[ -z "${holder_pid}" || "${holder_pid}" == "${owner_pid}" ]]; then
    rm -rf "${lock_dir}"
  fi
}

current_project_ffmpeg_pid() {
  local pid=""

  pid="$(cat "${PID_FILE}" 2>/dev/null || true)"
  if [[ -n "${pid}" ]] && process_exists "${pid}" && ! process_is_zombie "${pid}"; then
    printf '%s\n' "${pid}"
    return 0
  fi

  return 1
}

collect_project_ffmpeg_pids() {
  {
    if [[ -f "${PID_FILE}" ]]; then
      cat "${PID_FILE}" 2>/dev/null || true
    fi
    pgrep -f -- "ffmpeg .*${PROGRESS_FILE}" 2>/dev/null || true
  } | awk 'NF && !seen[$0]++'
}

collect_project_run_ffmpeg_pids() {
  {
    pgrep -f -- "${SCRIPT_DIR}/run_ffmpeg_once.sh" 2>/dev/null || true
    pgrep -f -- "${SCRIPT_DIR}/ops/run_ffmpeg_once.sh" 2>/dev/null || true
  } | awk 'NF && !seen[$0]++'
}

count_active_project_ffmpeg() {
  local pid
  local count=0

  while IFS= read -r pid; do
    [[ -n "${pid}" ]] || continue
    if process_exists "${pid}" && ! process_is_zombie "${pid}"; then
      count=$((count + 1))
    fi
  done < <(collect_project_ffmpeg_pids)

  printf '%s\n' "${count}"
}

count_active_project_run_ffmpeg() {
  local exclude_pid="${1:-}"
  local pid
  local count=0

  while IFS= read -r pid; do
    [[ -n "${pid}" ]] || continue
    if [[ -n "${exclude_pid}" && "${pid}" == "${exclude_pid}" ]]; then
      continue
    fi
    if process_exists "${pid}" && ! process_is_zombie "${pid}"; then
      count=$((count + 1))
    fi
  done < <(collect_project_run_ffmpeg_pids)

  printf '%s\n' "${count}"
}

log_project_process_counts() {
  local context="$1"
  local exclude_wrapper_pid="${2:-}"
  local ffmpeg_count=0
  local wrapper_count=0

  ffmpeg_count="$(count_active_project_ffmpeg)"
  wrapper_count="$(count_active_project_run_ffmpeg "${exclude_wrapper_pid}")"
  log INFO "${context}: ffmpeg_activos=${ffmpeg_count} run_ffmpeg_once_activos=${wrapper_count}"
}

log_active_stream_pid() {
  local context="$1"
  local active_pid=""

  active_pid="$(current_project_ffmpeg_pid || true)"
  if [[ -n "${active_pid}" ]]; then
    log INFO "${context}: pid_ffmpeg_activo=${active_pid}"
  else
    log INFO "${context}: pid_ffmpeg_activo=none"
  fi
}

terminate_pid_with_logging() {
  local pid="$1"
  local label="$2"
  local reason="$3"
  local state=""
  local waited=0

  [[ -n "${pid}" ]] || return 0

  if ! process_exists "${pid}"; then
    return 0
  fi

  state="$(process_state "${pid}")"
  if [[ "${state}" == Z* ]]; then
    log WARN "Proceso ${label} PID ${pid} detectado en zombie durante ${reason}"
    return 0
  fi

  log WARN "Matando ${label} PID ${pid} por ${reason}"
  kill "${pid}" 2>/dev/null || true

  while process_exists "${pid}" && (( waited < 10 )); do
    sleep 1
    waited=$((waited + 1))
  done

  if process_exists "${pid}" && ! process_is_zombie "${pid}"; then
    log WARN "Forzando ${label} PID ${pid} con SIGKILL por ${reason}"
    kill -9 "${pid}" 2>/dev/null || true
    sleep 1
  fi
}

terminate_project_stream_processes() {
  local reason="$1"
  local pid
  local wrapper_pid

  while IFS= read -r pid; do
    [[ -n "${pid}" ]] || continue
    terminate_pid_with_logging "${pid}" "ffmpeg" "${reason}"
  done < <(collect_project_ffmpeg_pids)

  while IFS= read -r wrapper_pid; do
    [[ -n "${wrapper_pid}" ]] || continue
    if [[ "${wrapper_pid}" == "$$" ]]; then
      continue
    fi
    terminate_pid_with_logging "${wrapper_pid}" "run_ffmpeg_once" "${reason}"
  done < <(collect_project_run_ffmpeg_pids)

  rm -f "${PID_FILE}"
}

wait_for_project_stream_stop() {
  local timeout_seconds="${1:-15}"
  local reason="${2:-parada}"
  local exclude_wrapper_pid="${3:-}"
  local elapsed=0
  local ffmpeg_count=0
  local wrapper_count=0

  while true; do
    ffmpeg_count="$(count_active_project_ffmpeg)"
    wrapper_count="$(count_active_project_run_ffmpeg "${exclude_wrapper_pid}")"

    if (( ffmpeg_count == 0 && wrapper_count == 0 )); then
      log INFO "Instancia previa detenida correctamente tras ${reason}"
      log_active_stream_pid "Estado posterior a parada"
      return 0
    fi

    if (( elapsed >= timeout_seconds )); then
      log ERROR "Persisten procesos del stream tras ${reason}: ffmpeg=${ffmpeg_count} run_ffmpeg_once=${wrapper_count}"
      pgrep -af -- "ffmpeg .*${PROGRESS_FILE}" 2>/dev/null || true
      pgrep -af -- "${SCRIPT_DIR}/run_ffmpeg_once.sh|${SCRIPT_DIR}/ops/run_ffmpeg_once.sh" 2>/dev/null || true
      return 1
    fi

    sleep 1
    elapsed=$((elapsed + 1))
  done
}

wait_for_project_ffmpeg_stop() {
  local timeout_seconds="${1:-15}"
  local reason="${2:-parada}"
  local elapsed=0
  local ffmpeg_count=0

  while true; do
    ffmpeg_count="$(count_active_project_ffmpeg)"

    if (( ffmpeg_count == 0 )); then
      log INFO "Instancia ffmpeg previa detenida correctamente tras ${reason}"
      log_active_stream_pid "Estado posterior a parada ffmpeg"
      return 0
    fi

    if (( elapsed >= timeout_seconds )); then
      log ERROR "Persisten procesos ffmpeg del stream tras ${reason}: ffmpeg=${ffmpeg_count}"
      pgrep -af -- "ffmpeg .*${PROGRESS_FILE}" 2>/dev/null || true
      return 1
    fi

    sleep 1
    elapsed=$((elapsed + 1))
  done
}

verify_single_ffmpeg_or_fail() {
  local reason="$1"
  local active_count=0

  active_count="$(count_active_project_ffmpeg)"
  if (( active_count > 0 )); then
    log ERROR "Persisten ${active_count} instancias ffmpeg tras saneamiento (${reason})"
    pgrep -af -- "ffmpeg .*${PROGRESS_FILE}" 2>/dev/null || true
    return 1
  fi

  return 0
}
