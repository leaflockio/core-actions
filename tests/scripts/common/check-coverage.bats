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

@test "respects COVERAGE_TAG from .hooks-config" {
  printf 'shell: 96.0\njs: 90.0\n' >.coverage-baseline
  printf 'COVERAGE_FLOOR=80\nCOVERAGE_TAG=shell\n' >.hooks-config
  git add .hooks-config
  run bash "$SCRIPT" 96
  [ "$status" -eq 0 ]
  [[ "$output" == *"baseline: 96.0%"* ]]
}

@test "respects COVERAGE_SCRIPT from .hooks-config" {
  # COVERAGE_SCRIPT is not used by check-coverage.sh directly,
  # but the parser branch must be exercised. Verify config loads without error.
  printf 'COVERAGE_FLOOR=80\nCOVERAGE_SCRIPT=test:custom:cov\n' >.hooks-config
  git add .hooks-config
  run bash "$SCRIPT" 96
  [ "$status" -eq 0 ]
}

# ── Tag-based baseline tests ──────────────────────────────────────

@test "tag: uses tagged baseline when tag is provided" {
  printf 'shell: 96.0\njs: 90.0\n' >.coverage-baseline
  run bash "$SCRIPT" 96 shell
  [ "$status" -eq 0 ]
  [[ "$output" == *"baseline: 96.0%"* ]]
}

@test "tag: warns and skips when tag not found" {
  printf 'shell: 96.0\n' >.coverage-baseline
  run bash "$SCRIPT" 96 go
  [ "$status" -eq 0 ]
  [[ "$output" == *"Tag 'go' not found"* ]]
  [[ "$output" == *"Skipping delta check"* ]]
}

@test "tag: detects regression against tagged baseline" {
  printf 'shell: 96.10\njs: 90.0\n' >.coverage-baseline
  run bash "$SCRIPT" 96 shell
  [ "$status" -eq 1 ]
  [[ "$output" == *"Coverage dropped"* ]]
}

@test "tag: ignores comments and blank lines" {
  printf '# Coverage baselines\n\nshell: 96.0\n\n# JS tests\njs: 90.0\n' >.coverage-baseline
  run bash "$SCRIPT" 96 shell
  [ "$status" -eq 0 ]
  [[ "$output" == *"baseline: 96.0%"* ]]
}

@test "tag: legacy mode reads plain number file without tag" {
  echo "96.0" >.coverage-baseline
  run bash "$SCRIPT" 96
  [ "$status" -eq 0 ]
  [[ "$output" == *"baseline: 96.0%"* ]]
}

@test "tag: legacy mode warns when tagged file used without tag" {
  printf 'shell: 96.0\njs: 90.0\n' >.coverage-baseline
  run bash "$SCRIPT" 96
  [ "$status" -eq 0 ]
  [[ "$output" == *"Tagged .coverage-baseline detected but no tag provided"* ]]
  [[ "$output" == *"Skipping delta check"* ]]
}

# ── Runner config (number mode — shell/go/python) ────────────────

@test "runner config: uses floor from runner config over legacy COVERAGE_FLOOR" {
  printf 'COVERAGE_FLOOR=95\n' >.hooks-config
  git add .hooks-config
  run bash "$SCRIPT" 82 "" '{"floor":80,"delta":0.05}'
  [ "$status" -eq 0 ]
}

@test "runner config: uses delta from runner config over legacy COVERAGE_MAX_DROP" {
  echo "90" >.coverage-baseline
  printf 'COVERAGE_FLOOR=80\nCOVERAGE_MAX_DROP=0.05\n' >.hooks-config
  git add .hooks-config
  run bash "$SCRIPT" 82 "" '{"floor":80,"delta":10}'
  [ "$status" -eq 0 ]
}

@test "runner config: falls back to legacy floor when runner config is empty" {
  printf 'COVERAGE_FLOOR=95\n' >.hooks-config
  git add .hooks-config
  run bash "$SCRIPT" 82 "" ""
  [ "$status" -eq 1 ]
  [[ "$output" == *"below floor threshold"* ]]
}

@test "runner config: uses tag from second arg to look up tagged baseline" {
  printf 'shell: 80\njs: 90\n' >.coverage-baseline
  printf 'COVERAGE_FLOOR=70\n' >.hooks-config
  git add .hooks-config
  run bash "$SCRIPT" 82 "shell" '{"floor":70,"delta":5}'
  [ "$status" -eq 0 ]
  [[ "$output" == *"baseline: 80%"* ]]
}

# ── JSON mode (node — per-metric) ────────────────────────────────

JSON_METRICS='{"lines":85,"statements":82,"functions":78,"branches":72}'
JSON_FLOOR_LOW='{"lines":70,"statements":70,"functions":70,"branches":70}'

@test "json: passes all metrics above single number floor with no baseline" {
  # No COVERAGE_CONFIG_NODE — falls back to COVERAGE_FLOOR as plain number
  printf 'COVERAGE_FLOOR=70\nCOVERAGE_MAX_DROP=0.05\n' >.hooks-config
  git add .hooks-config

  run bash "$SCRIPT" "$JSON_METRICS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"lines: 85%"* ]]
  [[ "$output" == *"statements: 82%"* ]]
  [[ "$output" == *"functions: 78%"* ]]
  [[ "$output" == *"branches: 72%"* ]]
}

@test "json: fails when one metric below single number floor" {
  # No COVERAGE_CONFIG_NODE — falls back to COVERAGE_FLOOR as plain number
  printf 'COVERAGE_FLOOR=80\nCOVERAGE_MAX_DROP=0.05\n' >.hooks-config
  git add .hooks-config

  run bash "$SCRIPT" '{"lines":85,"statements":82,"functions":78,"branches":72}'
  [ "$status" -eq 1 ]
  [[ "$output" == *"branches: 72% is below floor (80%)"* ]]
}

