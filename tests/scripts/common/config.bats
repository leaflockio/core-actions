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
  local wrapper="${SCRIPT_DIR}/.config-test-wrapper-$$.sh"
  cat >"$wrapper" <<EOF
#!/usr/bin/env bash
${pre}
. "\$(dirname "\${BASH_SOURCE[0]}")/config.sh"
eval 'printf "%s\n" "\$${var}"'
EOF
  local result
  result=$(cd "$REPO_DIR" && bash "$wrapper")
  rm -f "$wrapper"
  printf '%s' "$result"
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
