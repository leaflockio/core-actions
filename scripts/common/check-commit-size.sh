#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Warns when total lines changed in a commit exceeds MAX_COMMIT_LINES.
# Aligns with ADR-009 (PR size limit of 400 lines of production code).
# This is a warning only — it does not block the commit.
#
# Excludes from the count:
#   - Test files (*.test.*, *.spec.*)
#   - Generated files (lock files, CHANGELOG, LICENSE)
#
# Configurable via .hooks-config at repo root:
#   MAX_COMMIT_LINES=400  (default 400 lines changed)

. "$(dirname "$0")/config.sh"

# In all mode, this check is not applicable (no diff to measure)
if [ "$CHECK_MODE" = "all" ]; then
  exit 0
fi

# Count insertions and deletions from staged changes, excluding test/generated files
TOTAL_CHANGED=$(git diff --cached --numstat 2>/dev/null || true)
TOTAL_CHANGED=$(echo "$TOTAL_CHANGED" | grep -vE '\.(test|spec)\.(ts|tsx|js|jsx|py|go)' || true)
TOTAL_CHANGED=$(echo "$TOTAL_CHANGED" | grep -vE '(\.lock|CHANGELOG|LICENSE)' || true)
TOTAL_CHANGED=$(echo "$TOTAL_CHANGED" | awk '{ added += $1; deleted += $2 } END { print added + deleted }')

TOTAL_CHANGED="${TOTAL_CHANGED:-0}"

if [ "$TOTAL_CHANGED" -gt "$MAX_COMMIT_LINES" ]; then
  log_warn "Commit changes $TOTAL_CHANGED lines (recommended max $MAX_COMMIT_LINES)."
  log_info "Consider splitting into smaller, focused commits."
fi
