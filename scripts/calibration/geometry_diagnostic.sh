#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib.sh"

load_config
require_cmd ffmpeg ffprobe timeout tee sed mktemp cp rm

RUN_ID="$(timestamp)"
LOG_FILE="${DIAGNOSTIC_LOG_DIR}/geometry_diagnostic_${RUN_ID}.log"
MANIFEST_FILE="${ARTIFACTS_DIAGNOSTICS_DIR}/geometry_diagnostic_${RUN_ID}.tsv"
PRECHECK_ATTEMPTS=4
PRECHECK_SLEEP_SECONDS=2
BETWEEN_CASES_SLEEP_SECONDS=2

parse_crop_spec "${CAM1_CROP}"
CAM1_BASE_W="${PARSED_CROP_W}"
CAM1_BASE_H="${PARSED_CROP_H}"
CAM1_BASE_X="${PARSED_CROP_X}"
CAM1_BASE_Y="${PARSED_CROP_Y}"

parse_crop_spec "${CAM2_CROP}"
CAM2_BASE_W="${PARSED_CROP_W}"
CAM2_BASE_H="${PARSED_CROP_H}"
CAM2_BASE_X="${PARSED_CROP_X}"
CAM2_BASE_Y="${PARSED_CROP_Y}"

printf 'file\tcase\trc\tcam1_rotate\tcam1_hflip\tcam1_vflip\tcam2_rotate\tcam2_hflip\tcam2_vflip\tih_fov\tiv_fov\tcam1_crop\tcam2_crop\n' > "${MANIFEST_FILE}"

wait_for_rtsp_inputs() {
  local attempt=1
  local cam1_ok=1
  local cam2_ok=1

  while (( attempt <= PRECHECK_ATTEMPTS )); do
    cam1_ok=0
    cam2_ok=0

    if probe_rtsp_video_dimensions "${URL_RTSP_CAM1}" >/dev/null 2>&1; then
      cam1_ok=1
    fi
    if probe_rtsp_video_dimensions "${URL_RTSP_CAM2}" >/dev/null 2>&1; then
      cam2_ok=1
    fi

    if (( cam1_ok == 1 && cam2_ok == 1 )); then
      log INFO "RTSP precheck correcto en intento ${attempt}" | tee -a "${LOG_FILE}"
      return 0
    fi

    log WARN "RTSP precheck intento ${attempt}/${PRECHECK_ATTEMPTS} no disponible aun; reintentando" | tee -a "${LOG_FILE}"
    sleep "${PRECHECK_SLEEP_SECONDS}"
    attempt=$(( attempt + 1 ))
  done

  log ERROR "RTSP no disponible tras ${PRECHECK_ATTEMPTS} intentos; se aborta geometry-diagnostic" | tee -a "${LOG_FILE}"
  return 1
}

write_temp_env() {
  local env_file="$1"
  cp "${CONFIG_FILE}" "${env_file}"
  sed -i "s/^LOCAL_TEST_DURATION_SECONDS=.*/LOCAL_TEST_DURATION_SECONDS=${CALIBRATION_SWEEP_DURATION_SECONDS}/" "${env_file}"
}

run_case() {
  local case_name="$1"
  local cam1_rotate="$2"
  local cam1_hflip="$3"
  local cam1_vflip="$4"
  local cam2_rotate="$5"
  local cam2_hflip="$6"
  local cam2_vflip="$7"
  local ih_fov="$8"
  local iv_fov="$9"
  local cam1_crop="${10}"
  local cam2_crop="${11}"
  local env_file=""
  local output_path="${ARTIFACTS_DIAGNOSTICS_DIR}/diagnostic_${RUN_ID}_${case_name}.mp4"
  local rc=0

  env_file="$(mktemp "${RUNTIME_TMP_DIR}/geometry_diagnostic_XXXXXX.env")"
  write_temp_env "${env_file}"

  sed -i "s/^CAM1_PRE_ROTATE=.*/CAM1_PRE_ROTATE=${cam1_rotate}/" "${env_file}"
  sed -i "s/^CAM2_PRE_ROTATE=.*/CAM2_PRE_ROTATE=${cam2_rotate}/" "${env_file}"
  sed -i "s/^CAM1_HFLIP=.*/CAM1_HFLIP=${cam1_hflip}/" "${env_file}"
  sed -i "s/^CAM2_HFLIP=.*/CAM2_HFLIP=${cam2_hflip}/" "${env_file}"
  sed -i "s/^CAM1_VFLIP=.*/CAM1_VFLIP=${cam1_vflip}/" "${env_file}"
  sed -i "s/^CAM2_VFLIP=.*/CAM2_VFLIP=${cam2_vflip}/" "${env_file}"
  sed -i "s/^V360_IH_FOV=.*/V360_IH_FOV=${ih_fov}/" "${env_file}"
  sed -i "s/^V360_IV_FOV=.*/V360_IV_FOV=${iv_fov}/" "${env_file}"
  sed -i "s/^CAM1_CROP=.*/CAM1_CROP=\"${cam1_crop}\"/" "${env_file}"
  sed -i "s/^CAM2_CROP=.*/CAM2_CROP=\"${cam2_crop}\"/" "${env_file}"

  {
    wait_for_rtsp_inputs
    log INFO "Caso ${case_name}"
    log INFO "  CAM1 rot=${cam1_rotate} hflip=${cam1_hflip} vflip=${cam1_vflip} crop=${cam1_crop}"
    log INFO "  CAM2 rot=${cam2_rotate} hflip=${cam2_hflip} vflip=${cam2_vflip} crop=${cam2_crop}"
    log INFO "  FOV ${ih_fov}/${iv_fov}"
    YOUTUBE360_ENV_FILE="${env_file}" "${SCRIPT_DIR}/calibration_test.sh" equirect "${output_path}" "${ih_fov}" "${iv_fov}"
  } 2>&1 | tee -a "${LOG_FILE}" || rc=$?

  if [[ "${rc}" -ne 0 ]]; then
    log WARN "Caso ${case_name} finalizo con codigo ${rc}" | tee -a "${LOG_FILE}"
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "${output_path}" \
    "${case_name}" \
    "${rc}" \
    "${cam1_rotate}" \
    "${cam1_hflip}" \
    "${cam1_vflip}" \
    "${cam2_rotate}" \
    "${cam2_hflip}" \
    "${cam2_vflip}" \
    "${ih_fov}" \
    "${iv_fov}" \
    "${cam1_crop}" \
    "${cam2_crop}" >> "${MANIFEST_FILE}"

  rm -f "${env_file}"
  sleep "${BETWEEN_CASES_SLEEP_SECONDS}"
  return 0
}

