#!/bin/sh
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Blocks commits containing bare to-do or fix-me markers without a ticket number.
# Every marker must have a trackable issue reference in parentheses.
#
# Accepted: marker(#123), marker(PROJ-789)
# Rejected: bare marker without parenthesized ticket
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
  case "$f" in
  *.png | *.jpg | *.gif | *.ico | *.svg | *.woff | *.woff2 | *.ttf | *.eot) continue ;;
  *.lock | *.min.js | *.min.css | *.map) continue ;;
  esac

  # In staged mode, only check new lines from the diff
  # In all mode, check the full file
  if [ "$CHECK_MODE" = "all" ]; then
    CONTENT=$(cat "$f" 2>/dev/null || true)
  else
    CONTENT=$(git diff --cached -- "$f" |
      grep '^+' |
      grep -v '^+++' ||
      true)
  fi

  [ -z "$CONTENT" ] && continue

  # Find bare markers without a ticket reference like (#123) or (PROJ-123)
  # Skip lines where the marker appears inside quotes or as part of a variable name
  BARE_TODOS=$(echo "$CONTENT" |
    grep -E '(TODO|FIXME)' |
    grep -vE '(TODO|FIXME)\([A-Za-z]*#?[0-9]+\)' |
    grep -vE "['\"].*TODO|TODO.*['\"]" |
    grep -vE "['\"].*FIXME|FIXME.*['\"]" |
    grep -vE '[A-Z_](TODO|FIXME)|(TODO|FIXME)[A-Z_]' ||
    true)

  if [ -n "$BARE_TODOS" ]; then
    log_error "Bare TODO/FIXME without ticket number in: $f"
    # Match each flagged line against the file to get line numbers
    echo "$BARE_TODOS" | while IFS= read -r line; do
      # Strip the leading + from diff output for matching
      CLEAN=$(echo "$line" | sed 's/^+//')
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
  log_info "Every marker must reference a ticket: TODO(#123) or FIXME(PROJ-456)"
  exit 1
fi

log_success "TODO check passed."
