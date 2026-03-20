#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Validates commit messages follow the conventional commits format.
# Hook mode:  validate-commit-msg.sh <commit-msg-file>
# CI mode:    validate-commit-msg.sh (no args — checks all PR commits)

. "$(dirname "$0")/config.sh"

MAX_LENGTH="$MAX_COMMIT_MSG_LENGTH"
PATTERN='^(feat|fix|chore|docs|refactor|test|style|perf|ci|build|revert)(\(.+\))?(!)?: .+'

validate_message() {
  local FIRST_LINE="$1"
  local CONTEXT="$2"

  if ! echo "$FIRST_LINE" | grep -qE "$PATTERN"; then
    log_error "Invalid commit message.${CONTEXT:+ ($CONTEXT)}"
    echo ""
    echo "  Got:      $FIRST_LINE"
    echo ""
    echo "  Format:   type(scope)?: description"
    echo "  Breaking: type(scope)!: description"
    echo ""
    echo "  Types: feat, fix, chore, docs, refactor, test, style, perf, ci, build, revert"
    echo ""
    echo "  Examples:"
    echo "    feat(auth): add Google login"
    echo "    fix: correct null pointer on startup"
    echo "    feat!: remove deprecated v1 endpoints"
    return 1
  fi

  LENGTH=$(echo "$FIRST_LINE" | wc -c | tr -d ' ')
  LENGTH=$((LENGTH - 1))
  if [ "$LENGTH" -gt "$MAX_LENGTH" ]; then
    log_error "Commit message first line is $LENGTH characters (max $MAX_LENGTH).${CONTEXT:+ ($CONTEXT)}"
    echo ""
    echo "  Got: $FIRST_LINE"
    return 1
  fi

  if echo "$FIRST_LINE" | grep -qE '^[^:]+: [A-Z]'; then
    log_error "Commit message description must be lowercase.${CONTEXT:+ ($CONTEXT)}"
    echo ""
    echo "  Got:      $FIRST_LINE"
    echo "  Expected: description should start with a lowercase letter"
    return 1
  fi

  return 0
}

if [ -n "$1" ]; then
  MSG=$(cat "$1")
  FIRST_LINE=$(echo "$MSG" | head -n 1)
  validate_message "$FIRST_LINE" "" || exit 1
  log_success "Commit message format is valid."
  exit 0
fi

REMOTE=$(get_remote_branch)
if [ -z "$REMOTE" ]; then
  log_error "No remote branch found to compare against."
  exit 1
fi

COMMITS=$(git rev-list "$REMOTE"..HEAD 2>/dev/null)
if [ -z "$COMMITS" ]; then
  log_success "No new commits to validate."
  exit 0
fi

FAIL=0
for COMMIT in $COMMITS; do
  FIRST_LINE=$(git log --format=%s -1 "$COMMIT")
  SHORT=$(git rev-parse --short "$COMMIT")
  validate_message "$FIRST_LINE" "$SHORT" || FAIL=1
done

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi

log_success "All commit messages are valid."
