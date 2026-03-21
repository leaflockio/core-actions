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
BELOW_FLOOR=$(awk -v p="$PERCENT" -v f="$COVERAGE_FLOOR" 'BEGIN { print (p < f) ? 1 : 0 }')
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

BASELINE=$(tr -d '[:space:]' <"$BASELINE_FILE")
if [ -z "$BASELINE" ]; then
  log_warn "Empty ${BASELINE_FILE}. Skipping delta check."
  log_info "Coverage: ${PERCENT}%"
  exit 0
fi

DROP=$(awk -v b="$BASELINE" -v p="$PERCENT" 'BEGIN { printf "%.2f", b - p }')
EXCEEDED=$(awk -v d="$DROP" -v m="$COVERAGE_MAX_DROP" 'BEGIN { print (d > m) ? 1 : 0 }')

if [ "$EXCEEDED" -eq 1 ]; then
  log_error "Coverage dropped ${DROP}% (${BASELINE}% → ${PERCENT}%). Max allowed drop: ${COVERAGE_MAX_DROP}%."
  exit 1
fi

NO_CHANGE=$(awk -v d="$DROP" 'BEGIN { print (d == 0) ? 1 : 0 }')
IMPROVED=$(awk -v d="$DROP" 'BEGIN { print (d < 0) ? 1 : 0 }')
if [ "$NO_CHANGE" -eq 1 ]; then
  log_success "Coverage: ${PERCENT}% (baseline: ${BASELINE}%)"
elif [ "$IMPROVED" -eq 1 ]; then
  GAIN=$(awk -v p="$PERCENT" -v b="$BASELINE" 'BEGIN { printf "%.2f", p - b }')
  log_success "Coverage: ${PERCENT}% (baseline: ${BASELINE}%, +${GAIN}%)"
else
  log_success "Coverage: ${PERCENT}% (baseline: ${BASELINE}%, -${DROP}%)"
fi
