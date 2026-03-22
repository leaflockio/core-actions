#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Force-sync pre-main to match main HEAD after a production release.
# No merge commit — pre-main simply points to main's HEAD.
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

# ── Get main HEAD SHA ────────────────────────────────────────────
MAIN_SHA="$(api GET "/git/ref/heads/main" | jq -r '.object.sha')"
[ -n "$MAIN_SHA" ] && [ "$MAIN_SHA" != "null" ] || {
  log_error "Failed to get main HEAD SHA"
  exit 1
}

# ── Get pre-main HEAD SHA ────────────────────────────────────────
PRE_MAIN_SHA="$(api GET "/git/ref/heads/pre-main" | jq -r '.object.sha')"
[ -n "$PRE_MAIN_SHA" ] && [ "$PRE_MAIN_SHA" != "null" ] || {
  log_error "Failed to get pre-main HEAD SHA"
  exit 1
}

# ── Already in sync? ─────────────────────────────────────────────
if [ "$MAIN_SHA" = "$PRE_MAIN_SHA" ]; then
  log_success "pre-main already points to main HEAD — nothing to do"
  exit 0
fi

# ── Force-update pre-main to main HEAD ───────────────────────────
api PATCH "/git/refs/heads/pre-main" "$(jq -cn \
  --arg sha "$MAIN_SHA" \
  '{sha: $sha, force: true}')" >/dev/null

log_success "pre-main force-synced to main HEAD (${MAIN_SHA:0:7})"
