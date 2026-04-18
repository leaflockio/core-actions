#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  echo "init" >README.md
  git add README.md
  git commit -m "init"

  SCRIPT="${PROJECT_ROOT}/scripts/go/coverage.sh"
}

teardown() {
  _common_teardown
}

@test "skips when no Go packages found" {
  create_mock "go" '
    if [ "$1" = "list" ]; then
      exit 0
    fi
  '

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No Go packages found, skipping coverage"* ]]
}

@test "passes when tests pass and coverage meets baseline" {
  create_mock "go" '
    if [ "$1" = "list" ]; then
      echo "example.com/pkg"
      exit 0
    elif [ "$1" = "test" ]; then
      echo "ok"
      touch coverage.out
      exit 0
    elif [ "$1" = "tool" ] && [ "$2" = "cover" ] && echo "$*" | grep -q "\-func"; then
      echo "total:	(statements)	96.0%"
      exit 0
    elif [ "$1" = "tool" ] && [ "$2" = "cover" ] && echo "$*" | grep -q "\-html"; then
      exit 0
    fi
  '

  echo "96.0" >.coverage-baseline

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Coverage: 96"* ]]
}

@test "runs tests with race detector" {
  create_mock "go" '
    if [ "$1" = "list" ]; then
      echo "example.com/pkg"
      exit 0
    elif [ "$1" = "test" ]; then
      if ! echo "$*" | grep -q "\-race"; then
        echo "missing -race flag"
        exit 1
      fi
      touch coverage.out
      exit 0
    elif [ "$1" = "tool" ] && [ "$2" = "cover" ] && echo "$*" | grep -q "\-func"; then
      echo "total:	(statements)	96.0%"
      exit 0
    elif [ "$1" = "tool" ] && [ "$2" = "cover" ] && echo "$*" | grep -q "\-html"; then
      exit 0
    fi
  '

  echo "96.0" >.coverage-baseline

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "fails when tests fail" {
  create_mock "go" '
    if [ "$1" = "list" ]; then
      echo "example.com/pkg"
      exit 0
    elif [ "$1" = "test" ]; then
      echo "FAIL"
      exit 1
    fi
  '

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Tests failed"* ]]
}

@test "fails when coverage cannot be extracted" {
  create_mock "go" '
    if [ "$1" = "list" ]; then
      echo "example.com/pkg"
      exit 0
    elif [ "$1" = "test" ]; then
      exit 0
    elif [ "$1" = "tool" ]; then
      echo ""
      exit 0
    fi
  '

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Could not extract coverage percentage"* ]]
}

@test "shows running message" {
  create_mock "go" '
    if [ "$1" = "list" ]; then
      echo "example.com/pkg"
      exit 0
    elif [ "$1" = "test" ]; then
      touch coverage.out
      exit 0
    elif [ "$1" = "tool" ] && [ "$2" = "cover" ] && echo "$*" | grep -q "\-func"; then
      echo "total:	(statements)	96.0%"
      exit 0
    elif [ "$1" = "tool" ] && [ "$2" = "cover" ] && echo "$*" | grep -q "\-html"; then
      exit 0
    fi
  '

  run bash "$SCRIPT"
  [[ "$output" == *"Running Go tests with coverage"* ]]
}

@test "uses custom command from COVERAGE_CONFIG_GO" {
  create_mock "go" '
    if [ "$1" = "list" ]; then
      echo "example.com/pkg"
      exit 0
    elif [ "$1" = "test" ]; then
      echo "go test should not be called with custom command"
      exit 1
    elif [ "$1" = "tool" ] && [ "$2" = "cover" ] && echo "$*" | grep -q "\-func"; then
      echo "total:	(statements)	96.0%"
      exit 0
    elif [ "$1" = "tool" ] && [ "$2" = "cover" ] && echo "$*" | grep -q "\-html"; then
      exit 0
    fi
  '

  export COVERAGE_CONFIG_GO='{"command": "touch coverage/coverage.out"}'
  echo "96.0" >.coverage-baseline

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Coverage: 96"* ]]
}

@test "falls back to default command when no command field in COVERAGE_CONFIG_GO" {
  create_mock "go" '
    if [ "$1" = "list" ]; then
      echo "example.com/pkg"
      exit 0
    elif [ "$1" = "test" ]; then
      mkdir -p coverage
      touch coverage/coverage.out
      exit 0
    elif [ "$1" = "tool" ] && [ "$2" = "cover" ] && echo "$*" | grep -q "\-func"; then
      echo "total:	(statements)	96.0%"
      exit 0
    elif [ "$1" = "tool" ] && [ "$2" = "cover" ] && echo "$*" | grep -q "\-html"; then
      exit 0
    fi
  '

  export COVERAGE_CONFIG_GO='{"tag": "v1"}'
  echo "96.0" >.coverage-baseline

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Coverage: 96"* ]]
}
