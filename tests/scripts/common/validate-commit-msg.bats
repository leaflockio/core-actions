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
