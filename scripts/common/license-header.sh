#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# License header management for source files.
#
# Usage:
#   license-header.sh get                    # Print the header for this repo
#   license-header.sh check <file|--staged>  # Validate header exists and matches repo type
#   license-header.sh add <file|--all>       # Insert correct header at top of file(s)
#   license-header.sh update <file|--all>    # Update year in existing header(s)
#   license-header.sh migrate <open-source|private>  # Convert all files and LICENSE file
#
# Configuration:
#   .license-config at repo root with ORG_NAME=YourOrg
#   Year is always auto-detected from system clock.
#   License type is auto-detected from LICENSE file presence.

. "$(dirname "$0")/config.sh"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIGS_DIR="${SCRIPT_DIR}/../../configs/common"
CURRENT_YEAR=$(date +%Y)

# Read org name from .license-config at repo root
if [ ! -f ".license-config" ]; then
  log_error "Missing .license-config at repo root."
  log_info "Create one with: ORG_NAME=YourOrg"
  exit 1
fi

ORG_NAME=$(grep '^ORG_NAME=' .license-config | cut -d= -f2)

if [ -z "$ORG_NAME" ]; then
  log_error "ORG_NAME not set in .license-config."
  log_info "Add: ORG_NAME=YourOrg"
  exit 1
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

detect_license_type() {
  if [ -f "LICENSE" ]; then
    if grep -qiE 'Apache|MIT|BSD|ISC|MPL|LGPL|GPL' LICENSE 2>/dev/null; then
      echo "open-source"
    else
      echo "private"
    fi
  else
    echo "private"
  fi
}

get_comment_style() {
  case "$1" in
  *.sh | *.py) echo "hash" ;;
  *.js | *.jsx | *.ts | *.tsx | *.go | *.css | *.scss) echo "slash" ;;
  *.html) echo "html" ;;
  *) echo "" ;;
  esac
}

