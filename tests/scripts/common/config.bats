#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  SCRIPT_DIR="${PROJECT_ROOT}/scripts/common"
  REPO_DIR="${TEST_TEMP_DIR}/repo"
}

teardown() {
  _common_teardown
}

# Usage: get_config_var VAR_NAME [PRE_COMMANDS]
get_config_var() {
  local var="$1"
  local pre="${2:-}"
  local wrapper="${TEST_TEMP_DIR}/.config-test-wrapper-$$.sh"
  cat >"$wrapper" <<EOF
#!/usr/bin/env bash
${pre}
. "${SCRIPT_DIR}/config.sh"
eval 'printf "%s\n" "\$${var}"'
EOF
  local result
  result=$(cd "$REPO_DIR" && bash "$wrapper")
  printf '%s' "$result"
}

# Usage: run_config [PRE_COMMANDS]
# Runs config.sh in a standalone script and captures exit code + output.
run_config() {
  local pre="${1:-}"
  local wrapper="${TEST_TEMP_DIR}/.config-run-wrapper-$$.sh"
  cat >"$wrapper" <<EOF
#!/usr/bin/env bash
cd "$REPO_DIR"
${pre}
. "${SCRIPT_DIR}/config.sh"
EOF
  run bash "$wrapper"
}

@test "config sets default values" {
  [ "$(get_config_var PARTIAL_STAGE)" = "fail" ]
  [ "$(get_config_var UNCOMMITTED_PUSH)" = "fail" ]
  [ "$(get_config_var MAX_FILE_SIZE)" = "1000000" ]
  [ "$(get_config_var MAX_FILE_LINES)" = "2000" ]
  [ "$(get_config_var MAX_COMMIT_LINES)" = "400" ]
  [ "$(get_config_var MAX_COMMIT_MSG_LENGTH)" = "72" ]
  [ "$(get_config_var PROTECTED_BRANCHES)" = "main master pre-main" ]
  [ "$(get_config_var LINK_CHECK_TIMEOUT)" = "5" ]
  [ "$(get_config_var CHECK_MODE)" = "staged" ]
}

@test "config reads overrides from .hooks-config" {
  cat >.hooks-config <<'EOF'
MAX_FILE_SIZE=500000
MAX_FILE_LINES=1000
PROTECTED_BRANCHES=main develop
EOF

  [ "$(get_config_var MAX_FILE_SIZE)" = "500000" ]
  [ "$(get_config_var MAX_FILE_LINES)" = "1000" ]
  [ "$(get_config_var PROTECTED_BRANCHES)" = "main develop" ]
  [ "$(get_config_var MAX_COMMIT_LINES)" = "400" ]
}

@test "config ignores comments and blank lines in .hooks-config" {
  cat >.hooks-config <<'EOF'
# This is a comment
MAX_FILE_SIZE=999

EOF

  [ "$(get_config_var MAX_FILE_SIZE)" = "999" ]
  [ "$(get_config_var MAX_FILE_LINES)" = "2000" ]
}

@test "config populates CHECK_FILES from staged files in staged mode" {
  echo "hello" >test.txt
  git add test.txt
  git commit -m "init"

  echo "world" >new.txt
  git add new.txt

  local result
  result="$(get_config_var CHECK_FILES)"
  echo "$result" | grep -q "new.txt"
}

@test "config populates CHECK_FILES from all tracked files in all mode" {
  echo "hello" >test.txt
  git add test.txt
  git commit -m "init"

  echo "CHECK_MODE=all" >.hooks-config

  local result
  result="$(get_config_var CHECK_FILES)"
  echo "$result" | grep -q "test.txt"
}

# ── CHECK_MODE: pr ────────────────────────────────────────────────

@test "pr mode populates CHECK_FILES from diff against PR_BASE_SHA" {
  echo "base" >base.txt
  git add base.txt
  git commit -m "base commit"

  BASE_SHA=$(git rev-parse HEAD)

  # Create a feature branch so three-dot diff has a real merge-base
  git checkout -b feature
  echo "pr change" >pr-file.txt
  git add pr-file.txt
  git commit -m "pr commit"

  local result
  result="$(get_config_var CHECK_FILES "export CHECK_MODE=pr; export PR_BASE_SHA=${BASE_SHA}")"
  echo "$result" | grep -q "pr-file.txt"
  ! echo "$result" | grep -q "base.txt"
}

@test "pr mode fails when PR_BASE_SHA is not set" {
  echo "file" >file.txt
  git add file.txt
  git commit -m "init"

  run_config 'export CHECK_MODE=pr; unset PR_BASE_SHA'
  [ "$status" -ne 0 ]
  echo "$output" | grep -q "PR_BASE_SHA"
}

