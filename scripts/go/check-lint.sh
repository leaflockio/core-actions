#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Runs golangci-lint on the entire module.

. "$(dirname "$0")/../common/utils.sh"

log_info "Running golangci-lint..."

if ! golangci-lint run ./...; then
  log_error "golangci-lint found issues. Fix them before committing."
  exit 1
fi

log_success "golangci-lint passed."
