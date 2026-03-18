#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Runs go vet on the entire module.

. "$(dirname "$0")/../common/utils.sh"

log_info "Running go vet..."

if ! go vet ./...; then
  log_error "go vet found issues. Fix them before committing."
  exit 1
fi

log_success "go vet passed."
