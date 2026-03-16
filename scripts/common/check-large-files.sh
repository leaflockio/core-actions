#!/bin/sh
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Blocks commits containing files larger than MAX_FILE_SIZE bytes.
# Prevents large binaries and assets from bloating the git history.
#
# Configurable via .hooks-config at repo root:
#   MAX_FILE_SIZE=1000000  (default 1MB)

. "$(dirname "$0")/config.sh"

if [ -z "$CHECK_FILES" ]; then
  log_success "Large file check passed."
  exit 0
fi

FAIL=0

for f in $CHECK_FILES; do
  [ -f "$f" ] || continue
  SIZE=$(wc -c <"$f")
  if [ "$SIZE" -gt "$MAX_FILE_SIZE" ]; then
    log_error "File too large: $f (${SIZE} bytes, max ${MAX_FILE_SIZE})"
    FAIL=1
  fi
done

if [ "$FAIL" -ne 0 ]; then
  echo ""
  log_info "Consider using Git LFS for large assets."
  exit 1
fi

log_success "Large file check passed."
