#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Centralized hook configuration. Reads .hooks-config and sets defaults.
# Source this in scripts that need configurable values.
# shellcheck disable=SC2034 # Variables are used by scripts that source this file.

SCRIPTS_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Load logging utilities
. "$SCRIPTS_DIR/utils.sh"

# ── Defaults ────────────────────────────────────────────────────────

PARTIAL_STAGE="${PARTIAL_STAGE:-fail}"
UNCOMMITTED_PUSH="${UNCOMMITTED_PUSH:-fail}"
MAX_FILE_SIZE="${MAX_FILE_SIZE:-1000000}"
MAX_FILE_LINES="${MAX_FILE_LINES:-2000}"
MAX_COMMIT_LINES="${MAX_COMMIT_LINES:-400}"
MAX_COMMIT_MSG_LENGTH="${MAX_COMMIT_MSG_LENGTH:-72}"
PROTECTED_BRANCHES="${PROTECTED_BRANCHES:-main master pre-main}"
LINK_CHECK_TIMEOUT="${LINK_CHECK_TIMEOUT:-5}"
COVERAGE_MAX_DROP="${COVERAGE_MAX_DROP:-0.05}"
COVERAGE_FLOOR="${COVERAGE_FLOOR:-95}"
COVERAGE_SRC="${COVERAGE_SRC:-scripts}"
COVERAGE_SCRIPT="${COVERAGE_SCRIPT:-test:coverage}"
COVERAGE_TAG="${COVERAGE_TAG:-}"
COVERAGE_DIR="${COVERAGE_DIR:-coverage}"
COVERAGE_CONFIG_NODE="${COVERAGE_CONFIG_NODE:-}"
COVERAGE_CONFIG_SHELL="${COVERAGE_CONFIG_SHELL:-}"
COVERAGE_CONFIG_GO="${COVERAGE_CONFIG_GO:-}"
COVERAGE_CONFIG_PYTHON="${COVERAGE_CONFIG_PYTHON:-}"
CHECK_MODE="${CHECK_MODE:-staged}"
CHECK_PATHS_SKIP_FILES="${CHECK_PATHS_SKIP_FILES:-[]}"

# ── Override from .hooks-config ─────────────────────────────────────

if [ -f ".hooks-config" ]; then
  while IFS='=' read -r key value; do
    case "$key" in
    '' | \#*) continue ;;
    esac
    case "$key" in
    PARTIAL_STAGE) PARTIAL_STAGE="$value" ;;
    UNCOMMITTED_PUSH) UNCOMMITTED_PUSH="$value" ;;
    MAX_FILE_SIZE) MAX_FILE_SIZE="$value" ;;
    MAX_FILE_LINES) MAX_FILE_LINES="$value" ;;
    MAX_COMMIT_LINES) MAX_COMMIT_LINES="$value" ;;
    MAX_COMMIT_MSG_LENGTH) MAX_COMMIT_MSG_LENGTH="$value" ;;
    PROTECTED_BRANCHES) PROTECTED_BRANCHES="$value" ;;
    LINK_CHECK_TIMEOUT) LINK_CHECK_TIMEOUT="$value" ;;
    COVERAGE_MAX_DROP) COVERAGE_MAX_DROP="$value" ;;
    COVERAGE_FLOOR) COVERAGE_FLOOR="$value" ;;
    COVERAGE_SRC) COVERAGE_SRC="$value" ;;
    COVERAGE_SCRIPT) COVERAGE_SCRIPT="$value" ;;
    COVERAGE_TAG) COVERAGE_TAG="$value" ;;
    COVERAGE_DIR) COVERAGE_DIR="$value" ;;
    COVERAGE_CONFIG_NODE) COVERAGE_CONFIG_NODE="$value" ;;
    COVERAGE_CONFIG_SHELL) COVERAGE_CONFIG_SHELL="$value" ;;
    COVERAGE_CONFIG_GO) COVERAGE_CONFIG_GO="$value" ;;
    COVERAGE_CONFIG_PYTHON) COVERAGE_CONFIG_PYTHON="$value" ;;
    CHECK_MODE) CHECK_MODE="$value" ;;
    CHECK_PATHS_SKIP_FILES) CHECK_PATHS_SKIP_FILES="$value" ;;
    esac
  done <<<"$(cat .hooks-config)"
fi

# ── File list ───────────────────────────────────────────────────────
# Populated based on CHECK_MODE. Scripts filter locally as needed.

case "$CHECK_MODE" in
all)
  CHECK_FILES=$(git ls-files)
  ;;
pr)
  if [ -z "${PR_BASE_SHA:-}" ]; then
    log_error "CHECK_MODE=pr requires PR_BASE_SHA to be set."
    exit 1
  fi
  CHECK_FILES=$(git diff --name-only --diff-filter=ACMR "$PR_BASE_SHA"...HEAD)
  ;;
*)
  CHECK_FILES=$(git diff --cached --name-only --diff-filter=ACMR)
  ;;
esac
