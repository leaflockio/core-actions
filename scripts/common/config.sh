#!/bin/sh
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Centralized hook configuration. Reads .hooks-config and sets defaults.
# Source this in scripts that need configurable values.
# shellcheck disable=SC2034 # Variables are used by scripts that source this file.

SCRIPTS_DIR="$(dirname "$0")"

# Load logging utilities
. "$SCRIPTS_DIR/utils.sh"

# ── Defaults ────────────────────────────────────────────────────────

PARTIAL_STAGE="fail"
UNCOMMITTED_PUSH="fail"
MAX_FILE_SIZE=1000000
MAX_FILE_LINES=2000
MAX_COMMIT_LINES=400
MAX_COMMIT_MSG_LENGTH=72
PROTECTED_BRANCHES="main master pre-main"
LINK_CHECK_TIMEOUT=5
COVERAGE_MAX_DROP=0.05
COVERAGE_FLOOR=95
CHECK_MODE="staged"

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
    CHECK_MODE) CHECK_MODE="$value" ;;
    esac
  done <.hooks-config
fi

# ── File list ───────────────────────────────────────────────────────
# Populated based on CHECK_MODE. Scripts filter locally as needed.

if [ "$CHECK_MODE" = "all" ]; then
  CHECK_FILES=$(git ls-files)
else
  CHECK_FILES=$(git diff --cached --name-only --diff-filter=ACM)
fi
