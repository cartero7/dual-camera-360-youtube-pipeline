#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib.sh"

load_config
require_cmd ffmpeg ffprobe timeout sed awk grep date
check_required_settings

RUN_ID="$(timestamp)"
LOG_FILE="${VALIDATION_LOG_DIR}/youtube_preflight_${RUN_ID}.log"

failures=0
warnings=0

check_ok() {
  local message="$1"
  log INFO "OK: ${message}"
}

check_warn() {
  local message="$1"
  log WARN "WARN: ${message}"
  warnings=$((warnings + 1))
}

check_fail() {
  local message="$1"
  log ERROR "FAIL: ${message}"
  failures=$((failures + 1))
}

{
  log INFO "Iniciando preflight de YouTube 360"
  print_pipeline_summary

  if (( OUTPUT_WIDTH == OUTPUT_HEIGHT * 2 )); then
    check_ok "salida 2:1 (${OUTPUT_WIDTH}x${OUTPUT_HEIGHT})"
  else
    check_fail "la salida debe ser 2:1 para equirectangular; actual ${OUTPUT_WIDTH}x${OUTPUT_HEIGHT}"
  fi

  if [[ "${PIX_FMT}" == "yuv420p" ]]; then
    check_ok "pixel format ${PIX_FMT}"
  else
    check_fail "YouTube espera yuv420p; actual ${PIX_FMT}"
  fi

  if [[ "${VIDEO_CODEC}" == "libx264" || "${VIDEO_CODEC}" == "h264" ]]; then
    check_ok "codec de video ${VIDEO_CODEC}"
  else
    check_fail "YouTube RTMP/RTMPS requiere H.264; actual ${VIDEO_CODEC}"
  fi

  check_ok "audio AAC en pipeline"

  if (( GOP == FPS * 2 )); then
    check_ok "keyframe cada 2s (GOP=${GOP}, FPS=${FPS})"
  elif (( GOP > 0 && FPS > 0 )); then
    check_warn "YouTube recomienda 2s; actual GOP=${GOP} para ${FPS} fps"
  else
    check_fail "FPS/GOP invalidos"
  fi

  if [[ "${YOUTUBE_RTMP_URL}" == rtmps://* ]]; then
    check_ok "ingest seguro por RTMPS"
  else
    check_warn "se recomienda RTMPS; actual ${YOUTUBE_RTMP_URL}"
  fi

  if [[ -n "${STREAM_KEY}" && "${STREAM_KEY}" != "REEMPLAZAR_CON_TU_STREAM_KEY" ]]; then
    check_ok "stream key configurada"
  else
    check_fail "stream key no configurada"
  fi

  log INFO "Paso manual imprescindible en YouTube:"
  log INFO "  En Live Control Room, activa video 360 en Configuracion adicional."
  log INFO "  Si usas la API de YouTube, el broadcast debe tener contentDetails.projection=360."
  log INFO "  El stream RTMP por si solo no garantiza que YouTube detecte 360."

  if [[ "${OUTPUT_MODE}" != "dual" && "${OUTPUT_MODE}" != "stream" ]]; then
    check_warn "para emitir a YouTube conviene OUTPUT_MODE=dual o stream; actual ${OUTPUT_MODE}"
  fi

  if (( failures == 0 )); then
    log INFO "Preflight finalizado correctamente (${warnings} warnings)"
  else
    log ERROR "Preflight con ${failures} errores y ${warnings} warnings"
    exit 1
  fi
} 2>&1 | tee -a "${LOG_FILE}"
