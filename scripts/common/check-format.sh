#!/bin/sh
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Checks formatting of files using prettier.
# Requires: prettier (npm install -g prettier)

. "$(dirname "$0")/config.sh"

if ! command -v prettier >/dev/null 2>&1; then
  log_error "prettier is not installed."
  log_info "Run: npm install -g prettier"
  exit 1
fi

# Filter CHECK_FILES to formattable extensions
FORMAT_FILES=""
for f in $CHECK_FILES; do
  case "$f" in
  *.yml | *.yaml | *.json | *.md | *.js | *.jsx | *.ts | *.tsx | *.css | *.html)
    FORMAT_FILES="$FORMAT_FILES $f"
    ;;
  esac
done

if [ -z "$FORMAT_FILES" ]; then
  log_success "No files to format check."
  exit 0
fi

log_info "Checking formatting..."

FAIL=0

for f in $FORMAT_FILES; do
  [ -f "$f" ] || continue

  if ! prettier --config configs/common/.prettierrc --ignore-path configs/common/.prettierignore --check "$f" >/dev/null 2>&1; then
    log_error "Not formatted: $f"
    FAIL=1
  fi
done

if [ "$FAIL" -ne 0 ]; then
  echo ""
  log_error "Formatting errors detected."
  log_info "Run: prettier --write <file> to fix."
  exit 1
fi

log_success "Formatting check passed."
