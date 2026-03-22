#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Shared logging utilities. Sourced by config.sh — do not source directly.
# Use: . "$(dirname "$0")/config.sh"

supports_color() {
  [ -n "$FORCE_COLOR" ] && return 0
  [ -n "$NO_COLOR" ] && return 1
  case "$(uname -s)" in
  MINGW* | CYGWIN* | MSYS*) return 1 ;;
  esac
  [ -t 1 ] && return 0
  return 1
}

if supports_color; then
  RED="\033[0;31m"
  GREEN="\033[0;32m"
  YELLOW="\033[1;33m"
  BLUE="\033[0;34m"
  RESET="\033[0m"
else
  RED="" GREEN="" YELLOW="" BLUE="" RESET=""
fi

log_info() { printf "${BLUE}ℹ  %s${RESET}\n" "$1"; }
log_warn() { printf "${YELLOW}⚠  %s${RESET}\n" "$1"; }
log_success() { printf "${GREEN}✔  %s${RESET}\n" "$1"; }
log_error() { printf "${RED}✖  %s${RESET}\n" "$1"; }

# ── Shared helpers ──────────────────────────────────────────────────

# Prompt Y/N. Returns 0 on Y, 1 on anything else.
# Usage: prompt_yn "Proceed?" "Commit aborted."
prompt_yn() {
  printf "%s [y/N] " "$1"
  read -r REPLY
  case "$REPLY" in
  y | Y) return 0 ;;
  *)
    [ -n "$2" ] && log_error "$2"
    return 1
    ;;
  esac
}

# Returns 0 if a rebase is in progress.
is_rebasing() {
  _git_dir=$(git rev-parse --git-dir 2>/dev/null) || return 1
  [ -d "$_git_dir/rebase-merge" ] || [ -d "$_git_dir/rebase-apply" ]
}

# Exit 1 if a command is not found.
# Usage: require_command "prettier" "npm install -g prettier"
require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log_error "$1 is not installed."
    log_info "Run: $2"
    exit 1
  fi
}

# Returns 0 if branch is in PROTECTED_BRANCHES, 1 otherwise.
# Usage: is_protected_branch "$BRANCH"
is_protected_branch() {
  for _pb in $PROTECTED_BRANCHES; do
    [ "$1" = "$_pb" ] && return 0
  done
  return 1
}

# Prints the remote tracking branch. Falls back to origin/main or origin/master.
# Returns 1 if no remote branch is found.
get_remote_branch() {
  _remote=$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)
  if [ -n "$_remote" ]; then
    echo "$_remote"
    return 0
  fi
  if git rev-parse --verify origin/main >/dev/null 2>&1; then
    echo "origin/main"
    return 0
  fi
  if git rev-parse --verify origin/master >/dev/null 2>&1; then
    echo "origin/master"
    return 0
  fi
  return 1
}

# Returns 0 for binary/generated files that should be skipped.
# Usage: is_skippable_file "image.png"
is_skippable_file() {
  case "$1" in
  *.png | *.jpg | *.gif | *.ico | *.svg | *.woff | *.woff2 | *.ttf | *.eot) return 0 ;;
  *.lock | *.min.js | *.min.css | *.map) return 0 ;;
  esac
  return 1
}

# Returns file content: full file in "all" mode, only added diff lines otherwise.
# Usage: get_file_content "file.js" "$CHECK_MODE"
get_file_content() {
  if [ "$2" = "all" ]; then
    cat "$1" 2>/dev/null || true
  else
    git diff --cached -- "$1" |
      grep '^+' |
      grep -v '^+++' || true
  fi
}
