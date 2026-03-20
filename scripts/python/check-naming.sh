#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Enforces snake_case file and folder naming for Python projects.

. "$(dirname "$0")/../common/config.sh"

FILES=$(echo "$CHECK_FILES" | grep '\.py$')

if [ -z "$FILES" ]; then
  log_info "No Python files to check for naming."
  exit 0
fi

FAIL=0
CHECKED_DIRS=""

while IFS= read -r FILE; do

  # --- Folder checks ---
  DIR=$(dirname "$FILE")
  if [ "$DIR" != "." ]; then
    IFS='/' read -ra SEGMENTS <<<"$DIR"
    for SEG in "${SEGMENTS[@]}"; do
      echo "$CHECKED_DIRS" | grep -qF "|$SEG|" && continue
      CHECKED_DIRS="$CHECKED_DIRS|$SEG|"

      # Skip hidden folders
      case "$SEG" in .*) continue ;; esac

      # Skip double-underscore dirs (__pycache__, __init__, etc.)
      case "$SEG" in __*__) continue ;; esac

      # Must be snake_case
      if ! echo "$SEG" | grep -qE '^[a-z][a-z0-9_]*$'; then
        log_error "Invalid Python folder name: $SEG (in $FILE)"
        log_info "Use snake_case (e.g. my_package, utils)"
        FAIL=1
      fi
    done
  fi

  # --- File checks ---
  BASE=$(basename "$FILE")

  case "$BASE" in
  __init__.py | __main__.py) continue ;;
  esac

  if ! echo "$BASE" | grep -qE '^[a-z][a-z0-9_]*\.py$'; then
    log_error "Invalid Python filename: $FILE"
    log_info "Use snake_case (e.g. user_service.py)"
    FAIL=1
  fi
done <<<"$FILES"

[ "$FAIL" -eq 0 ] && log_success "Python naming check passed." || exit 1
