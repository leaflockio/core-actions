#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup

  # Set env vars the script expects
  export GITHUB_TOKEN="fake-token"
  export GITHUB_REPOSITORY="leaflockio/core-actions"

  SCRIPT="${PROJECT_ROOT}/scripts/release/force-sync.sh"

  # Track curl calls
  CURL_LOG="${TEST_TEMP_DIR}/curl_calls.log"
  export CURL_LOG

  # Ensure real jq is available via test bin
  REAL_JQ="$(which jq)"
  [ -n "$REAL_JQ" ] && ln -sf "$REAL_JQ" "${TEST_BIN_DIR}/jq"
}

teardown() {
  _common_teardown
}

@test "updates pre-main ref to main HEAD SHA" {
  cat >"${TEST_BIN_DIR}/curl" <<'MOCK'
#!/bin/sh
echo "$@" >> "$CURL_LOG"
case "$@" in
  *GET*/git/ref/heads/main*)
    echo '{"object": {"sha": "abc123main"}}'
    ;;
  *GET*/git/ref/heads/pre-main*)
    echo '{"object": {"sha": "def456premain"}}'
    ;;
  *PATCH*/git/refs/heads/pre-main*)
    echo '{"ref": "refs/heads/pre-main", "object": {"sha": "abc123main"}}'
    ;;
esac
MOCK
  chmod +x "${TEST_BIN_DIR}/curl"

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"force-synced to main HEAD"* ]]
  [[ "$output" == *"abc123m"* ]]

  # Verify PATCH was called with force: true and main's SHA
  PATCH_CALL="$(grep "PATCH" "$CURL_LOG")"
  [[ "$PATCH_CALL" == *"abc123main"* ]]
  [[ "$PATCH_CALL" == *"force"* ]]
}

@test "exits 0 with skip message when already in sync" {
  cat >"${TEST_BIN_DIR}/curl" <<'MOCK'
#!/bin/sh
echo "$@" >> "$CURL_LOG"
case "$@" in
  *GET*/git/ref/heads/main*)
    echo '{"object": {"sha": "same-sha-000"}}'
    ;;
  *GET*/git/ref/heads/pre-main*)
    echo '{"object": {"sha": "same-sha-000"}}'
    ;;
esac
MOCK
  chmod +x "${TEST_BIN_DIR}/curl"

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"already points to main HEAD"* ]]

  # No PATCH call should have been made
  ! grep -q "PATCH" "$CURL_LOG" 2>/dev/null
}

@test "fails when API returns null main SHA" {
  cat >"${TEST_BIN_DIR}/curl" <<'MOCK'
#!/bin/sh
echo "$@" >> "$CURL_LOG"
case "$@" in
  *GET*/git/ref/heads/main*)
    echo '{}'
    ;;
esac
MOCK
  chmod +x "${TEST_BIN_DIR}/curl"

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Failed to get main HEAD SHA"* ]]
}

@test "fails when API returns null pre-main SHA" {
  cat >"${TEST_BIN_DIR}/curl" <<'MOCK'
#!/bin/sh
echo "$@" >> "$CURL_LOG"
case "$@" in
  *GET*/git/ref/heads/main*)
    echo '{"object": {"sha": "abc123main"}}'
    ;;
  *GET*/git/ref/heads/pre-main*)
    echo '{}'
    ;;
esac
MOCK
  chmod +x "${TEST_BIN_DIR}/curl"

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Failed to get pre-main HEAD SHA"* ]]
}

@test "exits 1 on API error" {
  cat >"${TEST_BIN_DIR}/curl" <<'MOCK'
#!/bin/sh
echo "$@" >> "$CURL_LOG"
# Simulate API failure (curl -f exits non-zero on HTTP errors)
exit 22
MOCK
  chmod +x "${TEST_BIN_DIR}/curl"

  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
}
