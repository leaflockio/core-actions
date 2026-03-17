#!/bin/sh
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Back-merge main → pre-main after a production release (ADR-010).
# Expects GITHUB_TOKEN to be set for push authentication.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/../common/utils.sh"

REMOTE_URL="https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"

git remote set-url origin "${REMOTE_URL}"
git fetch origin main pre-main

git checkout pre-main
git reset --hard origin/pre-main

if git merge origin/main --no-ff -m "chore: back-merge main into pre-main [skip ci]"; then
  git push origin pre-main
  log_success "Back-merge complete — pre-main is up to date with main"
else
  log_error "Back-merge conflict detected"
  log_error "Manual resolution required:"
  log_info "  1. git checkout -b chore/back-merge-main origin/pre-main"
  log_info "  2. git merge origin/main"
  log_info "  3. Resolve conflicts, commit, and open a PR to pre-main"
  exit 1
fi
