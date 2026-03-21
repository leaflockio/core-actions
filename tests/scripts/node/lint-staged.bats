#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup

  SCRIPT="${PROJECT_ROOT}/scripts/node/lint-staged.sh"
}

teardown() {
  _common_teardown
}

@test "passes when lint-staged succeeds" {
  create_mock "npx" 'exit 0'

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"lint-staged passed"* ]]
}

@test "fails when lint-staged fails" {
  create_mock "npx" 'exit 1'

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"lint-staged failed"* ]]
}

@test "shows running message" {
  create_mock "npx" 'exit 0'

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Running lint-staged"* ]]
}