@test "pr mode fails when PR_BASE_SHA is empty" {
  echo "file" >file.txt
  git add file.txt
  git commit -m "init"

  run_config 'export CHECK_MODE=pr; export PR_BASE_SHA=""'
  [ "$status" -ne 0 ]
  echo "$output" | grep -q "PR_BASE_SHA"
}

# ── Coverage and remaining config keys ────────────────────────────

@test "config reads all coverage keys from .hooks-config" {
  cat >.hooks-config <<'EOF'
COVERAGE_MAX_DROP=1.0
COVERAGE_FLOOR=80
COVERAGE_SRC=src lib
COVERAGE_SCRIPT=test:custom:cov
COVERAGE_TAG=js
COVERAGE_DIR=coverage/js
EOF

  [ "$(get_config_var COVERAGE_MAX_DROP)" = "1.0" ]
  [ "$(get_config_var COVERAGE_FLOOR)" = "80" ]
  [ "$(get_config_var COVERAGE_SRC)" = "src lib" ]
  [ "$(get_config_var COVERAGE_SCRIPT)" = "test:custom:cov" ]
  [ "$(get_config_var COVERAGE_TAG)" = "js" ]
  [ "$(get_config_var COVERAGE_DIR)" = "coverage/js" ]
}

@test "config reads remaining keys from .hooks-config" {
  cat >.hooks-config <<'EOF'
PARTIAL_STAGE=prompt
UNCOMMITTED_PUSH=prompt
MAX_COMMIT_LINES=200
MAX_COMMIT_MSG_LENGTH=50
LINK_CHECK_TIMEOUT=10
CHECK_MODE=all
EOF

  [ "$(get_config_var PARTIAL_STAGE)" = "prompt" ]
  [ "$(get_config_var UNCOMMITTED_PUSH)" = "prompt" ]
  [ "$(get_config_var MAX_COMMIT_LINES)" = "200" ]
  [ "$(get_config_var MAX_COMMIT_MSG_LENGTH)" = "50" ]
  [ "$(get_config_var LINK_CHECK_TIMEOUT)" = "10" ]
  [ "$(get_config_var CHECK_MODE)" = "all" ]
}

# ── COVERAGE_CONFIG_* keys ────────────────────────────────────────

@test "config defaults CHECK_PATHS_SKIP_FILES to empty array" {
  [ "$(get_config_var CHECK_PATHS_SKIP_FILES)" = "[]" ]
}

@test "config reads CHECK_PATHS_SKIP_FILES from .hooks-config" {
  cat >.hooks-config <<'EOF'
CHECK_PATHS_SKIP_FILES=["Dockerfile","Dockerfile.*","*.dockerfile"]
EOF

  result="$(get_config_var CHECK_PATHS_SKIP_FILES)"
  [ "$result" = '["Dockerfile","Dockerfile.*","*.dockerfile"]' ]
}

@test "config defaults COVERAGE_CONFIG_* to empty string" {
  [ "$(get_config_var COVERAGE_CONFIG_NODE)" = "" ]
  [ "$(get_config_var COVERAGE_CONFIG_SHELL)" = "" ]
  [ "$(get_config_var COVERAGE_CONFIG_GO)" = "" ]
  [ "$(get_config_var COVERAGE_CONFIG_PYTHON)" = "" ]
}

@test "config reads COVERAGE_CONFIG_NODE with JSON value from .hooks-config" {
  cat >.hooks-config <<'EOF'
COVERAGE_CONFIG_NODE={"floor":{"lines":80,"statements":80,"functions":75,"branches":70},"delta":2}
EOF

  result="$(get_config_var COVERAGE_CONFIG_NODE)"
  [ "$result" = '{"floor":{"lines":80,"statements":80,"functions":75,"branches":70},"delta":2}' ]
}

@test "config reads all COVERAGE_CONFIG_* keys from .hooks-config" {
  cat >.hooks-config <<'EOF'
COVERAGE_CONFIG_NODE={"floor":{"lines":80,"statements":80,"functions":75,"branches":70},"delta":2}
COVERAGE_CONFIG_SHELL={"floor":60,"delta":5}
COVERAGE_CONFIG_GO={"floor":75,"delta":2}
COVERAGE_CONFIG_PYTHON={"floor":75,"delta":2}
EOF

  [ "$(get_config_var COVERAGE_CONFIG_SHELL)" = '{"floor":60,"delta":5}' ]
  [ "$(get_config_var COVERAGE_CONFIG_GO)" = '{"floor":75,"delta":2}' ]
  [ "$(get_config_var COVERAGE_CONFIG_PYTHON)" = '{"floor":75,"delta":2}' ]
}
