#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Runs Go tests with coverage and checks against baseline.

. "$(dirname "$0")/../common/config.sh"

log_info "Running Go tests with coverage..."

mkdir -p "$COVERAGE_DIR"

OUTPUT=$(go test -coverprofile="$COVERAGE_DIR/coverage.out" ./... 2>&1)
STATUS=$?

if [ "$STATUS" -ne 0 ]; then
  echo "$OUTPUT"
  log_error "Tests failed."
  exit 1
fi

PERCENT=$(go tool cover -func="$COVERAGE_DIR/coverage.out" | grep '^total:' | awk '{print $NF}' | tr -d '%')
go tool cover -html="$COVERAGE_DIR/coverage.out" -o "$COVERAGE_DIR/index.html"

if [ -z "$PERCENT" ]; then
  log_error "Could not extract coverage percentage."
  exit 1
fi

log_info "Coverage: ${PERCENT}%"
log_info "Report: ${COVERAGE_DIR}/index.html"
_tag=""
if command -v jq >/dev/null 2>&1; then
  _tag=$(echo "${COVERAGE_CONFIG_GO:-}" | jq -r '.tag // empty' 2>/dev/null)
fi
bash "$(dirname "$0")/../common/check-coverage.sh" "$PERCENT" "${_tag:-${COVERAGE_TAG:-}}" "${COVERAGE_CONFIG_GO:-}"
