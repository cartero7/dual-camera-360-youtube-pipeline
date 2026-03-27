#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib.sh"

load_config
require_cmd bash date sleep tee stat pkill

if ! acquire_process_lock "${WATCHDOG_LOCK_DIR}" "watchdog" "$$"; then
  holder_pid="$(cat "${WATCHDOG_LOCK_DIR}/pid" 2>/dev/null || true)"
  log ERROR "Otro watchdog ya esta activo con PID ${holder_pid:-desconocido}; abortando"
  exit 1
fi

cleanup_watchdog_lock() {
  release_process_lock "${WATCHDOG_LOCK_DIR}" "$$"
}

trap cleanup_watchdog_lock EXIT

RUN_ID="$(timestamp)"
WATCHDOG_LOG="${OPS_LOG_DIR}/watchdog_${RUN_ID}.log"
RESTART_COUNT=0
RESTART_REASON=""
RESTART_TIMESTAMPS=()

request_restart() {
  local child_pid="$1"
  local reason="$2"
  local detail="${3:-}"

  RESTART_REASON="${reason}"
  log ERROR "Reinicio solicitado: ${reason}" | tee -a "${WATCHDOG_LOG}"
  if [[ -n "${detail}" ]]; then
    log ERROR "Detalle: ${detail}" | tee -a "${WATCHDOG_LOG}"
  fi

  log WARN "Parando instancia previa del stream antes de relanzar" | tee -a "${WATCHDOG_LOG}"
  kill "${child_pid}" 2>/dev/null || true

  if ! wait_for_project_stream_stop 20 "${reason}" "${child_pid}" | tee -a "${WATCHDOG_LOG}"; then
    log WARN "Parada ordenada insuficiente; forzando limpieza del stream" | tee -a "${WATCHDOG_LOG}"
    terminate_project_stream_processes "${reason}"
    wait_for_project_stream_stop 20 "${reason}" "${child_pid}" | tee -a "${WATCHDOG_LOG}" || true
  fi

  return 1
}

