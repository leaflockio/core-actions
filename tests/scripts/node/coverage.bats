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

@test "uses custom COVERAGE_SCRIPT when set" {
  create_mock "npm" '
    # Verify the script name was passed
    if echo "$@" | grep -q "test:custom:cov"; then
      echo "All files  |   96.0 |    95.0 |   98.0 |   96.0"
      exit 0
    fi
    echo "wrong script: $@" >&2
    exit 1
  '

  export COVERAGE_SCRIPT="test:custom:cov"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Coverage: 96.0"* ]]
}

@test "passes COVERAGE_TAG to check-coverage" {
  create_mock "npm" '
    echo "All files  |   96.0 |    95.0 |   98.0 |   96.0"
    exit 0
  '

  printf 'js: 96.0\nshell: 80.0\n' >.coverage-baseline

  export COVERAGE_TAG="js"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"baseline: 96.0%"* ]]
}

@test "COVERAGE_TAG regression detected against tagged baseline" {
  create_mock "npm" '
    echo "All files  |   96.0 |    95.0 |   98.0 |   96.0"
    exit 0
  '

  printf 'js: 96.10\nshell: 80.0\n' >.coverage-baseline

  export COVERAGE_TAG="js"
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Coverage dropped"* ]]
}
