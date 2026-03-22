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

SUMMARY_FILE="${COVERAGE_DIR}/coverage-summary.json"

if [ ! -f "$SUMMARY_FILE" ]; then
  log_error "Coverage summary not found at ${SUMMARY_FILE}."
  log_info "Ensure '${COVERAGE_SCRIPT}' generates a json-summary report."
  exit 1
fi

# Compute overall coverage: sum all covered / sum all total across all four metrics
PERCENT=$(jq -r '.total | (.lines.covered + .statements.covered + .functions.covered + .branches.covered) / (.lines.total + .statements.total + .functions.total + .branches.total) * 100 | . * 100 | floor / 100' "$SUMMARY_FILE")

if [ -z "$PERCENT" ] || [ "$PERCENT" = "null" ]; then
  log_error "Could not extract coverage from ${SUMMARY_FILE}."
  exit 1
fi

log_info "Coverage: ${PERCENT}%"
log_info "Report: ${COVERAGE_DIR}/index.html"
bash "$(dirname "$0")/../common/check-coverage.sh" "$PERCENT" "${COVERAGE_TAG:-}"
