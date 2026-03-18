#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup

  SCRIPT="${PROJECT_ROOT}/scripts/go/vet.sh"
}

teardown() {
  _common_teardown
}

@test "passes when go vet succeeds" {
  create_mock "go" 'exit 0'

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"go vet passed"* ]]
}

@test "fails when go vet fails" {
  create_mock "go" 'exit 1'

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"go vet found issues"* ]]
}

@test "shows running message" {
  create_mock "go" 'exit 0'

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Running go vet"* ]]
}
