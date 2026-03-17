#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  # Initial commit so branches work
  echo "init" >README.md
  git add README.md
  git commit -m "init"

  SCRIPT="${PROJECT_ROOT}/scripts/common/check-branch.sh"
}

teardown() {
  _common_teardown
}

@test "blocks commit on main branch" {
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Direct commits to 'main' are not allowed"* ]]
}

@test "blocks commit on master branch" {
  git checkout -b master
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Direct commits to 'master'"* ]]
}

@test "blocks commit on pre-main branch" {
  git checkout -b pre-main
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Direct commits to 'pre-main' are not allowed"* ]]
}

@test "blocks invalid branch name" {
  git checkout -b my-bad-branch
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid branch name"* ]]
}

@test "passes with valid feature branch" {
  git checkout -b feature/123-add-login
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Branch check passed"* ]]
}

@test "passes with valid fix branch" {
  git checkout -b fix/87-login-redirect
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "passes with valid hotfix branch" {
  git checkout -b hotfix/201-payment-failure
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "blocks branch name missing issue number" {
  git checkout -b feature/add-login
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid branch name"* ]]
}

@test "blocks branch name with uppercase" {
  git checkout -b feature/123-Add-Login
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
}