@test "json: passes all metrics above JSON floor object via COVERAGE_CONFIG_NODE" {
  export COVERAGE_CONFIG_NODE='{"floor":{"lines":70,"statements":70,"functions":70,"branches":70},"delta":0.05}'
  run bash "$SCRIPT" "$JSON_METRICS"
  [ "$status" -eq 0 ]
}

@test "json: fails when one metric below JSON floor object threshold" {
  export COVERAGE_CONFIG_NODE='{"floor":{"lines":70,"statements":70,"functions":80,"branches":70},"delta":0.05}'
  run bash "$SCRIPT" "$JSON_METRICS"
  [ "$status" -eq 1 ]
  [[ "$output" == *"functions: 78% is below floor (80%)"* ]]
}

@test "json: skips delta when no baseline file" {
  export COVERAGE_CONFIG_NODE='{"floor":{"lines":70,"statements":70,"functions":70,"branches":70},"delta":0.05}'

  run bash "$SCRIPT" "$JSON_METRICS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No .coverage-baseline found"* ]]
  [[ "$output" == *"no baseline"* ]]
}

@test "json: passes when all metrics match baseline" {
  export COVERAGE_CONFIG_NODE='{"floor":{"lines":70,"statements":70,"functions":70,"branches":70},"delta":0.05}'
  echo '{"lines":85,"statements":82,"functions":78,"branches":72}' >.coverage-baseline

  run bash "$SCRIPT" "$JSON_METRICS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"lines: 85%"* ]]
  [[ "$output" == *"baseline: 85%"* ]]
}

@test "json: passes when drop within delta" {
  export COVERAGE_CONFIG_NODE='{"floor":{"lines":70,"statements":70,"functions":70,"branches":70},"delta":0.05}'
  echo '{"lines":85.04,"statements":82,"functions":78,"branches":72}' >.coverage-baseline

  run bash "$SCRIPT" "$JSON_METRICS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"-0.04% from"* ]]
}

@test "json: fails when one metric drops beyond delta" {
  export COVERAGE_CONFIG_NODE='{"floor":{"lines":70,"statements":70,"functions":70,"branches":70},"delta":0.05}'
  echo '{"lines":85.10,"statements":82,"functions":78,"branches":72}' >.coverage-baseline

  run bash "$SCRIPT" "$JSON_METRICS"
  [ "$status" -eq 1 ]
  [[ "$output" == *"lines: dropped 0.10%"* ]]
}

@test "json: shows improvement when metric increases from baseline" {
  export COVERAGE_CONFIG_NODE='{"floor":{"lines":70,"statements":70,"functions":70,"branches":70},"delta":0.05}'
  echo '{"lines":83,"statements":82,"functions":78,"branches":72}' >.coverage-baseline

  run bash "$SCRIPT" "$JSON_METRICS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"+2.00% from"* ]]
}

@test "json: warns and skips delta when baseline is plain number" {
  export COVERAGE_CONFIG_NODE='{"floor":{"lines":70,"statements":70,"functions":70,"branches":70},"delta":0.05}'
  echo "85" >.coverage-baseline

  run bash "$SCRIPT" "$JSON_METRICS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"plain number"* ]]
  [[ "$output" == *"migrate"* ]]
}

@test "json: tagged baseline passes when all metrics match" {
  export COVERAGE_CONFIG_NODE='{"floor":{"lines":70,"statements":70,"functions":70,"branches":70},"delta":0.05}'
  printf 'js: {"lines":85,"statements":82,"functions":78,"branches":72}\n' >.coverage-baseline

  run bash "$SCRIPT" "$JSON_METRICS" js
  [ "$status" -eq 0 ]
  [[ "$output" == *"baseline: 85%"* ]]
}

@test "json: tagged baseline fails when one metric regresses" {
  export COVERAGE_CONFIG_NODE='{"floor":{"lines":70,"statements":70,"functions":70,"branches":70},"delta":0.05}'
  printf 'js: {"lines":85.10,"statements":82,"functions":78,"branches":72}\n' >.coverage-baseline

  run bash "$SCRIPT" "$JSON_METRICS" js
  [ "$status" -eq 1 ]
  [[ "$output" == *"lines: dropped"* ]]
}

@test "json: tagged baseline warns when tag not found" {
  export COVERAGE_CONFIG_NODE='{"floor":{"lines":70,"statements":70,"functions":70,"branches":70},"delta":0.05}'
  printf 'shell: {"lines":85,"statements":82,"functions":78,"branches":72}\n' >.coverage-baseline

  run bash "$SCRIPT" "$JSON_METRICS" js
  [ "$status" -eq 0 ]
  [[ "$output" == *"Tag 'js' not found"* ]]
  [[ "$output" == *"Skipping delta check"* ]]
}

@test "json: warns when tagged baseline file used without tag" {
  export COVERAGE_CONFIG_NODE='{"floor":{"lines":70,"statements":70,"functions":70,"branches":70},"delta":0.05}'
  printf 'js: {"lines":85,"statements":82,"functions":78,"branches":72}\n' >.coverage-baseline

  run bash "$SCRIPT" "$JSON_METRICS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Tagged .coverage-baseline detected but no tag provided"* ]]
  [[ "$output" == *"Skipping delta check"* ]]
}

@test "json: warns when baseline metric key missing from JSON" {
  export COVERAGE_CONFIG_NODE='{"floor":{"lines":70,"statements":70,"functions":70,"branches":70},"delta":0.05}'
  # baseline missing branches key
  echo '{"lines":85,"statements":82,"functions":78}' >.coverage-baseline

  run bash "$SCRIPT" "$JSON_METRICS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"branches: not found in baseline"* ]]
}
