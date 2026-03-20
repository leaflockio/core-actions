#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  echo "init" >README.md
  git add README.md
  git commit -m "init"

  SCRIPT="${PROJECT_ROOT}/scripts/common/check-branch-name.sh"
}

teardown() {
  _common_teardown
}

@test "exits 0 for file checkout (not branch checkout)" {
  # $3 = 0 means file checkout
  run bash "$SCRIPT" "" "" "0"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "exits 0 when no checkout type provided and on protected branch" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "skips protected branches without warning" {
  # On main, $3=1 (branch checkout)
  run bash "$SCRIPT" "" "" "1"
  [ "$status" -eq 0 ]
  [[ "$output" != *"does not follow convention"* ]]
}

@test "warns on invalid branch name during branch checkout" {
  git checkout -b bad-branch-name
  run bash "$SCRIPT" "" "" "1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"does not follow convention"* ]]
  [[ "$output" == *"Rename with"* ]]
}

@test "no warning on valid branch name" {
  git checkout -b feature/42-add-tests
  run bash "$SCRIPT" "" "" "1"
  [ "$status" -eq 0 ]
  [[ "$output" != *"does not follow convention"* ]]
}

# CI mode tests (no args — validates and fails on invalid)

@test "ci mode passes on valid branch name" {
  git checkout -b feature/42-add-tests
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Branch name is valid"* ]]
}

@test "ci mode fails on invalid branch name" {
  git checkout -b bad-branch-name
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not follow convention"* ]]
}

@test "ci mode skips protected branches" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "ci mode uses GITHUB_HEAD_REF when set" {
  export GITHUB_HEAD_REF="feature/99-from-pr"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Branch name is valid"* ]]
  unset GITHUB_HEAD_REF
}

@test "ci mode fails when GITHUB_HEAD_REF is invalid" {
  export GITHUB_HEAD_REF="bad-name"
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not follow convention"* ]]
  unset GITHUB_HEAD_REF
}
