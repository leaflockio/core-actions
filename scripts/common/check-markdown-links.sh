#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Validates links in markdown files.
# Internal links (relative paths): error if target does not exist.
# External links (http/https): warn if unreachable, do not block.

. "$(dirname "$0")/config.sh"

# Filter CHECK_FILES to markdown only
MD_FILES=""
for f in $CHECK_FILES; do
  case "$f" in
  *.md) MD_FILES="$MD_FILES $f" ;;
  esac
done

if [ -z "$MD_FILES" ]; then
  log_success "No markdown files to check."
  exit 0
fi

FAIL=0

for file in $MD_FILES; do
  [ -f "$file" ] || continue

  FILE_DIR=$(dirname "$file")

  # Strip fenced code blocks before extracting links.
  # Handles both ``` and ```` (or more) fence markers.
  STRIPPED_FILE=$(mktemp)
  sed "/^[[:space:]]*\`\{3,\}/,/^[[:space:]]*\`\{3,\}/d" "$file" >"$STRIPPED_FILE"

  # Extract markdown links: [text](url-or-path)
  MATCHES_FILE=$(mktemp)
  grep -noE '\[([^]]*)\]\(([^)]+)\)' "$STRIPPED_FILE" 2>/dev/null >"$MATCHES_FILE" || true

  while IFS= read -r match; do
    LINE_NUM=$(echo "$match" | cut -d: -f1)
    TARGET=$(echo "$match" | sed 's/.*](\([^)]*\))/\1/' | sed 's/#.*//' | sed 's/?.*//')

    # Skip pure anchors (#section) which resolve to empty after stripping
    [ -z "$TARGET" ] && continue

    # External links: warn if unreachable
    case "$TARGET" in
    http://* | https://*)
      STATUS=$(curl -sL -o /dev/null -w '%{http_code}' --max-time "$LINK_CHECK_TIMEOUT" "$TARGET" 2>/dev/null || echo "000")
      if [ "$STATUS" -ge 400 ] || [ "$STATUS" = "000" ]; then
        log_warn "External link may be broken in $file:$LINE_NUM → $TARGET (HTTP $STATUS)"
      fi
      continue
      ;;
    esac

    # Internal links: check if target exists
    RESOLVED="$FILE_DIR/$TARGET"

    if [ ! -e "$RESOLVED" ] && [ ! -e "$TARGET" ]; then
      log_error "Broken link in $file:$LINE_NUM → $TARGET"
      FAIL=1
    fi
  done <<<"$(cat "$MATCHES_FILE")"
  rm -f "$MATCHES_FILE" "$STRIPPED_FILE"
done

if [ "$FAIL" -ne 0 ]; then
  echo ""
  log_error "Broken internal links in markdown files."
  log_info "Fix the paths above or remove the broken links."
  exit 1
fi

log_success "Markdown link check passed."
