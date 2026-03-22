#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Validates branch name follows the naming convention.
# Hook mode:  check-branch-name.sh <prev-head> <new-head> <checkout-type>
#             Runs on post-checkout. Warns only — cannot block branch creation.
# CI mode:    check-branch-name.sh (no args)
#             Fails if branch name is invalid.
#
# Expected format: {type}/{issue-number}-short-description
# Types: feature, fix, chore, docs, refactor, hotfix

. "$(dirname "$0")/config.sh"

# Skip during rebase — detached HEAD is expected
is_rebasing && exit 0

NAMING_PATTERN='^(feature|fix|chore|docs|refactor|hotfix)/[0-9]+-[a-z0-9-]+$'

# Hook mode — warn only
if [ -n "$3" ]; then
  CHECKOUT_TYPE="$3"
  if [ "$CHECKOUT_TYPE" != "1" ]; then
    exit 0
  fi

  BRANCH=$(git rev-parse --abbrev-ref HEAD)
  is_protected_branch "$BRANCH" && exit 0

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
  exit 0
fi

# CI mode — fail on invalid name
BRANCH="${GITHUB_HEAD_REF:-$(git rev-parse --abbrev-ref HEAD)}"
is_protected_branch "$BRANCH" && exit 0

if ! echo "$BRANCH" | grep -qE "$NAMING_PATTERN"; then
  log_error "Branch name does not follow convention: '$BRANCH'"
  echo ""
  echo "  Format:  {type}/{issue-number}-short-description"
  echo "  Types:   feature, fix, chore, docs, refactor, hotfix"
  echo ""
  echo "  Examples:"
  echo "    feature/123-portfolio-header"
  echo "    fix/87-login-redirect"
  echo "    hotfix/201-payment-failure"
  exit 1
fi

log_success "Branch name is valid."
