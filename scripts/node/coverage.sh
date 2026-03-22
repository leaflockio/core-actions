#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Runs Node tests with coverage and checks against baseline.
# Expects: npm run test:coverage in the consumer's package.json

. "$(dirname "$0")/../common/config.sh"

log_info "Running tests with coverage..."

OUTPUT=$(npm run "${COVERAGE_SCRIPT}" 2>&1)
STATUS=$?

if [ "$STATUS" -ne 0 ]; then
  echo "$OUTPUT"
  log_error "Tests failed."
  exit 1
fi

PERCENT=$(echo "$OUTPUT" | grep -i 'all files' | grep -oE '[0-9]+(\.[0-9]+)?' | head -1)

if [ -z "$PERCENT" ]; then
  log_error "Could not extract coverage percentage from test output."
  log_info "Ensure 'npm run test:coverage' outputs a summary with 'All files' and a percentage."
  exit 1
fi

COVERAGE_DIR="${COVERAGE_DIR:-coverage}"

log_info "Coverage: ${PERCENT}%"
log_info "Report: ${COVERAGE_DIR}/index.html"
bash "$(dirname "$0")/../common/check-coverage.sh" "$PERCENT" "${COVERAGE_TAG:-}"