run_case \
  "base" \
  "${CAM1_PRE_ROTATE}" "${CAM1_HFLIP}" "${CAM1_VFLIP}" \
  "${CAM2_PRE_ROTATE}" "${CAM2_HFLIP}" "${CAM2_VFLIP}" \
  "${V360_IH_FOV}" "${V360_IV_FOV}" \
  "${CAM1_CROP}" "${CAM2_CROP}"

run_case \
  "cam2_hflip" \
  "${CAM1_PRE_ROTATE}" "${CAM1_HFLIP}" "${CAM1_VFLIP}" \
  "${CAM2_PRE_ROTATE}" true "${CAM2_VFLIP}" \
  "${V360_IH_FOV}" "${V360_IV_FOV}" \
  "${CAM1_CROP}" "${CAM2_CROP}"

run_case \
  "cam2_rot180" \
  "${CAM1_PRE_ROTATE}" "${CAM1_HFLIP}" "${CAM1_VFLIP}" \
  180 "${CAM2_HFLIP}" "${CAM2_VFLIP}" \
  "${V360_IH_FOV}" "${V360_IV_FOV}" \
  "${CAM1_CROP}" "${CAM2_CROP}"

run_case \
  "fov185" \
  "${CAM1_PRE_ROTATE}" "${CAM1_HFLIP}" "${CAM1_VFLIP}" \
  "${CAM2_PRE_ROTATE}" "${CAM2_HFLIP}" "${CAM2_VFLIP}" \
  185 185 \
  "${CAM1_CROP}" "${CAM2_CROP}"

run_case \
  "cam1_xminus20" \
  "${CAM1_PRE_ROTATE}" "${CAM1_HFLIP}" "${CAM1_VFLIP}" \
  "${CAM2_PRE_ROTATE}" "${CAM2_HFLIP}" "${CAM2_VFLIP}" \
  "${V360_IH_FOV}" "${V360_IV_FOV}" \
  "${CAM1_BASE_W}:${CAM1_BASE_H}:$((CAM1_BASE_X - 20)):${CAM1_BASE_Y}" \
  "${CAM2_CROP}"

run_case \
  "cam2_xplus20" \
  "${CAM1_PRE_ROTATE}" "${CAM1_HFLIP}" "${CAM1_VFLIP}" \
  "${CAM2_PRE_ROTATE}" "${CAM2_HFLIP}" "${CAM2_VFLIP}" \
  "${V360_IH_FOV}" "${V360_IV_FOV}" \
  "${CAM1_CROP}" \
  "${CAM2_BASE_W}:${CAM2_BASE_H}:$((CAM2_BASE_X + 20)):${CAM2_BASE_Y}"

run_case \
  "cam2_hflip_fov185" \
  "${CAM1_PRE_ROTATE}" "${CAM1_HFLIP}" "${CAM1_VFLIP}" \
  "${CAM2_PRE_ROTATE}" true "${CAM2_VFLIP}" \
  185 185 \
  "${CAM1_CROP}" "${CAM2_CROP}"

run_case \
  "cam2_rot180_fov185" \
  "${CAM1_PRE_ROTATE}" "${CAM1_HFLIP}" "${CAM1_VFLIP}" \
  180 "${CAM2_HFLIP}" "${CAM2_VFLIP}" \
  185 185 \
  "${CAM1_CROP}" "${CAM2_CROP}"

log INFO "Diagnostico completo. Manifiesto: ${MANIFEST_FILE}" | tee -a "${LOG_FILE}"
