#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  echo "init" >README.md
  git add README.md
  git commit -m "init"

  SCRIPT="${PROJECT_ROOT}/scripts/node/coverage.sh"
}

teardown() {
  _common_teardown
}

@test "passes when tests pass and coverage meets baseline" {
  create_mock "npm" '
    echo "All files  |   96.5 |    95.0 |   98.0 |   96.5"
    exit 0
  '

  echo "96.0" >.coverage-baseline

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Coverage: 96.5"* ]]
}

@test "fails when tests fail" {
  create_mock "npm" 'exit 1'

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Tests failed"* ]]
}

@test "fails when coverage cannot be extracted" {
  create_mock "npm" '
    echo "no coverage info here"
    exit 0
  '

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Could not extract coverage percentage"* ]]
}

@test "shows running message" {
  create_mock "npm" '
    echo "All files  |   90.0 |    80.0 |   90.0 |   90.0"
    exit 0
  '

  run bash "$SCRIPT"
  [[ "$output" == *"Running tests with coverage"* ]]
}
