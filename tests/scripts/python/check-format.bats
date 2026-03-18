#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  echo "init" >README.md
  git add README.md
  git commit -m "init"

  SCRIPT="${PROJECT_ROOT}/scripts/python/check-format.sh"
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

@test "passes when ruff format check succeeds" {
  create_mock "ruff" 'exit 0'

  echo "" >main.py
  git add main.py

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Format check passed"* ]]
}

@test "fails when ruff format check fails" {
  create_mock "ruff" 'exit 1'

  echo "" >main.py
  git add main.py

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Formatting issues found"* ]]
}

@test "shows fix hint on failure" {
  create_mock "ruff" 'exit 1'

  echo "" >main.py
  git add main.py

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ruff format"* ]]
}

@test "only checks staged Python files" {
  create_mock "ruff" 'exit 0'

  echo "" >staged.py
  echo "" >unstaged.py
  git add staged.py

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}
