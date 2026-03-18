#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Validates commit message follows the conventional commits format.
# Usage: validate-commit-msg.sh <commit-msg-file>

. "$(dirname "$0")/config.sh"

MAX_LENGTH="$MAX_COMMIT_MSG_LENGTH"
MSG=$(cat "$1")
FIRST_LINE=$(echo "$MSG" | head -n 1)
PATTERN='^(feat|fix|chore|docs|refactor|test|style|perf|ci|build|revert)(\(.+\))?(!)?: .+'

if ! echo "$FIRST_LINE" | grep -qE "$PATTERN"; then
  log_error "Invalid commit message."
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
  exit 1
fi

LENGTH=$(echo "$FIRST_LINE" | wc -c | tr -d ' ')
LENGTH=$((LENGTH - 1))
if [ "$LENGTH" -gt "$MAX_LENGTH" ]; then
  log_error "Commit message first line is $LENGTH characters (max $MAX_LENGTH)."
  echo ""
  echo "  Got: $FIRST_LINE"
  exit 1
fi

if echo "$FIRST_LINE" | grep -qE '^[^:]+: [A-Z]'; then
  log_error "Commit message description must be lowercase."
  echo ""
  echo "  Got:      $FIRST_LINE"
  echo "  Expected: description should start with a lowercase letter"
  exit 1
fi

log_success "Commit message format is valid."
