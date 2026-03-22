#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  echo "init" >README.md
  git add README.md
  git commit -q -m "init"

  SCRIPT="${PROJECT_ROOT}/scripts/node/coverage.sh"
}

teardown() {
  _common_teardown
}

# Helper: create a coverage-summary.json with given metrics.
# Usage: create_summary statements_covered statements_total branches_covered branches_total funcs_covered funcs_total lines_covered lines_total
create_summary() {
  mkdir -p coverage
  cat >coverage/coverage-summary.json <<EOF
{"total":{"statements":{"covered":$1,"total":$2},"branches":{"covered":$3,"total":$4},"functions":{"covered":$5,"total":$6},"lines":{"covered":$7,"total":$8}}}
EOF
}

@test "passes when tests pass and coverage meets baseline" {
  create_mock "npm" 'exit 0'
  create_summary 97 100 95 100 98 100 97 100
  echo "96.0" >.coverage-baseline

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Coverage: 96.75%"* ]]
}

@test "fails when tests fail" {
  create_mock "npm" 'exit 1'

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Tests failed"* ]]
}

@test "fails when coverage summary not found" {
  create_mock "npm" 'exit 0'

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Coverage summary not found"* ]]
}

@test "shows running message" {
  create_mock "npm" 'exit 0'
  create_summary 90 100 80 100 90 100 90 100

  run bash "$SCRIPT"
  [[ "$output" == *"Running tests with coverage"* ]]
}

@test "uses custom COVERAGE_SCRIPT when set" {
  create_mock "npm" '
    if echo "$@" | grep -q "test:custom:cov"; then
      exit 0
    fi
    echo "wrong script: $@" >&2
    exit 1
  '
  create_summary 96 100 95 100 98 100 96 100

  export COVERAGE_SCRIPT="test:custom:cov"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Coverage:"* ]]
}

@test "passes COVERAGE_TAG to check-coverage" {
  create_mock "npm" 'exit 0'
  create_summary 96 100 96 100 96 100 96 100

  printf 'js: 96.0\nshell: 80.0\n' >.coverage-baseline

  export COVERAGE_TAG="js"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"baseline: 96.0%"* ]]
}

@test "COVERAGE_TAG regression detected against tagged baseline" {
  create_mock "npm" 'exit 0'
  create_summary 96 100 96 100 96 100 96 100

  printf 'js: 96.10\nshell: 80.0\n' >.coverage-baseline

  export COVERAGE_TAG="js"
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Coverage dropped"* ]]
}

@test "fails when jq returns null from malformed summary" {
  create_mock "npm" 'exit 0'
  mkdir -p coverage
  echo '{"total":{}}' >coverage/coverage-summary.json

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Could not extract coverage"* ]]
}

@test "computes overall from all four metrics" {
  create_mock "npm" 'exit 0'
  # statements: 50/100=50%, branches: 40/100=40%, funcs: 30/100=30%, lines: 80/100=80%
  # overall: (50+40+30+80)/(100+100+100+100) = 200/400 = 50%
  create_summary 50 100 40 100 30 100 80 100

  printf 'COVERAGE_FLOOR=0\n' >.hooks-config
  git add .hooks-config

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Coverage: 50"* ]]
}
