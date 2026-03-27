#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib.sh"

load_config
require_cmd ffmpeg ffprobe timeout tee sed mktemp cp rm

VIEW="${1:-cam1}"

case "${VIEW}" in
  cam1|cam2|equirect)
    ;;
  *)
    echo "Vista de barrido no soportada: ${VIEW}" >&2
    echo "Usa una de: cam1, cam2, equirect" >&2
    exit 1
    ;;
esac

RUN_ID="$(timestamp)"
LOG_FILE="${CALIBRATION_LOG_DIR}/calibration_sweep_${VIEW}_${RUN_ID}.log"

write_temp_env() {
  local env_file="$1"
  cp "${CONFIG_FILE}" "${env_file}"
  sed -i "s/^LOCAL_TEST_DURATION_SECONDS=.*/LOCAL_TEST_DURATION_SECONDS=${CALIBRATION_SWEEP_DURATION_SECONDS}/" "${env_file}"
}

run_preview_with_env() {
  local env_file="$1"
  local view="$2"
  local output_path="$3"
  shift 3
  log INFO "Preview ${view} -> ${output_path}"
  YOUTUBE360_ENV_FILE="${env_file}" "${SCRIPT_DIR}/calibration_test.sh" "${view}" "${output_path}" "$@"
}

run_crop_sweep() {
  local view="$1"
  local camera_label="CAM1"
  local crop_spec="${CAM1_CROP}"
  local crop_var="CAM1_CROP"
  local sweep_x=()
  local sweep_y=()
  local crop_w=0
  local crop_h=0
  local base_x=0
  local base_y=0
  local dx=0
  local dy=0
  local new_x=0
  local new_y=0
  local env_file=""
  local output_path=""

  if [[ "${view}" == "cam2" ]]; then
    camera_label="CAM2"
    crop_spec="${CAM2_CROP}"
    crop_var="CAM2_CROP"
  fi

  parse_crop_spec "${crop_spec}"
  crop_w="${PARSED_CROP_W}"
  crop_h="${PARSED_CROP_H}"
  base_x="${PARSED_CROP_X}"
  base_y="${PARSED_CROP_Y}"

  IFS=',' read -r -a sweep_x <<< "${CALIBRATION_SWEEP_X_OFFSETS}"
  IFS=',' read -r -a sweep_y <<< "${CALIBRATION_SWEEP_Y_OFFSETS}"

  for dx in "${sweep_x[@]}"; do
    for dy in "${sweep_y[@]}"; do
      new_x=$(( base_x + dx ))
      new_y=$(( base_y + dy ))
      env_file="$(mktemp "${RUNTIME_TMP_DIR}/calibration_sweep_${view}_XXXXXX.env")"
      write_temp_env "${env_file}"
      sed -i "s/^${crop_var}=.*/${crop_var}=\"${crop_w}:${crop_h}:${new_x}:${new_y}\"/" "${env_file}"
      output_path="${ARTIFACTS_CALIBRATION_DIR}/calibration_${view}_${RUN_ID}_x$(printf '%04d' "${new_x}")_y$(printf '%04d' "${new_y}").mp4"
      {
        log INFO "${camera_label}: probando crop ${crop_w}:${crop_h}:${new_x}:${new_y}"
        run_preview_with_env "${env_file}" "${view}" "${output_path}"
      } 2>&1 | tee -a "${LOG_FILE}"
      rm -f "${env_file}"
    done
  done
}

run_fov_sweep() {
  local env_file=""
  local output_path=""
  local fov=""
  local fovs=()

  IFS=',' read -r -a fovs <<< "${CALIBRATION_SWEEP_FOVS}"

  for fov in "${fovs[@]}"; do
    env_file="$(mktemp "${RUNTIME_TMP_DIR}/calibration_sweep_equirect_XXXXXX.env")"
    write_temp_env "${env_file}"
    sed -i "s/^V360_IH_FOV=.*/V360_IH_FOV=${fov}/" "${env_file}"
    sed -i "s/^V360_IV_FOV=.*/V360_IV_FOV=${fov}/" "${env_file}"
    output_path="${ARTIFACTS_CALIBRATION_DIR}/calibration_equirect_${RUN_ID}_fov${fov}.mp4"
    {
      log INFO "EQUIRECT: probando FOV ${fov}/${fov}"
      run_preview_with_env "${env_file}" equirect "${output_path}" "${fov}" "${fov}"
    } 2>&1 | tee -a "${LOG_FILE}"
    rm -f "${env_file}"
  done
}

case "${VIEW}" in
  cam1|cam2)
    run_crop_sweep "${VIEW}"
    ;;
  equirect)
    run_fov_sweep
    ;;
esac