register_restart_attempt() {
  local now_epoch="$1"
  local kept=()
  local ts

  RESTART_TIMESTAMPS+=("${now_epoch}")

  if restart_loop_protection_enabled; then
    for ts in "${RESTART_TIMESTAMPS[@]}"; do
      if (( now_epoch - ts <= RESTART_LOOP_WINDOW_SECONDS )); then
        kept+=("${ts}")
      fi
    done
    RESTART_TIMESTAMPS=("${kept[@]}")

    if (( ${#RESTART_TIMESTAMPS[@]} >= RESTART_LOOP_THRESHOLD )); then
      log ERROR "Proteccion anti-loop activada: ${#RESTART_TIMESTAMPS[@]} reinicios en ${RESTART_LOOP_WINDOW_SECONDS}s" | tee -a "${WATCHDOG_LOG}"
      return 1
    fi
  fi

  return 0
}

monitor_progress() {
  local child_pid="$1"
  local child_started_epoch
  local now_epoch
  local progress_epoch
  local age
  local last_out_time_ms=""
  local current_out_time_ms=""
  local last_progress_advance_epoch=""
  local latest_segment=""
  local latest_segment_epoch=""
  local recording_age
  local child_uptime
  local log_read_offset=0
  local active_stream_log=""
  local line=""
  local rtsp_error_timestamps=()
  local filtered_rtsp_error_timestamps=()
  local rtmp_error_timestamps=()
  local filtered_rtmp_error_timestamps=()
  local last_rtsp_detail=""
  local last_rtmp_detail=""
  local i

  child_started_epoch="$(date +%s)"
  last_progress_advance_epoch="${child_started_epoch}"

  while kill -0 "${child_pid}" 2>/dev/null; do
    sleep "${HEALTHCHECK_INTERVAL_SECONDS}"
    now_epoch="$(date +%s)"

    if [[ ! -f "${PROGRESS_FILE}" ]]; then
      age=$((now_epoch - child_started_epoch))
      if (( age > STARTUP_GRACE_SECONDS )); then
        request_restart "${child_pid}" "No existe progress file tras ${age}s" ""
      fi
      log WARN "Sin fichero de progreso todavia" | tee -a "${WATCHDOG_LOG}"
      continue
    fi

    progress_epoch="$(stat -c %Y "${PROGRESS_FILE}")"
    age=$((now_epoch - progress_epoch))

    if (( age > STALL_TIMEOUT_SECONDS )); then
      request_restart "${child_pid}" "Pipeline sin actualizar progress file desde hace ${age}s" ""
    fi

    current_out_time_ms="$(awk -F= '/^out_time_ms=/{value=$2} END{print value}' "${PROGRESS_FILE}")"
    if [[ -n "${current_out_time_ms}" && "${current_out_time_ms}" != "N/A" ]]; then
      if [[ -z "${last_out_time_ms}" || "${current_out_time_ms}" -gt "${last_out_time_ms}" ]]; then
        last_out_time_ms="${current_out_time_ms}"
        last_progress_advance_epoch="${now_epoch}"
      fi
    fi

    age=$((now_epoch - last_progress_advance_epoch))
    if (( age > STALL_TIMEOUT_SECONDS )); then
      request_restart "${child_pid}" "Pipeline vivo pero out_time_ms no avanza desde hace ${age}s" ""
    fi

    child_uptime=$((now_epoch - child_started_epoch))
    if (( ${MAX_FFMPEG_UPTIME_SECONDS:-0} > 0 && child_uptime >= MAX_FFMPEG_UPTIME_SECONDS )); then
      request_restart "${child_pid}" "Reinicio programado tras ${child_uptime}s de uptime" ""
    fi

    if recording_output_enabled; then
      latest_segment="$(find_recording_files | tail -n 1)"
      if [[ -z "${latest_segment}" ]]; then
        age=$((now_epoch - child_started_epoch))
        if (( age > STARTUP_GRACE_SECONDS )); then
          request_restart "${child_pid}" "No se ha creado ningun segmento tras ${age}s" ""
        fi
      else
        latest_segment_epoch="$(stat -c %Y "${latest_segment}")"
        recording_age=$((now_epoch - latest_segment_epoch))
        if (( recording_age > RECORDING_STALL_TIMEOUT_SECONDS )); then
          request_restart "${child_pid}" "No hay segmentos nuevos desde hace ${recording_age}s" "Ultimo segmento visto: ${latest_segment}"
        fi
      fi
    fi

    if [[ -f "${CURRENT_LOG_FILE}" ]]; then
      active_stream_log="$(cat "${CURRENT_LOG_FILE}")"
    else
      active_stream_log=""
    fi

    if [[ -n "${active_stream_log}" && -f "${active_stream_log}" ]]; then
      while IFS= read -r line; do
        [[ -n "${line}" ]] || continue

        if strict_rtsp_watchdog_enabled && watchdog_match_rtsp_error_line "${line}"; then
          rtsp_error_timestamps+=("${now_epoch}|${line}")
        fi

        if strict_rtmp_watchdog_enabled && watchdog_match_rtmp_error_line "${line}"; then
          rtmp_error_timestamps+=("${now_epoch}|${line}")
        fi
      done < <(tail -c +"$((log_read_offset + 1))" "${active_stream_log}" 2>/dev/null || true)

      log_read_offset="$(wc -c < "${active_stream_log}")"
    fi

    if strict_rtsp_watchdog_enabled; then
      filtered_rtsp_error_timestamps=()
      for i in "${rtsp_error_timestamps[@]}"; do
        if (( now_epoch - ${i%%|*} <= STRICT_RTSP_ERROR_WINDOW_SECONDS )); then
          filtered_rtsp_error_timestamps+=("${i}")
        fi
      done
      rtsp_error_timestamps=("${filtered_rtsp_error_timestamps[@]}")

      if (( ${#rtsp_error_timestamps[@]} >= STRICT_RTSP_ERROR_THRESHOLD )); then
        log ERROR "Detectados ${#rtsp_error_timestamps[@]} errores RTSP relevantes en los ultimos ${STRICT_RTSP_ERROR_WINDOW_SECONDS}s" | tee -a "${WATCHDOG_LOG}"
        for i in "${rtsp_error_timestamps[@]: -3}"; do
          log ERROR "RTSP reciente: ${i#*|}" | tee -a "${WATCHDOG_LOG}"
          last_rtsp_detail="${i#*|}"
        done
        request_restart "${child_pid}" "Errores RTSP repetidos" "${last_rtsp_detail}"
      fi
    fi

    if strict_rtmp_watchdog_enabled; then
      filtered_rtmp_error_timestamps=()
      for i in "${rtmp_error_timestamps[@]}"; do
        if (( now_epoch - ${i%%|*} <= STRICT_RTMP_ERROR_WINDOW_SECONDS )); then
          filtered_rtmp_error_timestamps+=("${i}")
        fi
      done
      rtmp_error_timestamps=("${filtered_rtmp_error_timestamps[@]}")

      if (( ${#rtmp_error_timestamps[@]} >= STRICT_RTMP_ERROR_THRESHOLD )); then
        log ERROR "Detectados ${#rtmp_error_timestamps[@]} errores RTMP/RTMPS relevantes en los ultimos ${STRICT_RTMP_ERROR_WINDOW_SECONDS}s" | tee -a "${WATCHDOG_LOG}"
        for i in "${rtmp_error_timestamps[@]: -3}"; do
          log ERROR "RTMP reciente: ${i#*|}" | tee -a "${WATCHDOG_LOG}"
          last_rtmp_detail="${i#*|}"
        done
        request_restart "${child_pid}" "Emision remota RTMP/RTMPS caida con ffmpeg vivo" "${last_rtmp_detail}"
      fi
    fi
  done

  return 0
}

while true; do
  log_project_process_counts "Estado previo del watchdog"
  log INFO "Arrancando pipeline supervisado" | tee -a "${WATCHDOG_LOG}"
  RESTART_REASON=""
  "${SCRIPT_DIR}/stream_youtube.sh" >>"${WATCHDOG_LOG}" 2>&1 &
  child_pid=$!

  if monitor_progress "${child_pid}"; then
    wait "${child_pid}" || true
  fi

  wait "${child_pid}" || exit_code=$?
  exit_code="${exit_code:-0}"
  rm -f "${PID_FILE}"

  if [[ -n "${RESTART_REASON}" ]]; then
    log WARN "Proceso finalizado con codigo ${exit_code} tras reinicio por: ${RESTART_REASON}" | tee -a "${WATCHDOG_LOG}"
  else
    log WARN "Proceso finalizado con codigo ${exit_code}" | tee -a "${WATCHDOG_LOG}"
  fi

  log_active_stream_pid "PID activo despues de finalizar el ciclo" | tee -a "${WATCHDOG_LOG}"

  if ! register_restart_attempt "$(date +%s)"; then
    exit 1
  fi

  if (( MAX_RESTARTS > 0 )); then
    RESTART_COUNT=$((RESTART_COUNT + 1))
    if (( RESTART_COUNT >= MAX_RESTARTS )); then
      log ERROR "Se alcanzo MAX_RESTARTS=${MAX_RESTARTS}" | tee -a "${WATCHDOG_LOG}"
      exit 1
    fi
  fi

  log INFO "Reinicio en ${RESTART_DELAY_SECONDS}s" | tee -a "${WATCHDOG_LOG}"
  sleep "${RESTART_DELAY_SECONDS}"
  unset exit_code
done
