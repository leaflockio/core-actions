#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Blocks commits containing bare to-do or fix-me markers without a ticket number.
# Every marker must have a trackable issue reference in parentheses.
#
# Accepted: marker(#123), marker(KEY-789)
# Rejected: bare marker, marker(123), marker(username)
#
# In staged mode: checks only new lines from the diff.
# In all mode: checks full file content.

. "$(dirname "$0")/config.sh"
if [ -z "$CHECK_FILES" ]; then
  exit 0
fi

FAIL=0

for f in $CHECK_FILES; do
  [ -f "$f" ] || continue

  # Skip binaries and generated files
  is_skippable_file "$f" && continue

  CONTENT=$(get_file_content "$f" "$CHECK_MODE")

  [ -z "$CONTENT" ] && continue

  # Find bare markers without a ticket reference like (#123) or (KEY-123)
  # Skip lines where the marker appears inside quotes or as part of a variable name
  BARE_TODOS=$(echo "$CONTENT" | grep -E '(TODO|FIXME)' || true)
  BARE_TODOS=$(echo "$BARE_TODOS" | grep -vE '(TODO|FIXME)\((#[0-9]+|[A-Z]+-[0-9]+)\)' || true)
  BARE_TODOS=$(echo "$BARE_TODOS" | grep -vE "['\"].*TODO|TODO.*['\"]" || true)
  BARE_TODOS=$(echo "$BARE_TODOS" | grep -vE "['\"].*FIXME|FIXME.*['\"]" || true)
  BARE_TODOS=$(echo "$BARE_TODOS" | grep -vE '[A-Z_](TODO|FIXME)|(TODO|FIXME)[A-Z_]' || true)

  if [ -n "$BARE_TODOS" ]; then
    log_error "Bare TODO/FIXME without ticket number in: $f"
    # Match each flagged line against the file to get line numbers
    echo "$BARE_TODOS" | while IFS= read -r line; do
      # Strip the leading + from diff output for matching
      CLEAN="${line#+}"
      LINE_NUM=$(grep -nF "$CLEAN" "$f" 2>/dev/null | head -1 | cut -d: -f1)
      if [ -n "$LINE_NUM" ]; then
        echo "  $f:$LINE_NUM: $CLEAN"
      else
        echo "  $CLEAN"
      fi
    done
    echo ""
    FAIL=1
  fi
done

if [ "$FAIL" -ne 0 ]; then
  echo ""
  log_info "Every marker must reference a ticket: marker(#123) or marker(KEY-456)"
  exit 1
fi

log_success "TODO check passed."
