#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Runs Python tests with coverage and checks against baseline.
# Expects: pytest with pytest-cov installed.

. "$(dirname "$0")/../common/config.sh"

log_info "Running Python tests with coverage..."

mkdir -p "$COVERAGE_DIR"

OUTPUT=$(python -m pytest --cov --cov-report=html:"$COVERAGE_DIR" --cov-report=term 2>&1)
STATUS=$?

if [ "$STATUS" -ne 0 ]; then
  echo "$OUTPUT"
  log_error "Tests failed."
  exit 1
fi

PERCENT=$(echo "$OUTPUT" | grep '^TOTAL' | grep -oE '[0-9]+%' | tr -d '%')

if [ -z "$PERCENT" ]; then
  log_error "Could not extract coverage percentage from pytest output."
  exit 1
fi

log_info "Coverage: ${PERCENT}%"
log_info "Report: ${COVERAGE_DIR}/index.html"
_tag=""
if command -v jq >/dev/null 2>&1; then
  _tag=$(echo "${COVERAGE_CONFIG_PYTHON:-}" | jq -r '.tag // empty' 2>/dev/null)
fi
bash "$(dirname "$0")/../common/check-coverage.sh" "$PERCENT" "${_tag:-${COVERAGE_TAG:-}}" "${COVERAGE_CONFIG_PYTHON:-}"
