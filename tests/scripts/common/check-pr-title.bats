#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  echo "init" >README.md
  git add README.md
  git commit -m "init"

  SCRIPT="${PROJECT_ROOT}/scripts/common/check-pr-title.sh"
}

teardown() {
  _common_teardown
}

@test "accepts valid feat title" {
  run env PR_TITLE="feat: add login page" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PR title is valid"* ]]
}

@test "accepts valid fix title with scope" {
  run env PR_TITLE="fix(auth): correct null pointer" bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "accepts breaking change with bang" {
  run env PR_TITLE="feat!: remove deprecated endpoints" bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "accepts breaking change with scope and bang" {
  run env PR_TITLE="feat(api)!: remove v1 endpoints" bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "rejects title without type prefix" {
  run env PR_TITLE="add login page" bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid PR title"* ]]
}

@test "rejects title with invalid type" {
  run env PR_TITLE="feature: add login page" bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid PR title"* ]]
}

@test "rejects title exceeding 72 characters" {
  run env PR_TITLE="feat: this is a very long pr title that exceeds the seventy two character limit for sure" bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"characters (max 72)"* ]]
}

@test "accepts title with PR number suffix within limit after stripping" {
  # 71 chars + " (#58)" = 77 chars raw — mirrors the real CI failure case
  run env PR_TITLE="fix(update-major-tag): skip update when version is not a stable release (#58)" bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "accepts title at exactly 72 chars with PR number suffix" {
  # "fix(scope): " (12) + 60 a's = 72 chars, plus " (#1)" suffix
  run env PR_TITLE="fix(scope): aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa (#1)" bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "rejects title exceeding 72 chars even after stripping PR number suffix" {
  # 73 chars + " (#1)" — stripping still leaves 73 chars which exceeds limit
  run env PR_TITLE="feat: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa (#1)" bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"characters (max 72)"* ]]
}

@test "rejects description starting with uppercase" {
  run env PR_TITLE="feat: Add login page" bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be lowercase"* ]]
}

@test "accepts all valid types" {
  for type in feat fix chore docs refactor test style perf ci build revert; do
    run env PR_TITLE="${type}: valid message" bash "$SCRIPT"
    [ "$status" -eq 0 ]
  done
}

@test "fails when PR_TITLE is not set" {
  unset PR_TITLE
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"PR_TITLE is not set"* ]]
}
