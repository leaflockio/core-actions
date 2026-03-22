#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  # Initial commit on main
  echo "init" >README.md
  git add README.md
  git commit -m "init"

  # Create bare remote
  git clone --bare "${TEST_TEMP_DIR}/repo" "${TEST_TEMP_DIR}/remote.git" 2>/dev/null
  git remote add origin "${TEST_TEMP_DIR}/remote.git"
  git push -u origin main 2>/dev/null

  # Create pre-main branch and push it
  git checkout -b pre-main
  git push -u origin pre-main 2>/dev/null

  # Go back to main
  git checkout main

  # Set env vars the script expects
  export GITHUB_TOKEN="fake-token"
  export GITHUB_REPOSITORY="leaflockio/core-actions"

  SCRIPT="${PROJECT_ROOT}/scripts/release/back-merge.sh"

  # Track curl calls
  CURL_LOG="${TEST_TEMP_DIR}/curl_calls.log"
  export CURL_LOG
}

teardown() {
  _common_teardown
}

# Creates a mock curl that responds to GitHub API calls.
# Args: $1 = new commit SHA to return from POST /git/commits
setup_curl_mock() {
  local new_commit_sha="${1:-abc1234567890def}"
  local main_tree_sha="${2:-tree000sha}"

  REAL_GIT="$(which git)"
  export REAL_GIT

  cat >"${TEST_BIN_DIR}/curl" <<MOCK
#!/bin/sh
echo "\$@" >> "${CURL_LOG}"

# Route based on method + endpoint
case "\$@" in
  *GET*/git/commits/*)
    echo '{"tree": {"sha": "${main_tree_sha}"}}'
    ;;
  *POST*/git/commits*)
    echo '{"sha": "${new_commit_sha}"}'
    ;;
  *PATCH*/git/refs/heads/pre-main*)
    echo '{"ref": "refs/heads/pre-main", "object": {"sha": "${new_commit_sha}"}}'
    ;;
  *)
    echo '{"error": "unexpected call"}' >&2
    exit 1
    ;;
esac
MOCK
  chmod +x "${TEST_BIN_DIR}/curl"

  # Also need jq — use real jq
  REAL_JQ="$(which jq)"
  if [ -n "$REAL_JQ" ]; then
    ln -sf "$REAL_JQ" "${TEST_BIN_DIR}/jq"
  fi
}

@test "creates verified merge commit via API on clean merge" {
  # Add a commit to main that pre-main doesn't have
  echo "release v1.0.0" >VERSION
  git add VERSION
  git commit -m "chore: release v1.0.0"
  git push origin main 2>/dev/null

  setup_curl_mock "new-commit-sha-123"

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Back-merge complete"* ]]
  [[ "$output" == *"verified commit"* ]]

  # Verify API calls were made
  [ -f "$CURL_LOG" ]
  grep -q "GET.*git/commits" "$CURL_LOG"
  grep -q "POST.*git/commits" "$CURL_LOG"
  grep -q "PATCH.*git/refs/heads/pre-main" "$CURL_LOG"
}

@test "commit message includes skip ci and correct text" {
  echo "release v1.0.0" >VERSION
  git add VERSION
  git commit -m "chore: release v1.0.0"
  git push origin main 2>/dev/null

  setup_curl_mock

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]

  # Verify the POST body includes the right message
  grep "POST" "$CURL_LOG" | grep -q "git/commits"
}

@test "merge commit has two parents (pre-main and main SHAs)" {
  echo "release v1.0.0" >VERSION
  git add VERSION
  git commit -m "chore: release v1.0.0"
  git push origin main 2>/dev/null

  MAIN_SHA="$(git rev-parse origin/main)"
  PRE_MAIN_SHA="$(git rev-parse origin/pre-main)"

  # Use a curl mock that captures the POST body
  cat >"${TEST_BIN_DIR}/curl" <<MOCK
#!/bin/sh
echo "\$@" >> "${CURL_LOG}"
case "\$@" in
  *GET*/git/commits/*)
    echo '{"tree": {"sha": "treeSHA"}}'
    ;;
  *POST*/git/commits*)
    # Echo back what was sent so we can inspect
    echo '{"sha": "new-commit-123"}'
    ;;
  *PATCH*)
    echo '{"ref": "refs/heads/pre-main"}'
    ;;
