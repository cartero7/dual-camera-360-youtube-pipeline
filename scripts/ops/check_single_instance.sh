#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib.sh"

load_config
require_cmd ps pgrep awk

active_count="$(count_active_project_ffmpeg)"

echo "pgrep:"
pgrep -af -- "ffmpeg .*${PROGRESS_FILE}" || true
echo
echo "ps:"
ps -eo pid,ppid,stat,cmd | grep -E "[f]fmpeg|[r]un_ffmpeg_once.sh|[w]atchdog.sh" || true
echo
echo "active_ffmpeg_count=${active_count}"

if (( active_count > 1 )); then
  exit 1
fi
