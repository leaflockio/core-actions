#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup

  SCRIPT="${PROJECT_ROOT}/scripts/go/check-lint.sh"
}

teardown() {
  _common_teardown
}

@test "passes when golangci-lint succeeds" {
  create_mock "golangci-lint" 'exit 0'

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"golangci-lint passed"* ]]
}

@test "fails when golangci-lint fails" {
  create_mock "golangci-lint" 'exit 1'

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"golangci-lint found issues"* ]]
}

@test "shows running message" {
  create_mock "golangci-lint" 'exit 0'

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Running golangci-lint"* ]]
}
