#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Enforces snake_case file and lowercase folder naming for Go projects.

. "$(dirname "$0")/../common/utils.sh"

STAGED=$(git diff --cached --name-only --diff-filter=ACMR | grep '\.go$')

if [ -z "$STAGED" ]; then
  log_info "No Go files staged."
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

      # Must be lowercase alphanumeric (Go package convention)
      if ! echo "$SEG" | grep -qE '^[a-z][a-z0-9]*$'; then
        log_error "Invalid Go folder name: $SEG (in $FILE)"
        log_info "Use lowercase (e.g. httputil, testdata, internal)"
        FAIL=1
      fi
    done
  fi

  # --- File checks ---
  BASE=$(basename "$FILE")

  if ! echo "$BASE" | grep -qE '^[a-z][a-z0-9_]*\.go$'; then
    log_error "Invalid Go filename: $FILE"
    log_info "Use snake_case (e.g. user_service.go, user_service_test.go)"
    FAIL=1
  fi
done <<<"$STAGED"

[ "$FAIL" -eq 0 ] && log_success "Go naming check passed." || exit 1