should_skip_file() {
  case "$1" in
  *.json | *.yaml | *.yml | *.lock | *.toml | *.ini | *.cfg) return 0 ;;
  *.md | *.txt) return 0 ;;
  *.png | *.jpg | *.jpeg | *.gif | *.ico | *.svg) return 0 ;;
  *.woff | *.woff2 | *.ttf | *.eot | *.map) return 0 ;;
  *.min.js | *.min.css) return 0 ;;
  LICENSE* | CHANGELOG*) return 0 ;;
  .gitignore | .prettierignore | .env* | .license-config) return 0 ;;
  node_modules/* | dist/* | build/* | coverage/* | .git/*) return 0 ;;
  esac
  return 1
}

resolve_header_text() {
  TYPE=$(detect_license_type)

  if [ "$TYPE" = "open-source" ]; then
    TEMPLATE_FILE="${CONFIGS_DIR}/license-header-open-source.txt"
  else
    TEMPLATE_FILE="${CONFIGS_DIR}/license-header-proprietary.txt"
  fi

  if [ ! -f "$TEMPLATE_FILE" ]; then
    log_error "License header template not found: $TEMPLATE_FILE"
    log_info "Ensure configs/common/ contains the license header templates."
    exit 1
  fi

  sed "s/{YEAR}/$CURRENT_YEAR/g; s/{ORG}/$ORG_NAME/g" "$TEMPLATE_FILE" | sed '/^$/d'
}

wrap_header() {
  STYLE="$1"
  case "$STYLE" in
  hash)
    while IFS= read -r line; do
      if [ -z "$line" ]; then
        echo "#"
      else
        echo "# $line"
      fi
    done
    ;;
  slash)
    while IFS= read -r line; do
      if [ -z "$line" ]; then
        echo "//"
      else
        echo "// $line"
      fi
    done
    ;;
  html)
    echo "<!--"
    cat
    echo "-->"
    ;;
  esac
}

file_has_header() {
  head -n 10 "$1" | grep -q "Copyright [0-9]\{4\}"
}

# Validates year, org, and license type match current values.
# Returns 0 if valid, 1 if not. Sets HEADER_ISSUE with the reason.
validate_header() {
  HEAD_LINES=$(head -n 10 "$1")
  HEADER_ISSUE=""

  # Check year
  if ! echo "$HEAD_LINES" | grep -q "Copyright $CURRENT_YEAR"; then
    HEADER_ISSUE="outdated year"
    return 1
  fi

  # Check org
  if ! echo "$HEAD_LINES" | grep -q "Copyright $CURRENT_YEAR $ORG_NAME"; then
    HEADER_ISSUE="wrong org (expected $ORG_NAME)"
    return 1
  fi

  # Check license type matches expected template
  EXPECTED_TYPE=$(detect_license_type)
  if [ "$EXPECTED_TYPE" = "private" ]; then
    if ! echo "$HEAD_LINES" | grep -q "proprietary and confidential"; then
      HEADER_ISSUE="wrong license type (expected proprietary)"
      return 1
    fi
  else
    if ! echo "$HEAD_LINES" | grep -q "open source"; then
      HEADER_ISSUE="wrong license type (expected open-source)"
      return 1
    fi
  fi

  return 0
}

get_all_source_files() {
  git ls-files | while IFS= read -r f; do
    should_skip_file "$f" && continue
    STYLE=$(get_comment_style "$f")
    [ -z "$STYLE" ] && continue
    echo "$f"
  done
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

cmd_get() {
  TYPE=$(detect_license_type)
  echo "License type: $TYPE"
  echo "Org: $ORG_NAME"
  echo "Year: $CURRENT_YEAR"
  echo ""
  resolve_header_text
  echo ""
}

resolve_files() {
  _cmd="$1"
  shift
  if [ "$1" = "--staged" ] || [ "$1" = "--all" ]; then
    echo "$CHECK_FILES"
  elif [ -z "$1" ]; then
    log_error "Usage: license-header.sh $_cmd <file(s)|--staged|--all>"
    exit 1
  else
    echo "$*"
  fi
}

cmd_check() {
  FAIL=0
  FILES=$(resolve_files "check" "$@")

  for f in $FILES; do
    [ -f "$f" ] || continue
    should_skip_file "$f" && continue
    STYLE=$(get_comment_style "$f")
    [ -z "$STYLE" ] && continue

    if ! file_has_header "$f"; then
      log_error "Missing license header: $f"
      FAIL=1
    elif ! validate_header "$f"; then
      log_error "$f — $HEADER_ISSUE"
      FAIL=1
    fi
  done

  if [ "$FAIL" -ne 0 ]; then
    echo ""
    log_error "License header issues detected."
    log_info "Run: license-header.sh update --all   (fix year)"
    log_info "Run: license-header.sh add --all      (add missing headers)"
    log_info "Run: license-header.sh migrate <type> (change license type)"
    exit 1
  fi

  log_success "License header check passed."
}

cmd_add() {
  COUNT=0
  FILES=$(resolve_files "add" "$@")

  for f in $FILES; do
    [ -f "$f" ] || continue
    should_skip_file "$f" && continue
    STYLE=$(get_comment_style "$f")
    [ -z "$STYLE" ] && continue

    if file_has_header "$f"; then
      continue
    fi

    HEADER=$(resolve_header_text | wrap_header "$STYLE")
    TMPFILE=$(mktemp)

    # Preserve shebang if present
    FIRST_LINE=$(head -n 1 "$f")
    case "$FIRST_LINE" in
    '#!'*)
      echo "$FIRST_LINE" >"$TMPFILE"
      printf "%s\n\n" "$HEADER" >>"$TMPFILE"
      tail -n +2 "$f" >>"$TMPFILE"
      ;;
    *)
      printf "%s\n\n" "$HEADER" >"$TMPFILE"
      cat "$f" >>"$TMPFILE"
      ;;
    esac

    mv "$TMPFILE" "$f"
    COUNT=$((COUNT + 1))
    log_success "Added header: $f"
  done

  if [ "$COUNT" -eq 0 ]; then
    log_info "All files already have headers."
  else
    log_success "Added headers to $COUNT file(s)."
  fi
}

cmd_update() {
  COUNT=0
  FILES=$(resolve_files "update" "$@")

  for f in $FILES; do
    [ -f "$f" ] || continue
    should_skip_file "$f" && continue
    STYLE=$(get_comment_style "$f")
    [ -z "$STYLE" ] && continue

    if ! file_has_header "$f"; then
      continue
    fi

    if grep -q "Copyright $CURRENT_YEAR" "$f"; then
      continue
    fi

    sed -i.bak "s/Copyright [0-9]\{4\} $ORG_NAME/Copyright $CURRENT_YEAR $ORG_NAME/" "$f"
    rm -f "$f.bak"
    COUNT=$((COUNT + 1))
    log_success "Updated year: $f"
  done

  if [ "$COUNT" -eq 0 ]; then
    log_info "All headers already have current year."
  else
    log_success "Updated year in $COUNT file(s)."
  fi
}

cmd_migrate() {
  TARGET_TYPE="$1"

  if [ -z "$TARGET_TYPE" ]; then
    log_error "Usage: license-header.sh migrate <open-source|private>"
    exit 1
  fi

  case "$TARGET_TYPE" in
  open-source | private) ;;
  *)
    log_error "Invalid type: $TARGET_TYPE (use 'open-source' or 'private')"
    exit 1
    ;;
  esac

  CURRENT_TYPE=$(detect_license_type)

  if [ "$CURRENT_TYPE" = "$TARGET_TYPE" ]; then
    log_info "Repo is already $TARGET_TYPE. Nothing to do."
    exit 0
  fi

  log_info "Migrating from $CURRENT_TYPE to $TARGET_TYPE..."

  # Step 1: Remove existing headers from all files
  FILES=$(get_all_source_files)

  for f in $FILES; do
    [ -f "$f" ] || continue
    STYLE=$(get_comment_style "$f")
    [ -z "$STYLE" ] && continue

    if ! file_has_header "$f"; then
      continue
    fi

    TMPFILE=$(mktemp)
    IN_HEADER=0
    HEADER_DONE=0

    while IFS= read -r line; do
      if [ "$HEADER_DONE" -eq 1 ]; then
        echo "$line" >>"$TMPFILE"
        continue
      fi

      # Keep shebangs
      case "$line" in
      '#!'*)
        echo "$line" >>"$TMPFILE"
        continue
        ;;
      esac

      # Detect header start
      case "$line" in
      *Copyright*"$ORG_NAME"*)
        IN_HEADER=1
        continue
        ;;
      esac

      if [ "$IN_HEADER" -eq 1 ]; then
        IS_COMMENT=0
        case "$STYLE" in
        hash) case "$line" in '#'* | '') IS_COMMENT=1 ;; esac ;;
        slash) case "$line" in '//'* | '') IS_COMMENT=1 ;; esac ;;
        html) case "$line" in '<!--'* | '-->'* | '') IS_COMMENT=1 ;; esac ;;
        esac

        if [ "$IS_COMMENT" -eq 1 ]; then
          continue
        else
          HEADER_DONE=1
          echo "$line" >>"$TMPFILE"
        fi
      else
        echo "$line" >>"$TMPFILE"
      fi
    done <"$f"

    mv "$TMPFILE" "$f"
  done

  log_success "Removed old headers from all files."

  # Step 2: Handle LICENSE file
  if [ "$TARGET_TYPE" = "private" ]; then
    if [ -f "LICENSE" ]; then
      rm LICENSE
      log_success "Removed LICENSE file (repo is now private)"
    fi
  elif [ "$TARGET_TYPE" = "open-source" ]; then
    if [ ! -f "LICENSE" ]; then
      TEMPLATE="${CONFIGS_DIR}/LICENSE-apache-2.0"
      if [ -f "$TEMPLATE" ]; then
        sed "s/{YEAR}/$CURRENT_YEAR/g; s/{ORG}/$ORG_NAME/g" "$TEMPLATE" >LICENSE
      else
        log_error "License template not found: $TEMPLATE"
        log_info "Create a LICENSE file manually."
      fi
      log_success "Created Apache 2.0 LICENSE file"
    fi
  fi

  # Step 3: Add new headers to all files
  cmd_add "--all"

  log_success "Migration to $TARGET_TYPE complete."
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

COMMAND="$1"
shift 2>/dev/null || true

case "$COMMAND" in
get) cmd_get ;;
check) cmd_check "$@" ;;
add) cmd_add "$@" ;;
update) cmd_update "$@" ;;
migrate) cmd_migrate "$@" ;;
*)
  echo "Usage: license-header.sh <get|check|add|update|migrate> [args]"
  echo ""
  echo "Commands:"
  echo "  get                     Print the license header for this repo"
  echo "  check <file|--staged>   Validate header exists and matches repo type"
  echo "  add <file|--all>        Add header to file(s) missing it"
  echo "  update <file|--all>     Update copyright year in existing headers"
  echo "  migrate <open-source|private>  Convert all files and LICENSE file"
  exit 1
  ;;
esac
