#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Validates PR title follows the conventional commits format.
# The title becomes the squash merge commit message, so it must
# be a valid conventional commit.
#
# Required env: PR_TITLE

. "$(dirname "$0")/config.sh"

if [ -z "${PR_TITLE:-}" ]; then
  log_error "PR_TITLE is not set."
  exit 1
fi

MAX_LENGTH="$MAX_COMMIT_MSG_LENGTH"
PATTERN='^(feat|fix|chore|docs|refactor|test|style|perf|ci|build|revert)(\(.+\))?(!)?: .+'

if ! echo "$PR_TITLE" | grep -qE "$PATTERN"; then
  log_error "Invalid PR title."
  echo ""
  echo "  Got:      $PR_TITLE"
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

NORMALIZED=$(strip_pr_suffix "$PR_TITLE")
LENGTH=$(echo "$NORMALIZED" | wc -c | tr -d ' ')
LENGTH=$((LENGTH - 1))
if [ "$LENGTH" -gt "$MAX_LENGTH" ]; then
  log_error "PR title is $LENGTH characters (max $MAX_LENGTH)."
  echo ""
  echo "  Got: $PR_TITLE"
  exit 1
fi

if echo "$PR_TITLE" | grep -qE '^[^:]+: [A-Z]'; then
  log_error "PR title description must be lowercase."
  echo ""
  echo "  Got:      $PR_TITLE"
  echo "  Expected: description should start with a lowercase letter"
  exit 1
fi

log_success "PR title is valid."
