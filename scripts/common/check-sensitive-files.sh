#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Blocks staging of sensitive files (secrets, keys, credentials).
# Files with .example, .sample, or .template as a dot-separated
# segment are allowed — these are intentional placeholder files.

. "$(dirname "$0")/config.sh"

if [ -z "$CHECK_FILES" ]; then
  log_success "Sensitive file check passed."
  exit 0
fi

BLOCKED_PATTERN='\.env$|\.env\.local$|\.env\.development$|\.env\.production$|\.env\.staging$|\.pem$|\.key$|\.p12$|\.pfx$|\.jks$|\.keystore$|credentials\.json$|service-account\.json$|\.secret$|id_rsa$|id_ed25519$|\.npmrc$|\.pypirc$'
SAFE_SEGMENTS='\.example\.|\.sample\.|\.template\.'

FAIL=0

for f in $CHECK_FILES; do
  BASENAME=$(basename "$f")

  if echo "$BASENAME" | grep -qE "$SAFE_SEGMENTS"; then
    continue
  fi

  if echo "$BASENAME" | grep -qE "$BLOCKED_PATTERN"; then
    log_error "Sensitive file staged: $f"
    FAIL=1
  fi
done

if [ "$FAIL" -ne 0 ]; then
  echo ""
  log_info "If this is a placeholder file, rename it with a .example, .sample, or .template segment."
  log_info "Example: .env.example, cert.example.pem"
  exit 1
fi

log_success "Sensitive file check passed."
