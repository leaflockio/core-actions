#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Stack-agnostic coverage regression check.
# Compares a coverage percentage against .coverage-baseline.
# Usage: bash check-coverage.sh <percent> [tag]
#   e.g. bash check-coverage.sh 88.07
#   e.g. bash check-coverage.sh 88.07 shell

. "$(dirname "$0")/config.sh"

PERCENT="$1"
TAG="${2:-${COVERAGE_TAG:-}}"

if [ -z "$PERCENT" ]; then
  log_error "Usage: check-coverage.sh <percent> [tag]"
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

if [ -n "$TAG" ]; then
  # Tagged mode: parse "tag: value" format
  BASELINE=$(grep -E "^${TAG}:" "$BASELINE_FILE" | head -1 | sed 's/^[^:]*:[[:space:]]*//' | tr -d '[:space:]')
  if [ -z "$BASELINE" ]; then
    log_warn "Tag '${TAG}' not found in ${BASELINE_FILE}. Skipping delta check."
    log_info "Coverage: ${PERCENT}%"
    exit 0
  fi
else
  # Legacy mode: raw number (first non-comment, non-blank line)
  BASELINE_LINE=$(grep -v '^#' "$BASELINE_FILE" | grep -v '^$' | head -1 | tr -d '[:space:]')
  # Detect tagged file used without a tag
  if echo "$BASELINE_LINE" | grep -qE '^[a-zA-Z].*:'; then
    log_warn "Tagged ${BASELINE_FILE} detected but no tag provided. Skipping delta check."
    log_info "Coverage: ${PERCENT}%"
    exit 0
  fi
  BASELINE="$BASELINE_LINE"
fi

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
