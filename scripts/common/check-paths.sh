#!/bin/sh
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Detects hardcoded absolute file paths in staged changes.
# Catches UNIX absolute paths (/) and Windows absolute paths (C:\).
# Skips shebangs, URLs, and known safe patterns.
#
# In staged mode: checks only new lines from the diff.
# In all mode: checks full file content.

. "$(dirname "$0")/config.sh"

if [ -z "$CHECK_FILES" ]; then
  log_success "No files to check for paths."
  exit 0
fi

FAIL=0

for f in $CHECK_FILES; do
  [ -f "$f" ] || continue

  # Skip binary-ish files
  case "$f" in
    *.png|*.jpg|*.gif|*.ico|*.woff|*.woff2|*.ttf|*.eot|*.lock) continue ;;
  esac

  # In staged mode, only check new lines from the diff
  # In all mode, check the full file
  if [ "$CHECK_MODE" = "all" ]; then
    CONTENT=$(cat "$f" 2>/dev/null || true)
  else
    CONTENT=$(git diff --cached -- "$f" \
      | grep '^+' \
      | grep -v '^+++' \
      || true)
  fi

  [ -z "$CONTENT" ] && continue

  # UNIX absolute paths: /word/word starting from root (not relative)
  # Requires space, quote, or start-of-line before the leading /
  # Excludes relative paths (../), command substitutions, .git/ paths
  UNIX_MATCHES=$(echo "$CONTENT" \
    | grep -E '(^|[[:space:]"'\''=])/[a-zA-Z][a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+' \
    | grep -vE '^\+?\s*#!' \
    | grep -vE '://' \
    | grep -vE '/dev/null' \
    | grep -vE '^\+?\s*(#|//|/\*|\*).*example' \
    | grep -vE 'import |from |require\(' \
    | grep -vE '/api/|/v[0-9]+/' \
    | grep -vE '\$\(|\.git/' \
    || true)

  if [ -n "$UNIX_MATCHES" ]; then
    log_error "Hardcoded UNIX path in: $f"
    echo "$UNIX_MATCHES" | while IFS= read -r line; do
      CLEAN=$(echo "$line" | sed 's/^+//')
      LINE_NUM=$(grep -nF "$CLEAN" "$f" 2>/dev/null | head -1 | cut -d: -f1)
      if [ -n "$LINE_NUM" ]; then
        echo "  $f:$LINE_NUM: $CLEAN"
      else
        echo "  $CLEAN"
      fi
    done
    FAIL=1
  fi

  # Windows absolute paths: C:\, D:\, etc.
  WIN_MATCHES=$(echo "$CONTENT" \
    | grep -E '[A-Z]:\\[A-Za-z]' \
    || true)

  if [ -n "$WIN_MATCHES" ]; then
    log_error "Hardcoded Windows path in: $f"
    echo "$WIN_MATCHES" | while IFS= read -r line; do
      CLEAN=$(echo "$line" | sed 's/^+//')
      LINE_NUM=$(grep -nF "$CLEAN" "$f" 2>/dev/null | head -1 | cut -d: -f1)
      if [ -n "$LINE_NUM" ]; then
        echo "  $f:$LINE_NUM: $CLEAN"
      else
        echo "  $CLEAN"
      fi
    done
    FAIL=1
  fi
done

if [ "$FAIL" -ne 0 ]; then
  echo ""
  log_error "Hardcoded absolute paths detected."
  log_info  "Replace with relative paths or environment variables."
  exit 1
fi

log_success "Path check passed."
