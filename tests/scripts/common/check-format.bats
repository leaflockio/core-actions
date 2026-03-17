#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  echo "init" >README.md
  git add README.md
  git commit -m "init"

  SCRIPT="${PROJECT_ROOT}/scripts/common/check-format.sh"
}

teardown() {
  _common_teardown
}

@test "fails when prettier is not installed" {
  run env -i PATH="${TEST_BIN_DIR}:/usr/bin:/bin" NO_COLOR=1 HOME="$HOME" bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"prettier is not installed"* ]]
}

@test "passes when no formattable files staged" {
  create_mock prettier
  echo "hello" >data.bin
  git add data.bin

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No files to format check"* ]]
}

@test "passes when prettier reports files are formatted" {
  create_mock prettier 'exit 0'
  echo '{"key": "value"}' >config.json
  git add config.json

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Formatting check passed"* ]]
}

@test "fails when prettier reports unformatted files" {
  create_mock prettier 'exit 1'
  echo '{"key":"value"}' >config.json
  git add config.json

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Not formatted"* ]]
}

@test "checks only formattable extensions" {
  create_mock prettier 'exit 1'
  echo "data" >file.bin
  git add file.bin

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}
