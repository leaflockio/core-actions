#!/usr/bin/env bash
# Common test setup sourced by all .bats files.

# Resolve project root (two levels up from test_helper/)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export PROJECT_ROOT

_common_setup() {
  # Create isolated temp directory for each test
  TEST_TEMP_DIR="$(mktemp -d)"
  export TEST_TEMP_DIR

  # Disable color codes for predictable assertions
  export NO_COLOR=1

  # Prepend temp bin dir to PATH for mock commands
  TEST_BIN_DIR="${TEST_TEMP_DIR}/bin"
  mkdir -p "$TEST_BIN_DIR"
  export PATH="${TEST_BIN_DIR}:${PATH}"
}

_common_teardown() {
  # Clean up temp directory
  if [ -n "$TEST_TEMP_DIR" ] && [ -d "$TEST_TEMP_DIR" ]; then
    rm -rf "$TEST_TEMP_DIR"
  fi
}

# Create a mock executable in the temp bin dir.
# Usage: create_mock <command-name> [script-body]
create_mock() {
  local name="$1"
  local body="${2:-exit 0}"
  local mock_path="${TEST_BIN_DIR}/${name}"

  cat >"$mock_path" <<MOCK
#!/bin/sh
${body}
MOCK
  chmod +x "$mock_path"
}

# Initialize a git repo in the temp directory and cd into it.
init_test_repo() {
  git init --quiet -b main "${TEST_TEMP_DIR}/repo"
  cd "${TEST_TEMP_DIR}/repo" || return 1
  git config user.email "test@test.com"
  git config user.name "Test"
  git config commit.gpgsign false
}
