#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib.sh"

load_config
require_cmd ffprobe find date tee stat

RUN_ID="$(timestamp)"
LOG_FILE="${VALIDATION_LOG_DIR}/recordings_validate_${RUN_ID}.log"
now_epoch="$(date +%s)"
recent_count=0

{
  log INFO "Validando grabaciones en ${RECORDINGS_DIR}"
  log INFO "Se espera al menos 1 segmento cada ${SEGMENT_TIME}s"

  while IFS= read -r file; do
    [[ -n "${file}" ]] || continue
    mtime="$(stat -c %Y "${file}")"
    age=$((now_epoch - mtime))
    if (( age <= SEGMENT_TIME + 30 )); then
      recent_count=$((recent_count + 1))
    fi
  done < <(find_recording_files)

  log INFO "Segmentos recientes detectados: ${recent_count}"
  if (( recent_count < 1 )); then
    log ERROR "No se ha detectado ningun segmento reciente"
    exit 1
  fi

  latest_file="$(find_recording_files | tail -n 1)"
  if [[ -z "${latest_file}" ]]; then
    log ERROR "No hay ficheros en recordings"
    exit 1
  fi

  log INFO "Ultimo segmento: ${latest_file}"

  base_name="$(basename "${latest_file}")"
  if [[ ! "${base_name}" =~ ^[0-9]{8}_[0-9]{6}\. ]]; then
    log ERROR "El nombre no cumple el patron timestamp esperado"
    exit 1
  fi

  ffprobe -v error \
    -show_entries format=format_name,duration,size \
    -show_entries stream=index,codec_name,codec_type,width,height \
    -of default=noprint_wrappers=1 \
    "${latest_file}"

  log INFO "Validacion de grabaciones completada"
} 2>&1 | tee -a "${LOG_FILE}"
