#!/bin/sh
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Blocks commits containing source files that exceed MAX_FILE_LINES lines.
# Encourages modular code by preventing files from growing too large.
#
# Configurable via .hooks-config at repo root:
#   MAX_FILE_LINES=2000  (default 2000 lines per file)

. "$(dirname "$0")/config.sh"

if [ -z "$CHECK_FILES" ]; then
  exit 0
fi

FAIL=0

for f in $CHECK_FILES; do
  [ -f "$f" ] || continue

  # Only check source files, skip binaries and generated files
  case "$f" in
    *.png|*.jpg|*.gif|*.ico|*.svg|*.woff|*.woff2|*.ttf|*.eot) continue ;;
    *.lock|*.min.js|*.min.css|*.map) continue ;;
    CHANGELOG.md|LICENSE*) continue ;;
  esac

  LINES=$(wc -l < "$f" | tr -d ' ')
  if [ "$LINES" -gt "$MAX_FILE_LINES" ]; then
    log_error "File too long: $f ($LINES lines, max $MAX_FILE_LINES)"
    FAIL=1
  fi
done

if [ "$FAIL" -ne 0 ]; then
  echo ""
  log_info "Consider breaking large files into smaller modules."
  exit 1
fi

log_success "File length check passed."