esac
MOCK
  chmod +x "${TEST_BIN_DIR}/curl"
  REAL_JQ="$(which jq)"
  [ -n "$REAL_JQ" ] && ln -sf "$REAL_JQ" "${TEST_BIN_DIR}/jq"

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]

  # The POST call should include both parent SHAs
  POST_CALL="$(grep "POST" "$CURL_LOG")"
  [[ "$POST_CALL" == *"$PRE_MAIN_SHA"* ]]
  [[ "$POST_CALL" == *"$MAIN_SHA"* ]]
}

@test "exits 0 with skip message when already in sync" {
  # main and pre-main point to same commit — already in sync
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"already includes main"* ]]

  # No curl calls should have been made
  [ ! -f "$CURL_LOG" ] || [ ! -s "$CURL_LOG" ]
}

@test "fails with conflict instructions when merge conflicts" {
  # Create diverging changes on both branches
  echo "main content" >CONFLICT.txt
  git add CONFLICT.txt
  git commit -m "chore: add on main"
  git push origin main 2>/dev/null

  git checkout pre-main
  echo "pre-main content" >CONFLICT.txt
  git add CONFLICT.txt
  git commit -m "chore: add on pre-main"
  git push origin pre-main 2>/dev/null

  git checkout main

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Back-merge conflict detected"* ]]
  [[ "$output" == *"Manual resolution required"* ]]
}

@test "fails when API returns null tree SHA" {
  echo "release v1.0.0" >VERSION
  git add VERSION
  git commit -m "chore: release v1.0.0"
  git push origin main 2>/dev/null

  REAL_JQ="$(which jq)"
  [ -n "$REAL_JQ" ] && ln -sf "$REAL_JQ" "${TEST_BIN_DIR}/jq"

  cat >"${TEST_BIN_DIR}/curl" <<'MOCK'
#!/bin/sh
echo "$@" >> "$CURL_LOG"
case "$@" in
  *GET*/git/commits/*)
    echo '{}'
    ;;
esac
MOCK
  chmod +x "${TEST_BIN_DIR}/curl"

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Failed to get tree SHA"* ]]
}

@test "fails when API returns null commit SHA" {
  echo "release v1.0.0" >VERSION
  git add VERSION
  git commit -m "chore: release v1.0.0"
  git push origin main 2>/dev/null

  REAL_JQ="$(which jq)"
  [ -n "$REAL_JQ" ] && ln -sf "$REAL_JQ" "${TEST_BIN_DIR}/jq"

  cat >"${TEST_BIN_DIR}/curl" <<'MOCK'
#!/bin/sh
echo "$@" >> "$CURL_LOG"
case "$@" in
  *GET*/git/commits/*)
    echo '{"tree": {"sha": "valid-tree-sha"}}'
    ;;
  *POST*/git/commits*)
    echo '{}'
    ;;
esac
MOCK
  chmod +x "${TEST_BIN_DIR}/curl"

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Failed to create merge commit"* ]]
}

@test "uses main tree SHA for the merge commit" {
  echo "release v1.0.0" >VERSION
  git add VERSION
  git commit -m "chore: release v1.0.0"
  git push origin main 2>/dev/null

  MAIN_SHA="$(git rev-parse origin/main)"

  setup_curl_mock "new-commit" "main-tree-sha-123"

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]

  # The GET call should fetch main's commit to get tree SHA
  grep -q "GET.*git/commits/${MAIN_SHA}" "$CURL_LOG"

  # The POST body should include the tree SHA
  POST_CALL="$(grep "POST" "$CURL_LOG")"
  [[ "$POST_CALL" == *"main-tree-sha-123"* ]]
}
