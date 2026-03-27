#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib.sh"

load_config
require_cmd ffprobe timeout sed awk grep date

RUN_ID="$(timestamp)"
LOG_FILE="${VALIDATION_LOG_DIR}/validate_${RUN_ID}.log"

{
  log INFO "Iniciando validacion de camaras"
  print_pipeline_summary

  for entry in "cam1:${URL_RTSP_CAM1}" "cam2:${URL_RTSP_CAM2}"; do
    name="${entry%%:*}"
    url="${entry#*:}"
    host="$(rtsp_host_from_url "${url}")"

    echo
    log INFO "Validando ${name} (${host})"

    if ping_host_if_possible "${host}"; then
      log INFO "Ping correcto a ${host}"
    else
      log WARN "Ping no responde para ${host}; se continua con ffprobe"
    fi

    ffprobe_rtsp "${url}"

    dims="$(probe_rtsp_video_dimensions "${url}")"
    input_w="${dims%x*}"
    input_h="${dims#*x}"

    if [[ "${name}" == "cam1" ]]; then
      resolve_crop_for_input "${name}" "${CAM1_CROP}" "${input_w}" "${input_h}" || {
        log ERROR "${RESOLVED_CROP_MESSAGE}"
        exit 1
      }
      log_crop_resolution "${name}" "${input_w}" "${input_h}" "${CAM1_CROP}" "${RESOLVED_CROP_VALUE}" "${RESOLVED_CROP_STATUS}" "${RESOLVED_CROP_MESSAGE}"
    else
      resolve_crop_for_input "${name}" "${CAM2_CROP}" "${input_w}" "${input_h}" || {
        log ERROR "${RESOLVED_CROP_MESSAGE}"
        exit 1
      }
      log_crop_resolution "${name}" "${input_w}" "${input_h}" "${CAM2_CROP}" "${RESOLVED_CROP_VALUE}" "${RESOLVED_CROP_STATUS}" "${RESOLVED_CROP_MESSAGE}"
    fi
  done

  log INFO "Validacion finalizada"
} 2>&1 | tee -a "${LOG_FILE}"
