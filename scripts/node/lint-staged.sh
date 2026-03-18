#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Runs lint-staged to lint only staged files.
# Requires: lint-staged configured in package.json

. "$(dirname "$0")/../common/utils.sh"

log_info "Running lint-staged..."

if ! npx lint-staged; then
  log_error "lint-staged failed. Fix the issues above and re-stage the files."
  exit 1
fi

log_success "lint-staged passed."
