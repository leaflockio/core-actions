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

log_info "Running golangci-lint..."

PATCH=$(mktemp)
git diff --cached -- '*.go' >"$PATCH"

if ! golangci-lint run --new-from-patch "$PATCH" ./...; then
  rm -f "$PATCH"
  log_error "Go lint check failed. Fix the issues above."
  exit 1
fi

rm -f "$PATCH"
log_success "Go lint check passed."
