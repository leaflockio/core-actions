#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  echo "init" >README.md
  git add README.md
  git commit -m "init"

  SCRIPT="${PROJECT_ROOT}/scripts/common/check-rebase.sh"
}

teardown() {
  _common_teardown
}

@test "blocks rebasing main branch" {
  run sh "$SCRIPT" "pre-main" "main"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Rebasing 'main' is not allowed"* ]]
}

@test "blocks rebasing master branch" {
  run sh "$SCRIPT" "pre-main" "master"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Rebasing 'master' is not allowed"* ]]
}

@test "blocks rebasing pre-main branch" {
  run sh "$SCRIPT" "main" "pre-main"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Rebasing 'pre-main' is not allowed"* ]]
}

@test "allows rebasing feature branch with warning" {
  git checkout -b feature/42-add-tests
  run sh "$SCRIPT" "pre-main" "feature/42-add-tests"
  [ "$status" -eq 0 ]
  [[ "$output" == *"--force-with-lease"* ]]
}

@test "uses current branch when second arg is empty" {
  # On main, should block
  run sh "$SCRIPT" "pre-main"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Rebasing 'main' is not allowed"* ]]
}
