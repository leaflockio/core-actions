#!/bin/sh
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Scans for leaked secrets using gitleaks.
# Requires: gitleaks binary (installed by: leaf setup)

. "$(dirname "$0")/config.sh"

if ! command -v gitleaks >/dev/null 2>&1; then
  log_error "gitleaks is not installed."
  log_info "Run: leaf setup"
  exit 1
fi

log_info "Scanning for secrets..."

if [ "$CHECK_MODE" = "all" ]; then
  if ! gitleaks detect --redact --verbose; then
    log_error "Secrets detected. Remove and rotate immediately."
    exit 1
  fi
else
  if ! gitleaks protect --staged --redact --verbose; then
    log_error "Secrets detected in staged changes. Commit blocked."
    log_info "Remove the secret and rotate it immediately if it was ever pushed."
    exit 1
  fi
fi

log_success "No secrets found."
