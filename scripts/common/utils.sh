#!/bin/sh
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Shared logging utilities. Sourced by config.sh — do not source directly.
# Use: . "$(dirname "$0")/config.sh"

supports_color() {
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
