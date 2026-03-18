#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  echo "init" >README.md
  git add README.md
  git commit -m "init"

  SCRIPT="${PROJECT_ROOT}/scripts/python/check-lint.sh"
}

teardown() {
  _common_teardown
}

@test "passes when no Python files staged" {
  echo "" >config.yml
  git add config.yml

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No Python files staged"* ]]
}

@test "passes when ruff check succeeds" {
  create_mock "ruff" 'exit 0'

  echo "" >main.py
  git add main.py

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Lint passed"* ]]
}

@test "fails when ruff check fails" {
  create_mock "ruff" 'exit 1'

  echo "" >main.py
  git add main.py

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Lint failed"* ]]
}

@test "shows running message" {
  create_mock "ruff" 'exit 0'

  echo "" >main.py
  git add main.py

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Running ruff lint"* ]]
}
