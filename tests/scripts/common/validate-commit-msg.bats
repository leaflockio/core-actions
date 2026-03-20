#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  echo "init" >README.md
  git add README.md
  git commit -m "init"

  SCRIPT="${PROJECT_ROOT}/scripts/common/validate-commit-msg.sh"
  MSG_FILE="${TEST_TEMP_DIR}/commit-msg"
}

teardown() {
  _common_teardown
}

@test "accepts valid feat commit message" {
  echo "feat: add login page" >"$MSG_FILE"
  run bash "$SCRIPT" "$MSG_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Commit message format is valid"* ]]
}

@test "accepts valid fix commit with scope" {
  echo "fix(auth): correct null pointer" >"$MSG_FILE"
  run bash "$SCRIPT" "$MSG_FILE"
  [ "$status" -eq 0 ]
}

@test "accepts breaking change with bang" {
  echo "feat!: remove deprecated endpoints" >"$MSG_FILE"
  run bash "$SCRIPT" "$MSG_FILE"
  [ "$status" -eq 0 ]
}

@test "accepts breaking change with scope and bang" {
  echo "feat(api)!: remove v1 endpoints" >"$MSG_FILE"
  run bash "$SCRIPT" "$MSG_FILE"
  [ "$status" -eq 0 ]
}

@test "rejects message without type prefix" {
  echo "add login page" >"$MSG_FILE"
  run bash "$SCRIPT" "$MSG_FILE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid commit message"* ]]
}

@test "rejects message with invalid type" {
  echo "feature: add login page" >"$MSG_FILE"
  run bash "$SCRIPT" "$MSG_FILE"
  [ "$status" -eq 1 ]
}

@test "rejects message exceeding 72 characters" {
  echo "feat: this is a very long commit message that exceeds the seventy two character limit for sure" >"$MSG_FILE"
  run bash "$SCRIPT" "$MSG_FILE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"characters (max 72)"* ]]
}

@test "rejects description starting with uppercase" {
  echo "feat: Add login page" >"$MSG_FILE"
  run bash "$SCRIPT" "$MSG_FILE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be lowercase"* ]]
}

@test "accepts all valid types" {
  for type in feat fix chore docs refactor test style perf ci build revert; do
    echo "${type}: valid message" >"$MSG_FILE"
    run bash "$SCRIPT" "$MSG_FILE"
    [ "$status" -eq 0 ]
  done
}

# CI mode tests (no args — checks all commits)

@test "ci mode passes with valid commits" {
  git clone --quiet "${TEST_TEMP_DIR}/repo" "${TEST_TEMP_DIR}/remote" --bare
  cd "${TEST_TEMP_DIR}/repo"
  git remote add origin "${TEST_TEMP_DIR}/remote"
  git push --quiet -u origin main

  git checkout -b feature/1-test
  echo "change" >file.txt
  git add file.txt
  git commit -m "feat: add feature"

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"All commit messages are valid"* ]]
}

@test "ci mode fails with invalid commit" {
  git clone --quiet "${TEST_TEMP_DIR}/repo" "${TEST_TEMP_DIR}/remote2" --bare
  cd "${TEST_TEMP_DIR}/repo"
  git remote add origin "${TEST_TEMP_DIR}/remote2"
  git push --quiet -u origin main

  git checkout -b feature/2-test
  echo "change" >file.txt
  git add file.txt
  git commit -m "bad message no type"

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid commit message"* ]]
}

@test "ci mode checks all commits in range" {
  git clone --quiet "${TEST_TEMP_DIR}/repo" "${TEST_TEMP_DIR}/remote3" --bare
  cd "${TEST_TEMP_DIR}/repo"
  git remote add origin "${TEST_TEMP_DIR}/remote3"
  git push --quiet -u origin main

  git checkout -b feature/3-test
  echo "a" >a.txt
  git add a.txt
  git commit -m "feat: first change"

  echo "b" >b.txt
  git add b.txt
  git commit -m "bad second commit"

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid commit message"* ]]
}

@test "ci mode fails when no remote branch exists" {
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"No remote branch found"* ]]
}

@test "ci mode passes with no new commits" {
  git clone --quiet "${TEST_TEMP_DIR}/repo" "${TEST_TEMP_DIR}/remote4" --bare
  cd "${TEST_TEMP_DIR}/repo"
  git remote add origin "${TEST_TEMP_DIR}/remote4"
  git push --quiet -u origin main

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No new commits to validate"* ]]
}
