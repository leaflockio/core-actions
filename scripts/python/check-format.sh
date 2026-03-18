#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Checks staged Python files are formatted with ruff.
# Requires: ruff

. "$(dirname "$0")/../common/utils.sh"

STAGED=$(git diff --cached --name-only --diff-filter=ACMR | grep '\.py$')

if [ -z "$STAGED" ]; then
  log_info "No Python files staged."
  exit 0
fi

log_info "Checking Python formatting..."

if ! echo "$STAGED" | xargs ruff format --check; then
  log_error "Formatting issues found."
  log_info "Run: ruff format ."
  exit 1
fi

log_success "Format check passed."
