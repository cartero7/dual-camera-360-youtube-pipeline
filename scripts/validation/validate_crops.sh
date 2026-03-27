#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib.sh"

load_config

RUN_ID="$(timestamp)"
LOG_FILE="${VALIDATION_LOG_DIR}/validate_crops_${RUN_ID}.log"

pass_count=0

assert_crop_valid() {
  local label="$1"
  local auto_adjust="$2"
  local input_w="$3"
  local input_h="$4"
  local crop_spec="$5"
  local expected_crop="$6"

  AUTO_ADJUST_CROP="${auto_adjust}"
  resolve_crop_for_input "${label}" "${crop_spec}" "${input_w}" "${input_h}" || {
    log ERROR "${label}: se esperaba crop valido y fallo: ${RESOLVED_CROP_MESSAGE}"
    return 1
  }

  if [[ "${RESOLVED_CROP_VALUE}" != "${expected_crop}" ]]; then
    log ERROR "${label}: crop esperado ${expected_crop}, obtenido ${RESOLVED_CROP_VALUE}"
    return 1
  fi

  log INFO "${label}: OK -> ${RESOLVED_CROP_VALUE}"
  pass_count=$((pass_count + 1))
}

assert_crop_invalid() {
  local label="$1"
  local auto_adjust="$2"
  local input_w="$3"
  local input_h="$4"
  local crop_spec="$5"

  AUTO_ADJUST_CROP="${auto_adjust}"
  if resolve_crop_for_input "${label}" "${crop_spec}" "${input_w}" "${input_h}" >/dev/null; then
    log ERROR "${label}: se esperaba fallo y el crop fue aceptado"
    return 1
  fi

  log INFO "${label}: OK -> ${RESOLVED_CROP_MESSAGE}"
  pass_count=$((pass_count + 1))
}

{
  log INFO "Iniciando validacion de reglas de crop"

  assert_crop_invalid "case1_fail_1920x1080_2048" false 1920 1080 "2048:2048:950:0"
  assert_crop_valid "case1_adjust_1920x1080_2048" true 1920 1080 "2048:2048:950:0" "1080:1080:420:0"
  assert_crop_valid "case2_valid_1920x1080_1080" false 1920 1080 "1080:1080:420:0" "1080:1080:420:0"
  assert_crop_invalid "case3_fail_2560x1440_2048" false 2560 1440 "2048:2048:256:0"
  assert_crop_valid "case3_adjust_2560x1440_2048" true 2560 1440 "2048:2048:256:0" "1440:1440:560:0"
  assert_crop_valid "case4_valid_2560x1440_square" false 2560 1440 "1440:1440:560:0" "1440:1440:560:0"

  log INFO "Validacion de crops finalizada: ${pass_count} casos correctos"
} 2>&1 | tee -a "${LOG_FILE}"
