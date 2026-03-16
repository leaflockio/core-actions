#!/bin/sh
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Blocks rebasing of protected and shared branches.
# Allows rebasing only on solo working branches.
#
# Rules (per ADR-003 and branching standards):
#   - Never rebase main, master, or pre-main
#   - Never rebase shared parent branches
#   - Solo branches may rebase onto pre-main to stay up to date
#   - Always use --force-with-lease when pushing (never --force)
#
# Git passes two arguments to pre-rebase:
#   $1 = upstream branch being rebased onto
#   $2 = branch being rebased (empty if current branch)

. "$(dirname "$0")/config.sh"

UPSTREAM="$1"
BRANCH="${2:-$(git rev-parse --abbrev-ref HEAD)}"

# Block rebasing protected branches
for _pb in $PROTECTED_BRANCHES; do
  if [ "$BRANCH" = "$_pb" ]; then
    log_error "Rebasing '$BRANCH' is not allowed."
    log_info "Protected branches must never be rebased."
    exit 1
  fi
done

# Warn about force push safety
log_warn "After rebasing, push with --force-with-lease (never --force)."
echo ""
echo "  git push --force-with-lease"
echo ""
log_info "If this is a shared branch, use merge instead:"
echo ""
echo "  git merge $UPSTREAM"
echo ""
