#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  echo "init" > README.md
  git add README.md
  git commit -m "init"

  SCRIPT="${PROJECT_ROOT}/scripts/common/check-commit-size.sh"
}

teardown() {
  _common_teardown
}

@test "exits 0 in all mode (not applicable)" {
  echo "CHECK_MODE=all" > .hooks-config
  git add .hooks-config

  run sh "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "no warning when changes are under limit" {
  seq 1 10 > small.js
  git add small.js

  run sh "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Commit changes"* ]]
}

@test "warns when changes exceed MAX_COMMIT_LINES" {
  echo "MAX_COMMIT_LINES=5" > .hooks-config
  git add .hooks-config
  git commit -m "add config"

  seq 1 20 > big.js
  git add big.js

  run sh "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Commit changes"* ]]
  [[ "$output" == *"splitting into smaller"* ]]
}

@test "excludes test files from count" {
  seq 1 500 > app.test.js
  git add app.test.js

  run sh "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Commit changes"* ]]
}
