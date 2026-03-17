#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  echo "init" >README.md
  git add README.md
  git commit -m "init"

  SCRIPT="${PROJECT_ROOT}/scripts/common/check-file-length.sh"
}

teardown() {
  _common_teardown
}

@test "passes when no files to check" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "passes with file under limit" {
  seq 1 100 >short.js
  git add short.js

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"File length check passed"* ]]
}

@test "blocks file exceeding default 2000 lines" {
  seq 1 2001 >long.js
  git add long.js

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"File too long"* ]]
}

@test "respects custom MAX_FILE_LINES from .hooks-config" {
  echo "MAX_FILE_LINES=50" >.hooks-config
  seq 1 51 >medium.js
  git add medium.js .hooks-config

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"File too long"* ]]
}

@test "skips binary and generated files" {
  seq 1 3000 >image.png
  seq 1 3000 >deps.lock
  git add image.png deps.lock

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "skips CHANGELOG and LICENSE files" {
  seq 1 3000 >CHANGELOG.md
  seq 1 3000 >LICENSE
  git add CHANGELOG.md LICENSE

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}
