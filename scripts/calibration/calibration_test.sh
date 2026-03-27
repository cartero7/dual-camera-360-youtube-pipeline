#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib.sh"

load_config
require_cmd ffmpeg ffprobe timeout tee sed mktemp cp rm

VIEW="${1:-equirect}"
OUTPUT_PATH="${2:-${ARTIFACTS_CALIBRATION_DIR}/calibration_${VIEW}_$(timestamp).mp4}"
IH_FOV_OVERRIDE="${3:-}"
IV_FOV_OVERRIDE="${4:-}"
RUN_ENV_FILE="${CONFIG_FILE}"
TEMP_ENV_FILE=""

case "${VIEW}" in
  cam1|cam2|equirect)
    ;;
  *)
    echo "Vista de calibracion no soportada: ${VIEW}" >&2
    echo "Usa una de: cam1, cam2, equirect" >&2
    exit 1
    ;;
esac

if [[ -n "${IH_FOV_OVERRIDE}" || -n "${IV_FOV_OVERRIDE}" ]]; then
  TEMP_ENV_FILE="$(mktemp "${RUNTIME_TMP_DIR}/calibration_test_env_XXXXXX.env")"
  trap 'rm -f "${TEMP_ENV_FILE}"' EXIT
  cp "${CONFIG_FILE}" "${TEMP_ENV_FILE}"

  if [[ -n "${IH_FOV_OVERRIDE}" ]]; then
    sed -i "s/^V360_IH_FOV=.*/V360_IH_FOV=${IH_FOV_OVERRIDE}/" "${TEMP_ENV_FILE}"
  fi
  if [[ -n "${IV_FOV_OVERRIDE}" ]]; then
    sed -i "s/^V360_IV_FOV=.*/V360_IV_FOV=${IV_FOV_OVERRIDE}/" "${TEMP_ENV_FILE}"
  fi

  RUN_ENV_FILE="${TEMP_ENV_FILE}"
fi

log INFO "Generando preview de calibracion (${VIEW}) en ${OUTPUT_PATH}"
YOUTUBE360_ENV_FILE="${RUN_ENV_FILE}" \
  "${SCRIPT_DIR}/run_ffmpeg_once.sh" local "${OUTPUT_PATH}" rtsp calibration "${VIEW}"

if [[ -f "${OUTPUT_PATH}" ]]; then
  log INFO "Archivo generado: ${OUTPUT_PATH}"
fi
