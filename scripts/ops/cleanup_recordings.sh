#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib.sh"

load_config
require_cmd find tee

LOG_FILE="${OPS_LOG_DIR}/cleanup_recordings_$(timestamp).log"

{
  log INFO "Limpiando grabaciones con antiguedad > ${RECORDINGS_KEEP_DAYS} dias"
  find "${RECORDINGS_DIR}" -type f -name "*.${SEGMENT_FORMAT}" -mtime +"${RECORDINGS_KEEP_DAYS}" -print -delete
  log INFO "Limpieza completada"
} 2>&1 | tee -a "${LOG_FILE}"
