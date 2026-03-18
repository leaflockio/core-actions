#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  echo "init" >README.md
  git add README.md
  git commit -m "init"

  SCRIPT="${PROJECT_ROOT}/scripts/common/check-coverage.sh"
}

teardown() {
  _common_teardown
}

@test "fails when no percent argument provided" {
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage: check-coverage.sh"* ]]
}

@test "fails when coverage is below floor threshold" {
  run bash "$SCRIPT" 80
  [ "$status" -eq 1 ]
  [[ "$output" == *"below floor threshold"* ]]
}

@test "passes when coverage meets floor and no baseline exists" {
  run bash "$SCRIPT" 96
  [ "$status" -eq 0 ]
  [[ "$output" == *"No .coverage-baseline found"* ]]
  [[ "$output" == *"Skipping delta check"* ]]
}

@test "passes when coverage equals floor threshold" {
  run bash "$SCRIPT" 95
  [ "$status" -eq 0 ]
}

@test "skips delta check when baseline file is empty" {
  echo "" >.coverage-baseline
  run bash "$SCRIPT" 96
  [ "$status" -eq 0 ]
  [[ "$output" == *"Empty .coverage-baseline"* ]]
}

@test "passes when coverage matches baseline" {
  echo "96" >.coverage-baseline
  run bash "$SCRIPT" 96
  [ "$status" -eq 0 ]
  [[ "$output" == *"baseline: 96%"* ]]
}

@test "passes when coverage drops within allowed delta" {
  echo "96.04" >.coverage-baseline
  run bash "$SCRIPT" 96
  [ "$status" -eq 0 ]
  [[ "$output" == *"-0.04%"* ]]
}

@test "fails when coverage drops beyond allowed delta" {
  echo "96.10" >.coverage-baseline
  run bash "$SCRIPT" 96
  [ "$status" -eq 1 ]
  [[ "$output" == *"Coverage dropped"* ]]
  [[ "$output" == *"0.10%"* ]]
}

@test "fails when coverage drop equals max delta" {
  echo "96.05" >.coverage-baseline
  # Default COVERAGE_MAX_DROP is 0.05, drop is exactly 0.05 — should pass (> not >=)
  run bash "$SCRIPT" 96
  [ "$status" -eq 0 ]
}

@test "shows gain when coverage improved" {
  echo "95" >.coverage-baseline
  run bash "$SCRIPT" 97
  [ "$status" -eq 0 ]
  [[ "$output" == *"+2.00%"* ]]
}

@test "respects custom floor from .hooks-config" {
  echo "COVERAGE_FLOOR=80" >.hooks-config
  git add .hooks-config
  run bash "$SCRIPT" 82
  [ "$status" -eq 0 ]
}

@test "respects custom max drop from .hooks-config" {
  echo "96" >.coverage-baseline
  printf 'COVERAGE_MAX_DROP=1\nCOVERAGE_FLOOR=80\n' >.hooks-config
  git add .hooks-config
  run bash "$SCRIPT" 95.5
  [ "$status" -eq 0 ]
}
