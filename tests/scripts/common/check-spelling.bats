#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  echo "init" >README.md
  git add README.md
  git commit -m "init"

  SCRIPT="${PROJECT_ROOT}/scripts/common/check-spelling.sh"
}

teardown() {
  _common_teardown
}

@test "fails when cspell is not installed" {
  run env -i PATH="${TEST_BIN_DIR}:/usr/bin:/bin" NO_COLOR=1 HOME="$HOME" sh "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"cspell is not installed"* ]]
}

@test "passes when no files to check" {
  create_mock cspell
  # No staged files
  run sh "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No files to spell check"* ]]
}

@test "passes when cspell reports no errors" {
  create_mock cspell 'exit 0'
  echo "hello world" >doc.md
  git add doc.md

  run sh "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Spelling check passed"* ]]
}

@test "fails when cspell reports errors" {
  create_mock cspell 'echo "misspelled word"; exit 1'
  # Build misspelled content dynamically to avoid triggering cspell on this file
  # Write misspelled content via variable to avoid cspell flagging this file
  local bad="spe"
  bad="${bad}ling er${bad:0:0}or"
  printf '%s\n' "$bad" >doc.md
  git add doc.md

  run sh "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Spelling errors detected"* ]]
}
