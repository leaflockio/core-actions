#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Enforces Node.js / React specific file and folder naming conventions.
#
# Folder rules (Node-specific exceptions):
#   - PascalCase component folders (e.g. components/MyComponent/)
#   - Next.js dynamic route folders ([slug]/, [...slug]/, [[...slug]]/)
#
# File rules:
#   - PascalCase for React components (.jsx, .tsx)
#   - useCamelCase for React hooks
#   - Next.js dynamic routes: [slug].tsx, [...slug].tsx, [[...slug]].tsx
#   - Next.js special files: _app.tsx, _document.tsx, _error.tsx
#   - Config/test/spec files: *.config.*, *.test.*, *.spec.*
#   - camelCase utilities: setupTests.ts, reportWebVitals.ts

. "$(dirname "$0")/../common/utils.sh"

STAGED=$(git diff --cached --name-only --diff-filter=ACMR | grep -E '\.(js|jsx|ts|tsx|cjs|mjs)$' | grep -v '^\.github/')

if [ -z "$STAGED" ]; then
  log_info "No JS/TS files staged for naming check."
  exit 0
fi

FAIL=0
CHECKED_DIRS=""

while IFS= read -r FILE; do

  # --- Folder checks ---
  DIR=$(dirname "$FILE")
  if [ "$DIR" != "." ]; then
    IFS='/' read -ra SEGMENTS <<<"$DIR"
    for SEG in "${SEGMENTS[@]}"; do
      echo "$CHECKED_DIRS" | grep -qF "|$SEG|" && continue
      CHECKED_DIRS="$CHECKED_DIRS|$SEG|"

      # Skip hidden folders, double-underscore dirs, node_modules
      case "$SEG" in .*) continue ;; esac
      case "$SEG" in __*__) continue ;; esac
      case "$SEG" in node_modules) continue ;; esac

      # Already kebab-case — fine
      echo "$SEG" | grep -qE '^[a-z0-9][a-z0-9_-]*$' && continue

      # Allow PascalCase component folders
      echo "$SEG" | grep -qE '^[A-Z][a-zA-Z0-9]*$' && continue

      # Allow Next.js dynamic route folders
      echo "$SEG" | grep -qE '^\[{1,2}(\.\.\.)?[a-z][a-zA-Z0-9]*\]{1,2}$' && continue

      log_error "Invalid JS/TS folder name: $SEG (in $FILE)"
      log_info "Use kebab-case (my-folder) or PascalCase for component folders (MyComponent)"
      FAIL=1
    done
  fi

  # --- File checks ---
  BASE=$(basename "$FILE")

  # Skip dotfiles
  case "$BASE" in .*) continue ;; esac

  # Already valid kebab-case — handled by common, skip here
  echo "$BASE" | grep -qE '^[a-z0-9][a-z0-9._-]*$' && continue

  # Allow PascalCase React components (.jsx, .tsx)
  echo "$BASE" | grep -qE '^[A-Z][a-zA-Z0-9]*\.(jsx?|tsx?)$' && continue

  # Allow useCamelCase React hooks
  echo "$BASE" | grep -qE '^use[A-Z][a-zA-Z0-9]*\.(js|ts)$' && continue

  # Allow camelCase utilities (setupTests.ts, reportWebVitals.ts)
  echo "$BASE" | grep -qE '^[a-z][a-zA-Z0-9]*\.(js|ts|jsx|tsx)$' && continue

  # Allow config/test/spec files (jest.config.ts, app.spec.tsx)
  echo "$BASE" | grep -qE '\.(config|test|spec)\.(js|ts|jsx|tsx|cjs|mjs)$' && continue

  # Allow Next.js dynamic routes ([slug].tsx, [...slug].tsx, [[...slug]].tsx)
  echo "$BASE" | grep -qE '^\[{1,2}(\.\.\.)?[a-z][a-zA-Z0-9]*\]{1,2}\.(js|ts|jsx|tsx)$' && continue

  # Allow Next.js special files (_app.tsx, _document.tsx, _error.tsx)
  echo "$BASE" | grep -qE '^_[a-z][a-zA-Z0-9]*\.(js|ts|jsx|tsx)$' && continue

  log_error "Invalid JS/TS filename: $FILE"
  log_info "Use kebab-case (my-utils.ts), PascalCase for components (MyComponent.tsx), or useCamelCase for hooks (useTheme.ts)"
  FAIL=1
done <<<"$STAGED"

[ "$FAIL" -eq 0 ] && log_success "Node naming check passed." || exit 1
