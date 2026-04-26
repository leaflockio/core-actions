#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Checks spelling in files using cspell.
# Requires: cspell (npm ci)

. "$(dirname "$0")/config.sh"

require_command "npx" "install Node.js"

if [ -z "$CHECK_FILES" ]; then
  log_success "No files to spell check."
  exit 0
fi

log_info "Checking spelling..."

if ! echo "$CHECK_FILES" | xargs npx cspell --no-progress --no-summary --no-must-find-files 2>&1; then
  echo ""
  log_error "Spelling errors detected."
  log_info "Fix the words above or add them to .cspell.json 'words' list."
  exit 1
fi

log_success "Spelling check passed."
