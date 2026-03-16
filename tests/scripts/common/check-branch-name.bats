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
  run sh "$SCRIPT" "" "" "0"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "exits 0 when no checkout type provided" {
  run sh "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "skips protected branches without warning" {
  # On main, $3=1 (branch checkout)
  run sh "$SCRIPT" "" "" "1"
  [ "$status" -eq 0 ]
  [[ "$output" != *"does not follow convention"* ]]
}

@test "warns on invalid branch name during branch checkout" {
  git checkout -b bad-branch-name
  run sh "$SCRIPT" "" "" "1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"does not follow convention"* ]]
  [[ "$output" == *"Rename with"* ]]
}

@test "no warning on valid branch name" {
  git checkout -b feature/42-add-tests
  run sh "$SCRIPT" "" "" "1"
  [ "$status" -eq 0 ]
  [[ "$output" != *"does not follow convention"* ]]
}
