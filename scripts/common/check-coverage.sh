#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Stack-agnostic coverage regression check.
# Compares a coverage percentage against .coverage-baseline.
# Usage: bash check-coverage.sh <percent>
#   e.g. bash check-coverage.sh 88.07

. "$(dirname "$0")/config.sh"

PERCENT="$1"

if [ -z "$PERCENT" ]; then
  log_error "Usage: check-coverage.sh <percent>"
  exit 1
fi

BASELINE_FILE=".coverage-baseline"

# Floor check — absolute minimum
BELOW_FLOOR=$(awk "BEGIN { print ($PERCENT < $COVERAGE_FLOOR) ? 1 : 0 }")
if [ "$BELOW_FLOOR" -eq 1 ]; then
  log_error "Coverage ${PERCENT}% is below floor threshold (${COVERAGE_FLOOR}%)."
  exit 1
fi

# Delta check — compare against baseline
if [ ! -f "$BASELINE_FILE" ]; then
  log_warn "No ${BASELINE_FILE} found. Skipping delta check."
  log_info "Coverage: ${PERCENT}%"
  exit 0
fi

BASELINE=$(cat "$BASELINE_FILE" | tr -d '[:space:]')
if [ -z "$BASELINE" ]; then
  log_warn "Empty ${BASELINE_FILE}. Skipping delta check."
  log_info "Coverage: ${PERCENT}%"
  exit 0
fi

DROP=$(awk "BEGIN { printf \"%.2f\", $BASELINE - $PERCENT }")
EXCEEDED=$(awk "BEGIN { print ($DROP > $COVERAGE_MAX_DROP) ? 1 : 0 }")

if [ "$EXCEEDED" -eq 1 ]; then
  log_error "Coverage dropped ${DROP}% (${BASELINE}% → ${PERCENT}%). Max allowed drop: ${COVERAGE_MAX_DROP}%."
  exit 1
fi

IMPROVED=$(awk "BEGIN { print ($DROP < 0) ? 1 : 0 }")
if [ "$IMPROVED" -eq 1 ]; then
  GAIN=$(awk "BEGIN { printf \"%.2f\", $PERCENT - $BASELINE }")
  log_success "Coverage: ${PERCENT}% (baseline: ${BASELINE}%, +${GAIN}%)"
else
  log_success "Coverage: ${PERCENT}% (baseline: ${BASELINE}%, -${DROP}%)"
fi
