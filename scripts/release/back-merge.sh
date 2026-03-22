#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Back-merge main → pre-main after a production release (ADR-010).
# Creates a verified merge commit via the GitHub API so the commit
# is signed by GitHub's key rather than an unverified local merge.
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/../common/utils.sh"

OWNER="${GITHUB_REPOSITORY%%/*}"
REPO="${GITHUB_REPOSITORY##*/}"
API="https://api.github.com/repos/${OWNER}/${REPO}"

api() {
  local method="$1" endpoint="$2" data="$3"
  local args=(-s -f -H "Authorization: Bearer ${GITHUB_TOKEN}" -H "Accept: application/vnd.github+json")
  [ -n "$data" ] && args+=(-d "$data")
  curl -X "$method" "${args[@]}" "${API}${endpoint}"
}

# ── Fetch current SHAs ────────────────────────────────────────────
git fetch origin main pre-main

MAIN_SHA="$(git rev-parse origin/main)"
PRE_MAIN_SHA="$(git rev-parse origin/pre-main)"

# ── Already in sync? ─────────────────────────────────────────────
if git merge-base --is-ancestor origin/main origin/pre-main; then
  log_success "pre-main already includes main — nothing to merge"
  exit 0
fi

# ── Check for conflicts locally ──────────────────────────────────
git merge-tree --write-tree origin/pre-main origin/main >/dev/null 2>&1 || {
  log_error "Back-merge conflict detected"
  log_error "Manual resolution required:"
  log_info "  1. git checkout -b chore/back-merge-main origin/pre-main"
  log_info "  2. git merge origin/main"
  log_info "  3. Resolve conflicts, commit, and open a PR to pre-main"
  exit 1
}

# ── Get main's tree SHA via API ──────────────────────────────────
MAIN_TREE_SHA="$(api GET "/git/commits/${MAIN_SHA}" | jq -r '.tree.sha')"
[ -n "$MAIN_TREE_SHA" ] && [ "$MAIN_TREE_SHA" != "null" ] || {
  log_error "Failed to get tree SHA for main"
  exit 1
}

# ── Create verified merge commit via API ─────────────────────────
COMMIT_MSG="chore: back-merge main into pre-main [skip ci]"
COMMIT_BODY="$(jq -cn --arg msg "$COMMIT_MSG" --arg tree "$MAIN_TREE_SHA" --arg p1 "$PRE_MAIN_SHA" --arg p2 "$MAIN_SHA" '{message: $msg, tree: $tree, parents: [$p1, $p2]}')"
NEW_COMMIT_SHA="$(api POST "/git/commits" "$COMMIT_BODY" | jq -r '.sha')"
[ -n "$NEW_COMMIT_SHA" ] && [ "$NEW_COMMIT_SHA" != "null" ] || {
  log_error "Failed to create merge commit"
  exit 1
}

# ── Update pre-main ref ─────────────────────────────────────────
api PATCH "/git/refs/heads/pre-main" "$(jq -cn --arg sha "$NEW_COMMIT_SHA" '{sha: $sha}')" >/dev/null

log_success "Back-merge complete — pre-main is up to date with main (verified commit ${NEW_COMMIT_SHA:0:7})"
