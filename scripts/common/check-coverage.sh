#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Stack-agnostic coverage regression check.
# Compares coverage against .coverage-baseline.
#
# Usage (number mode — shell, go, python):
#   bash check-coverage.sh <percent> [tag]
#   e.g. bash check-coverage.sh 88.07
#   e.g. bash check-coverage.sh 88.07 shell
#
# Usage (JSON mode — node, per-metric):
#   bash check-coverage.sh <metrics_json> [tag]
#   COVERAGE_FLOOR must be a JSON object: {"lines":80,"statements":80,"functions":75,"branches":70}
#   or a plain number applied to all metrics.
#   COVERAGE_MAX_DROP is a plain number (single delta for all metrics).
#
# Note: JSON values in .hooks-config must not contain '=' characters.
#   Use compact JSON without spaces. See docs/hooks-config.md for examples.

. "$(dirname "$0")/config.sh"

INPUT="$1"
TAG="${2:-${COVERAGE_TAG:-}}"

if [ -z "$INPUT" ]; then
  log_error "Usage: check-coverage.sh <percent|metrics_json> [tag]"
  exit 1
fi

BASELINE_FILE=".coverage-baseline"

# ── JSON mode (node — per-metric) ────────────────────────────────────

if echo "$INPUT" | grep -q '^{'; then
  METRICS_JSON="$INPUT"

  # Resolve floor and delta — prefer COVERAGE_CONFIG_NODE over legacy env vars.
  # COVERAGE_CONFIG_NODE is read directly here because config.sh re-reads .hooks-config
  # when check-coverage.sh is sourced, which would override any COVERAGE_FLOOR export
  # set by the calling runner script.
  if [ -n "${COVERAGE_CONFIG_NODE:-}" ]; then
    _NODE_FLOOR=$(echo "$COVERAGE_CONFIG_NODE" | jq -c '.floor')
    _NODE_DELTA=$(echo "$COVERAGE_CONFIG_NODE" | jq -r '.delta')
  else
    _NODE_FLOOR="$COVERAGE_FLOOR"
    _NODE_DELTA="$COVERAGE_MAX_DROP"
  fi

  # _NODE_FLOOR may be a JSON object (per-metric) or a plain number (applies to all metrics)
  if echo "$_NODE_FLOOR" | grep -q '^{'; then
    FLOOR_JSON="$_NODE_FLOOR"
  else
    FLOOR_JSON="{\"lines\":${_NODE_FLOOR},\"statements\":${_NODE_FLOOR},\"functions\":${_NODE_FLOOR},\"branches\":${_NODE_FLOOR}}"
  fi

  # Read raw baseline value
  BASELINE_RAW=""
  if [ ! -f "$BASELINE_FILE" ]; then
    log_warn "No ${BASELINE_FILE} found. Skipping delta check."
  elif [ -n "$TAG" ]; then
    BASELINE_RAW=$(grep -E "^${TAG}:" "$BASELINE_FILE" | head -1 | sed 's/^[^:]*:[[:space:]]*//' | tr -d '[:space:]')
    if [ -z "$BASELINE_RAW" ]; then
      log_warn "Tag '${TAG}' not found in ${BASELINE_FILE}. Skipping delta check."
    fi
  else
    FIRST_LINE=$(grep -v '^#' "$BASELINE_FILE" | grep -v '^$' | head -1 | tr -d '[:space:]')
    if echo "$FIRST_LINE" | grep -qE '^[a-zA-Z][^{]*:'; then
      log_warn "Tagged ${BASELINE_FILE} detected but no tag provided. Skipping delta check."
    else
      BASELINE_RAW="$FIRST_LINE"
    fi
  fi

  # Baseline must be JSON — warn and skip delta if it's a plain number (migration path)
  if [ -n "$BASELINE_RAW" ] && ! echo "$BASELINE_RAW" | grep -q '^{'; then
    log_warn "Baseline is a plain number — migrate to JSON format for per-metric tracking. Skipping delta check."
    BASELINE_RAW=""
  fi

  FAILED=0
  for METRIC in lines statements functions branches; do
    PCT=$(echo "$METRICS_JSON" | jq -r ".${METRIC}")
    FLOOR_VAL=$(echo "$FLOOR_JSON" | jq -r ".${METRIC}")

    # Floor check
    BELOW_FLOOR=$(awk -v p="$PCT" -v f="$FLOOR_VAL" 'BEGIN { print (p < f) ? 1 : 0 }')
    if [ "$BELOW_FLOOR" -eq 1 ]; then
      log_error "${METRIC}: ${PCT}% is below floor (${FLOOR_VAL}%)."
      FAILED=1
      continue
    fi

    # Delta check
    if [ -z "$BASELINE_RAW" ]; then
      log_info "${METRIC}: ${PCT}% (no baseline)"
      continue
    fi

    BASELINE_VAL=$(echo "$BASELINE_RAW" | jq -r ".${METRIC}" 2>/dev/null)
    if [ -z "$BASELINE_VAL" ] || [ "$BASELINE_VAL" = "null" ]; then
      log_warn "${METRIC}: not found in baseline. Skipping delta check."
      log_info "${METRIC}: ${PCT}%"
      continue
    fi

    DROP=$(awk -v b="$BASELINE_VAL" -v p="$PCT" 'BEGIN { printf "%.2f", b - p }')
    EXCEEDED=$(awk -v d="$DROP" -v m="$_NODE_DELTA" 'BEGIN { print (d > m) ? 1 : 0 }')
    if [ "$EXCEEDED" -eq 1 ]; then
      log_error "${METRIC}: dropped ${DROP}% (${BASELINE_VAL}% → ${PCT}%). Max allowed: ${_NODE_DELTA}%."
      FAILED=1
      continue
    fi

    NO_CHANGE=$(awk -v d="$DROP" 'BEGIN { print (d == 0) ? 1 : 0 }')
    IMPROVED=$(awk -v d="$DROP" 'BEGIN { print (d < 0) ? 1 : 0 }')
    if [ "$NO_CHANGE" -eq 1 ]; then
      log_success "${METRIC}: ${PCT}% (baseline: ${BASELINE_VAL}%)"
    elif [ "$IMPROVED" -eq 1 ]; then
      GAIN=$(awk -v p="$PCT" -v b="$BASELINE_VAL" 'BEGIN { printf "%.2f", p - b }')
      log_success "${METRIC}: ${PCT}% (+${GAIN}% from ${BASELINE_VAL}%)"
    else
      log_success "${METRIC}: ${PCT}% (-${DROP}% from ${BASELINE_VAL}%)"
    fi
  done

  [ "$FAILED" -eq 1 ] && exit 1
  exit 0
fi

# ── Number mode (shell, go, python — single percent) ─────────────────

PERCENT="$INPUT"

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
