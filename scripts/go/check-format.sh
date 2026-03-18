#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Checks that staged Go files are formatted with gofmt.

. "$(dirname "$0")/../common/utils.sh"

STAGED=$(git diff --cached --name-only --diff-filter=ACMR | grep '\.go$')

if [ -z "$STAGED" ]; then
  log_info "No Go files staged."
  exit 0
fi

UNFORMATTED=$(echo "$STAGED" | xargs gofmt -l)

if [ -n "$UNFORMATTED" ]; then
  log_error "Unformatted Go files detected:"
  printf '  - %s\n' "$UNFORMATTED"
  log_info "Run: gofmt -w ."
  exit 1
fi

log_success "Go format check passed."
