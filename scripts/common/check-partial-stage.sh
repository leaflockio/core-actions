#!/bin/sh
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Detects files that are both staged and have unstaged changes (partial stages).
#
# Problem:
#   When a file is edited after staging, the staged version (not the working
#   directory version) is what gets committed. This is a common source of
#   bugs — the developer thinks they committed their latest changes but
#   the commit actually contains an older version of the file.
#
# How it works:
#   Lefthook temporarily stashes unstaged changes into a patch file before
#   running pre-commit hooks. This means the unstaged changes are removed
#   from the working directory during hook execution — if you check the
#   file at that point, it will look like it has no modifications.
#
#   This script reads the patch file that lefthook created to find which
#   files had unstaged changes, then cross-references them with currently
#   staged files. Any file appearing in both lists is a partial stage.
#
# Behavior is controlled via .hooks-config at repo root:
#   PARTIAL_STAGE=fail    (default) block the commit
#   PARTIAL_STAGE=prompt  ask for confirmation before proceeding
#
# Important:
#   Do not terminate hook execution mid-way (e.g. Ctrl+C). Lefthook
#   restores the stashed changes only after all hooks complete. If
#   interrupted, changes can be recovered from the patch file at
#   .git/info/lefthook-unstaged.patch using:
#     git apply .git/info/lefthook-unstaged.patch

. "$(dirname "$0")/config.sh"

PATCH_FILE="$(git rev-parse --git-dir)/info/lefthook-unstaged.patch"

# Wait briefly for lefthook to create the patch file
WAIT=0
while [ ! -f "$PATCH_FILE" ] && [ "$WAIT" -lt 10 ]; do
  sleep 0.1
  WAIT=$((WAIT + 1))
done

# No patch file means no unstaged changes were stashed — nothing to check
if [ ! -f "$PATCH_FILE" ] || [ ! -s "$PATCH_FILE" ]; then
  exit 0
fi

# Read the patch to find which files lefthook stashed (had unstaged changes)
STASHED_FILES=$(grep '^diff --git' "$PATCH_FILE" | sed 's|diff --git a/\(.*\) b/.*|\1|')

if [ -z "$STASHED_FILES" ]; then
  exit 0
fi

# Get currently staged files
STAGED=$(git diff --cached --name-only --diff-filter=ACM)

if [ -z "$STAGED" ]; then
  exit 0
fi

# Find files that are both staged and had unstaged changes (stashed by lefthook)
PARTIAL=""
COUNT=0
for f in $STASHED_FILES; do
  if echo "$STAGED" | grep -qx "$f"; then
    PARTIAL="${PARTIAL}  - ${f}
"
    COUNT=$((COUNT + 1))
  fi
done

if [ "$COUNT" -eq 0 ]; then
  exit 0
fi

log_error "$COUNT file(s) have been modified after staging."
echo ""
log_warn "These files are staged but also have unstaged changes:"
printf "%s" "$PARTIAL"
echo ""
log_warn "The commit will capture the staged version, NOT your latest edits."
log_warn "Lefthook has temporarily stashed the unstaged changes — you will"
log_warn "not see them in the working directory until hooks finish running."
log_warn "They will be restored automatically after all hooks complete."
echo ""
log_info "To include latest changes:  git add <file>"
log_info "To discard unstaged edits:  git checkout -- <file>"
log_info "If changes are missing after hooks, recover from:"
log_info "  git apply .git/info/lefthook-unstaged.patch"
echo ""

if [ "$PARTIAL_STAGE" = "prompt" ]; then
  printf "Proceed with staged version? [y/N] "
  read -r REPLY
  case "$REPLY" in
  y | Y) exit 0 ;;
  *)
    log_error "Commit aborted."
    exit 1
    ;;
  esac
else
  log_error "Commit blocked. Stage or discard unstaged changes before committing."
  exit 1
fi
