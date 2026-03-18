#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Detects files being pushed that also have uncommitted local changes.
#
# Problem:
#   When a developer fixes a lint error or test failure locally but forgets
#   to commit the fix, the push contains the old (broken) code. CI then
#   fails even though the working tree looks correct locally.
#
# How it works:
#   Compares the list of files in commits being pushed against files with
#   uncommitted changes (both staged and unstaged). Any overlap means the
#   pushed code does not match the local working tree.

. "$(dirname "$0")/config.sh"

# Files with uncommitted changes (staged or unstaged)
DIRTY=$(git diff --name-only HEAD 2>/dev/null)

if [ -z "$DIRTY" ]; then
  exit 0
fi

# Files included in commits being pushed
# Compare local HEAD against the remote tracking branch
REMOTE=$(get_remote_branch) || exit 0

PUSH_FILES=$(git diff --name-only "$REMOTE"..HEAD 2>/dev/null)

if [ -z "$PUSH_FILES" ]; then
  exit 0
fi

# Find overlap: files being pushed that also have uncommitted changes
OVERLAP=""
COUNT=0
for f in $DIRTY; do
  if echo "$PUSH_FILES" | grep -qx "$f"; then
    OVERLAP="${OVERLAP}  - ${f}
"
    COUNT=$((COUNT + 1))
  fi
done

if [ "$COUNT" -eq 0 ]; then
  exit 0
fi

log_error "$COUNT file(s) being pushed have uncommitted local changes."
echo ""
log_warn "These files were modified locally but the changes are not committed:"
printf "%s" "$OVERLAP"
echo ""
log_warn "The pushed code does not match your working tree."
log_warn "CI will run the committed version, not your local edits."
echo ""
log_info "To include changes:  git add <file> && git commit"
log_info "To discard changes:  git checkout -- <file>"
echo ""

if [ "$UNCOMMITTED_PUSH" = "prompt" ]; then
  prompt_yn "Push anyway?" "Push aborted." || exit 1
  exit 0
fi

log_error "Push blocked. Commit or discard uncommitted changes before pushing."
exit 1
