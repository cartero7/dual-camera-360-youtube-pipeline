#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib.sh"

load_config
require_cmd ffmpeg timeout tee

RUN_ID="$(timestamp)"
LOG_FILE="${DIAGNOSTIC_LOG_DIR}/snapshot_${RUN_ID}.log"

{
  for entry in "cam1:${URL_RTSP_CAM1}" "cam2:${URL_RTSP_CAM2}"; do
    name="${entry%%:*}"
    url="${entry#*:}"
    mkdir -p "${ARTIFACTS_DIAGNOSTICS_DIR}/snapshots"
    out="${ARTIFACTS_DIAGNOSTICS_DIR}/snapshots/${name}_${RUN_ID}.jpg"

    log INFO "Capturando snapshot ${name} -> ${out}"
    timeout "${SNAPSHOT_TIMEOUT_SECONDS}" ffmpeg \
      -hide_banner \
      -loglevel error \
      -rtsp_transport "${RTSP_TRANSPORT}" \
      -i "${url}" \
      -frames:v 1 \
      -y \
      "${out}"
  done

  log INFO "Snapshots completados"
} 2>&1 | tee -a "${LOG_FILE}"
