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

# Helper: create a coverage-summary.json with given .pct values.
# Usage: create_summary lines_pct statements_pct functions_pct branches_pct
create_summary() {
  mkdir -p coverage
  cat >coverage/coverage-summary.json <<EOF
{"total":{"lines":{"pct":$1},"statements":{"pct":$2},"functions":{"pct":$3},"branches":{"pct":$4}}}
EOF
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

@test "fails when jq returns null from malformed summary" {
  create_mock "npm" 'exit 0'
  mkdir -p coverage
  echo '{"total":{}}' >coverage/coverage-summary.json

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Could not extract coverage metrics"* ]]
}

@test "shows running message" {
  create_mock "npm" 'exit 0'
  create_summary 90 90 90 90

  run bash "$SCRIPT"
  [[ "$output" == *"Running tests with coverage"* ]]
}

@test "shows report path" {
  create_mock "npm" 'exit 0'
  create_summary 90 90 90 90

  run bash "$SCRIPT"
  [[ "$output" == *"Report:"* ]]
}

@test "uses custom COVERAGE_SCRIPT when set" {
  create_mock "npm" '
    if echo "$@" | grep -q "test:custom:cov"; then
      exit 0
    fi
    echo "wrong script: $@" >&2
    exit 1
  '
  create_summary 96 96 96 96
  printf 'COVERAGE_FLOOR=0\nCOVERAGE_MAX_DROP=0.05\n' >.hooks-config
  git add .hooks-config

  export COVERAGE_SCRIPT="test:custom:cov"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ── Legacy floor (no COVERAGE_CONFIG_NODE) ────────────────────────

@test "passes with all metrics above legacy floor and no baseline" {
  create_mock "npm" 'exit 0'
  create_summary 96 97 98 95
  printf 'COVERAGE_FLOOR=80\nCOVERAGE_MAX_DROP=0.05\n' >.hooks-config
  git add .hooks-config

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"lines: 96%"* ]]
  [[ "$output" == *"statements: 97%"* ]]
  [[ "$output" == *"functions: 98%"* ]]
  [[ "$output" == *"branches: 95%"* ]]
}

@test "fails when one metric below legacy floor" {
  create_mock "npm" 'exit 0'
  create_summary 96 97 98 79
  printf 'COVERAGE_FLOOR=80\nCOVERAGE_MAX_DROP=0.05\n' >.hooks-config
  git add .hooks-config

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"branches: 79% is below floor (80%)"* ]]
}

# ── COVERAGE_CONFIG_NODE floor ────────────────────────────────────

@test "passes with all metrics meeting COVERAGE_CONFIG_NODE per-metric floor" {
  create_mock "npm" 'exit 0'
  create_summary 80 80 75 70

  export COVERAGE_CONFIG_NODE='{"floor":{"lines":80,"statements":80,"functions":75,"branches":70},"delta":0.05}'
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "fails when one metric below COVERAGE_CONFIG_NODE floor" {
  create_mock "npm" 'exit 0'
  create_summary 80 80 74 70

  export COVERAGE_CONFIG_NODE='{"floor":{"lines":80,"statements":80,"functions":75,"branches":70},"delta":0.05}'
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"functions: 74% is below floor (75%)"* ]]
}

@test "COVERAGE_CONFIG_NODE overrides legacy COVERAGE_FLOOR" {
  create_mock "npm" 'exit 0'
  # legacy floor is 95 — metrics are 80, would fail without override
  create_summary 80 80 75 70
  printf 'COVERAGE_FLOOR=95\n' >.hooks-config
  git add .hooks-config

  export COVERAGE_CONFIG_NODE='{"floor":{"lines":80,"statements":80,"functions":75,"branches":70},"delta":0.05}'
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ── Baseline and delta ────────────────────────────────────────────

@test "passes with JSON tagged baseline, all metrics match" {
  create_mock "npm" 'exit 0'
  create_summary 96 96 96 96
  printf 'js: {"lines":96,"statements":96,"functions":96,"branches":96}\n' >.coverage-baseline

  export COVERAGE_TAG="js"
  export COVERAGE_CONFIG_NODE='{"floor":{"lines":0,"statements":0,"functions":0,"branches":0},"delta":0.05}'
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"lines: 96%"* ]]
}

@test "detects regression against JSON tagged baseline" {
  create_mock "npm" 'exit 0'
  create_summary 96 96 96 96
  printf 'js: {"lines":96.1,"statements":96,"functions":96,"branches":96}\n' >.coverage-baseline

  export COVERAGE_TAG="js"
  export COVERAGE_CONFIG_NODE='{"floor":{"lines":0,"statements":0,"functions":0,"branches":0},"delta":0.05}'
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"lines: dropped"* ]]
}

@test "shows improvement when metric increases from baseline" {
  create_mock "npm" 'exit 0'
  create_summary 97 96 96 96
  printf 'js: {"lines":96,"statements":96,"functions":96,"branches":96}\n' >.coverage-baseline

  export COVERAGE_TAG="js"
  export COVERAGE_CONFIG_NODE='{"floor":{"lines":0,"statements":0,"functions":0,"branches":0},"delta":0.05}'
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"+1.00% from"* ]]
}

@test "uses custom summaryFile from COVERAGE_CONFIG_NODE when set" {
  create_mock "npm" 'exit 0'
  mkdir -p custom-reports
  cat >custom-reports/summary.json <<EOF
{"total":{"lines":{"pct":90},"statements":{"pct":90},"functions":{"pct":90},"branches":{"pct":90}}}
EOF

  export COVERAGE_CONFIG_NODE='{"floor":{"lines":80,"statements":80,"functions":80,"branches":80},"delta":0.05,"summaryFile":"custom-reports/summary.json"}'
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"lines: 90%"* ]]
}

@test "fails when custom summaryFile does not exist" {
  create_mock "npm" 'exit 0'

  export COVERAGE_CONFIG_NODE='{"floor":{"lines":80,"statements":80,"functions":80,"branches":80},"delta":0.05,"summaryFile":"no-such-dir/summary.json"}'
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Coverage summary not found"* ]]
}

@test "warns and skips delta when baseline is a plain number" {
  create_mock "npm" 'exit 0'
  create_summary 96 96 96 96
  echo "96" >.coverage-baseline

  export COVERAGE_CONFIG_NODE='{"floor":{"lines":0,"statements":0,"functions":0,"branches":0},"delta":0.05}'
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"plain number"* ]]
  [[ "$output" == *"migrate"* ]]
}
