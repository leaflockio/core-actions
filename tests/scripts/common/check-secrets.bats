#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  echo "init" >README.md
  git add README.md
  git commit -m "init"

  SCRIPT="${PROJECT_ROOT}/scripts/common/check-secrets.sh"
}

teardown() {
  _common_teardown
}

@test "fails when gitleaks is not installed" {
  run env -i PATH="${TEST_BIN_DIR}:/usr/bin:/bin" NO_COLOR=1 HOME="$HOME" bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"gitleaks is not installed"* ]]
}

@test "passes when gitleaks finds no secrets in staged mode" {
  create_mock gitleaks 'exit 0'
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No secrets found"* ]]
}

@test "fails when gitleaks detects secrets in staged mode" {
  create_mock gitleaks 'exit 1'
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Secrets detected"* ]]
}

@test "uses detect mode when CHECK_MODE is all" {
  # Mock gitleaks that checks for 'detect' argument
  create_mock gitleaks '
    case "$1" in
      detect) exit 0 ;;
      *) exit 1 ;;
    esac'
  echo "CHECK_MODE=all" >.hooks-config
  git add .hooks-config

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No secrets found"* ]]
}

@test "uses protect --staged in staged mode" {
  # Mock gitleaks that checks for 'protect' argument
  create_mock gitleaks '
    case "$1" in
      protect) exit 0 ;;
      *) exit 1 ;;
    esac'

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}
