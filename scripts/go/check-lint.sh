#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Runs golangci-lint on changed Go files only.

. "$(dirname "$0")/../common/config.sh"

FILES=$(echo "$CHECK_FILES" | grep '\.go$')

if [ -z "$FILES" ]; then
  log_info "No Go files to lint."
  exit 0
fi

mapfile -t PACKAGES < <(echo "$FILES" | xargs dirname | sort -u | sed 's|^[^./]|./&|')

log_info "Running golangci-lint..."

if ! golangci-lint run "${PACKAGES[@]}"; then
  log_error "Go lint check failed. Fix the issues above."
  exit 1
fi

log_success "Go lint check passed."
