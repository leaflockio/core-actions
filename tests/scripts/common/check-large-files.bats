#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  echo "init" >README.md
  git add README.md
  git commit -m "init"

  SCRIPT="${PROJECT_ROOT}/scripts/common/check-large-files.sh"
}

teardown() {
  _common_teardown
}

@test "passes when no files to check" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Large file check passed"* ]]
}

@test "passes with small file" {
  echo "small content" >small.txt
  git add small.txt

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Large file check passed"* ]]
}

@test "blocks file exceeding default 1MB limit" {
  # Create a file just over 1MB
  dd if=/dev/zero of=big.bin bs=1024 count=1025 2>/dev/null
  git add big.bin

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"File too large"* ]]
}

@test "respects custom MAX_FILE_SIZE from .hooks-config" {
  echo "MAX_FILE_SIZE=100" >.hooks-config
  # Create file larger than 100 bytes
  dd if=/dev/zero of=medium.bin bs=1 count=200 2>/dev/null
  git add medium.bin .hooks-config

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"File too large"* ]]
}
