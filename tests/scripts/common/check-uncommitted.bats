#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  echo "init" >README.md
  git add README.md
  git commit -m "init"

  # Create a fake remote by cloning into a bare repo
  git clone --bare "${TEST_TEMP_DIR}/repo" "${TEST_TEMP_DIR}/remote.git" 2>/dev/null
  git remote add origin "${TEST_TEMP_DIR}/remote.git"
  git push -u origin main 2>/dev/null

  SCRIPT="${PROJECT_ROOT}/scripts/common/check-uncommitted.sh"
}

teardown() {
  _common_teardown
}

@test "exits 0 when no uncommitted changes" {
  echo "new" >file.txt
  git add file.txt
  git commit -m "add file"

  run sh "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "exits 0 when dirty files are not in push" {
  echo "new" >file.txt
  git add file.txt
  git commit -m "add file"

  # Dirty a different file that is not part of the push
  echo "changed" >README.md

  run sh "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "blocks when pushed file has uncommitted changes" {
  echo "new" >file.txt
  git add file.txt
  git commit -m "add file"

  # Modify the same file without committing
  echo "local fix" >file.txt

  run sh "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"uncommitted local changes"* ]]
  [[ "$output" == *"file.txt"* ]]
}

@test "exits 0 when no commits ahead of remote" {
  # All commits are already pushed, dirty file is not in any push diff
  echo "dirty" >>README.md

  run sh "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "prompt mode allows push on Y" {
  echo "new" >file.txt
  git add file.txt
  git commit -m "add file"
  echo "local fix" >file.txt

  echo "UNCOMMITTED_PUSH=prompt" >.hooks-config

  run sh "$SCRIPT" <<<"y"
  [ "$status" -eq 0 ]
}

@test "prompt mode blocks push on N" {
  echo "new" >file.txt
  git add file.txt
  git commit -m "add file"
  echo "local fix" >file.txt

  echo "UNCOMMITTED_PUSH=prompt" >.hooks-config

  run sh "$SCRIPT" <<<"n"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Push aborted"* ]]
}

@test "exits 0 when no remote tracking branch and no origin" {
  git remote remove origin

  echo "new" >file.txt
  git add file.txt
  git commit -m "add file"
  echo "dirty" >file.txt

  run sh "$SCRIPT"
  [ "$status" -eq 0 ]
}
