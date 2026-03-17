#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  echo "init" >README.md
  git add README.md
  git commit -m "init"

  SCRIPT="${PROJECT_ROOT}/scripts/common/check-signing.sh"
}

teardown() {
  _common_teardown
}

@test "fails when commit is not signed" {
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"is not signed"* ]]
}
