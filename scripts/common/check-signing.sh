#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Verifies commits are signed with GPG or Gitsign.
# On post-commit: checks the latest commit.
# On pre-push: checks all new commits not yet on the remote.

. "$(dirname "$0")/config.sh"

check_commit() {
  COMMIT="$1"
  SIG=$(git log --show-signature -1 "$COMMIT" 2>/dev/null)

  if echo "$SIG" | grep -qE "Good signature|gitsign: Good signature"; then
    log_success "Commit $COMMIT is signed."
    return 0
  elif echo "$SIG" | grep -q "gpg: Signature made"; then
    log_warn "Commit $COMMIT is signed (key not in local keyring)."
    return 0
  else
    log_error "Commit $COMMIT is not signed."
    return 1
  fi
}

if [ -n "${PR_BASE_SHA:-}" ]; then
  COMMITS=$(git rev-list "$PR_BASE_SHA"..HEAD --no-merges 2>/dev/null)
else
  REMOTE=$(get_remote_branch)
  if [ -n "$REMOTE" ]; then
    COMMITS=$(git rev-list "$REMOTE"..HEAD 2>/dev/null)
  else
    COMMITS=$(git rev-list HEAD 2>/dev/null)
  fi
fi

# If called from post-commit with no upstream yet, just check HEAD
if [ -z "$COMMITS" ]; then
  COMMITS=$(git rev-parse HEAD)
fi

FAIL=0
for COMMIT in $COMMITS; do
  check_commit "$COMMIT" || FAIL=1
done

if [ "$FAIL" -ne 0 ]; then
  log_info "Set up commit signing: https://github.com/leaflockio/core-docs/blob/main/standards/git/commit-signing.md"
  exit 1
fi
