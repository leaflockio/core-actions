#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Checks staged Python files are formatted with ruff.
# Requires: ruff

. "$(dirname "$0")/../common/config.sh"

FILES=$(echo "$CHECK_FILES" | grep '\.py$')

if [ -z "$FILES" ]; then
  log_info "No Python files to check for formatting."
  exit 0
fi

log_info "Checking Python formatting..."

if ! echo "$FILES" | xargs ruff format --check; then
  log_error "Formatting issues found."
  log_info "Run: ruff format ."
  exit 1
fi

log_success "Python format check passed."
