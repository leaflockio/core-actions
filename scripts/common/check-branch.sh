#!/bin/sh
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Prevents commits directly to protected branches.
# Validates branch naming convention: {type}/{issue-number}-short-description

. "$(dirname "$0")/config.sh"

BRANCH=$(git rev-parse --abbrev-ref HEAD)

if is_protected_branch "$BRANCH"; then
  log_error "Direct commits to '$BRANCH' are not allowed."
  log_info "Create a feature branch and open a PR."
  exit 1
fi

NAMING_PATTERN='^(feature|fix|chore|docs|refactor|hotfix)/[0-9]+-[a-z0-9-]+$'

if ! echo "$BRANCH" | grep -qE "$NAMING_PATTERN"; then
  log_error "Invalid branch name: '$BRANCH'"
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

log_success "Branch check passed: $BRANCH"
