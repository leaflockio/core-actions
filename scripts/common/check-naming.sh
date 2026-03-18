#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Enforces general file and folder naming conventions across all repos.
#
# Folder rules:
#   - No spaces in folder names
#   - Naming convention enforcement is left to language-specific scripts
#
# File rules:
#   - No spaces in filenames
#   - kebab-case for general files
#   - UPPER_SNAKE_CASE allowed for docs (README.md, CHANGELOG.md, etc.)
#   - No-extension uppercase files allowed (LICENSE, CODEOWNERS)
#   - Exceptions: Dockerfile, Makefile, Procfile, dotfiles

. "$(dirname "$0")/utils.sh"

STAGED=$(git diff --cached --name-only --diff-filter=ACMR | grep -v '^\.github/')

if [ -z "$STAGED" ]; then
  log_success "No files staged for naming check."
  exit 0
fi

FAIL=0
CHECKED_DIRS=""

while IFS= read -r FILE; do

  # --- Folder checks (universal: no spaces) ---
  DIR=$(dirname "$FILE")
  if [ "$DIR" != "." ]; then
    IFS='/' read -ra SEGMENTS <<<"$DIR"
    for SEG in "${SEGMENTS[@]}"; do
      echo "$CHECKED_DIRS" | grep -qF "|$SEG|" && continue
      CHECKED_DIRS="$CHECKED_DIRS|$SEG|"

      if echo "$SEG" | grep -q ' '; then
        log_error "Folder name contains spaces: $SEG (in $FILE)"
        log_info "Replace spaces with hyphens (e.g. my-folder)"
        FAIL=1
      fi
    done
  fi

  # --- File checks ---
  BASE=$(basename "$FILE")

  # No spaces in filenames
  if echo "$BASE" | grep -q ' '; then
    log_error "Filename contains spaces: $FILE"
    log_info "Replace spaces with hyphens (e.g. my-file.md)"
    FAIL=1
    continue
  fi

  # Skip dotfiles
  case "$BASE" in .*) continue ;; esac

  # Skip known exceptions
  case "$BASE" in
  Dockerfile | Makefile | Procfile) continue ;;
  esac

  # Skip language-specific files
  case "$BASE" in
  *.js | *.jsx | *.ts | *.tsx | *.cjs | *.mjs) continue ;;
  *.go) continue ;;
  *.py) continue ;;
  *.sh) continue ;;
  esac

  # Allow no-extension uppercase files (LICENSE, CODEOWNERS)
  echo "$BASE" | grep -qE '^[A-Z][A-Z0-9_]*$' && continue

  # Allow UPPER_SNAKE_CASE docs (.md, .txt)
  echo "$BASE" | grep -qE '^[A-Z0-9_]+\.(md|txt)$' && continue

  # Default: must be kebab-case (lowercase, digits, dots, hyphens)
  if ! echo "$BASE" | grep -qE '^[a-z0-9][a-z0-9._-]*$'; then
    log_error "Invalid filename: $FILE"
    log_info "Use kebab-case (e.g. my-file.yml, setup-config.json)"
    FAIL=1
  fi
done <<<"$STAGED"

[ "$FAIL" -eq 0 ] && log_success "Naming check passed." || exit 1
