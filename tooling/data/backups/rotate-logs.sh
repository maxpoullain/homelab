#!/bin/bash

# Log Rotation Script
# Truncates each backup log to the last 500 lines.
#
# Usage:
#   ./rotate-logs.sh              # Truncate all logs
#   ./rotate-logs.sh --lines 200  # Keep last 200 lines instead

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEEP_LINES=500

if [ "${1}" = "--lines" ] && [ -n "${2}" ]; then
  KEEP_LINES="$2"
fi

truncate_log() {
  local log_file="$1"

  if [ ! -f "$log_file" ]; then
    return
  fi

  local total_lines
  total_lines=$(wc -l < "$log_file")

  if [ "$total_lines" -le "$KEEP_LINES" ]; then
    return
  fi

  local tmp
  tmp="$(mktemp)"
  tail -n "$KEEP_LINES" "$log_file" > "$tmp" && mv "$tmp" "$log_file"
  echo "Truncated $(basename "$log_file"): $total_lines → $KEEP_LINES lines"
}

truncate_log "$SCRIPT_DIR/backup-services.log"
truncate_log "$SCRIPT_DIR/backup-truenas.log"
