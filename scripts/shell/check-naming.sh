#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Enforces kebab-case naming for shell scripts.

. "$(dirname "$0")/../common/utils.sh"

STAGED=$(git diff --cached --name-only --diff-filter=ACMR | grep '\.sh$')

if [ -z "$STAGED" ]; then
  log_info "No shell files staged for naming check."
  exit 0
fi

FAIL=0

while IFS= read -r FILE; do
  BASE=$(basename "$FILE")

  if ! echo "$BASE" | grep -qE '^[a-z][a-z0-9.-]*\.sh$'; then
    log_error "Invalid shell filename: $FILE"
    log_info "Use kebab-case (e.g. check-branch.sh, run-tests.sh)"
    FAIL=1
  fi
done <<<"$STAGED"

[ "$FAIL" -eq 0 ] && log_success "Shell naming check passed." || exit 1
