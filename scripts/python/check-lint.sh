#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Lints staged Python files with ruff.
# Requires: ruff

. "$(dirname "$0")/../common/utils.sh"

STAGED=$(git diff --cached --name-only --diff-filter=ACMR | grep '\.py$')

if [ -z "$STAGED" ]; then
  log_info "No Python files staged."
  exit 0
fi

log_info "Running ruff lint..."

if ! echo "$STAGED" | xargs ruff check; then
  log_error "Lint failed. Fix the issues above."
  exit 1
fi

log_success "Lint passed."
