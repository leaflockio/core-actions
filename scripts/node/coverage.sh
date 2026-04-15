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

_SUMMARY_FILE=$(echo "${COVERAGE_CONFIG_NODE:-}" | jq -r '.summaryFile // empty' 2>/dev/null)
SUMMARY_FILE="${_SUMMARY_FILE:-${COVERAGE_DIR}/coverage-summary.json}"

if [ ! -f "$SUMMARY_FILE" ]; then
  log_error "Coverage summary not found at ${SUMMARY_FILE}."
  log_info "Ensure '${COVERAGE_SCRIPT}' generates a json-summary report (Istanbul format)."
  log_info "Override path via summaryFile in COVERAGE_CONFIG_NODE if needed."
  exit 1
fi

# Extract all four metrics as a single JSON object
METRICS=$(jq -c '{lines:.total.lines.pct,statements:.total.statements.pct,functions:.total.functions.pct,branches:.total.branches.pct}' "$SUMMARY_FILE")

if [ -z "$METRICS" ] || ! echo "$METRICS" | jq -e '[.lines,.statements,.functions,.branches] | all(. != null)' >/dev/null 2>&1; then
  log_error "Could not extract coverage metrics from ${SUMMARY_FILE}."
  exit 1
fi

log_info "Report: ${COVERAGE_DIR}/index.html"
_tag=$(echo "${COVERAGE_CONFIG_NODE:-}" | jq -r '.tag // empty' 2>/dev/null)
bash "$(dirname "$0")/../common/check-coverage.sh" "$METRICS" "${_tag:-${COVERAGE_TAG:-}}"
