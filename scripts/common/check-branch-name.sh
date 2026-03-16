#!/bin/sh
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Warns when a new branch name does not follow the naming convention.
# Runs on post-checkout (git checkout -b, git switch -c).
#
# Expected format: {type}/{issue-number}-short-description
# Types: feature, fix, chore, docs, refactor, hotfix
#
# This is a warning only — post-checkout cannot block branch creation.

. "$(dirname "$0")/config.sh"

# $3 = 1 for branch checkout, 0 for file checkout
CHECKOUT_TYPE="${3:-0}"

if [ "$CHECKOUT_TYPE" != "1" ]; then
  exit 0
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Skip protected branches — they have their own naming
for _pb in $PROTECTED_BRANCHES; do
  [ "$BRANCH" = "$_pb" ] && exit 0
done

NAMING_PATTERN='^(feature|fix|chore|docs|refactor|hotfix)/[0-9]+-[a-z0-9-]+$'

if ! echo "$BRANCH" | grep -qE "$NAMING_PATTERN"; then
  log_warn "Branch name does not follow convention: '$BRANCH'"
  echo ""
  echo "  Format:  {type}/{issue-number}-short-description"
  echo "  Types:   feature, fix, chore, docs, refactor, hotfix"
  echo ""
  echo "  Examples:"
  echo "    feature/123-portfolio-header"
  echo "    fix/87-login-redirect"
  echo "    hotfix/201-payment-failure"
  echo ""
  log_info "Rename with: git branch -m {correct-name}"
fi
