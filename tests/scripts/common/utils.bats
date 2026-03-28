#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  . "${PROJECT_ROOT}/scripts/common/utils.sh"
}

teardown() {
  _common_teardown
}

# --- supports_color ---

@test "supports_color returns 1 when NO_COLOR is set" {
  export NO_COLOR=1
  run supports_color
  [ "$status" -eq 1 ]
}

@test "supports_color returns 1 in non-interactive shell (no tty)" {
  unset NO_COLOR
  run supports_color
  [ "$status" -eq 1 ]
}

@test "supports_color returns 1 on Windows (MINGW)" {
  create_mock uname 'echo "MINGW64_NT-10.0"'
  run bash -c 'unset NO_COLOR; . "$1" && supports_color' _ "${PROJECT_ROOT}/scripts/common/utils.sh"
  [ "$status" -eq 1 ]
}

# --- color variables ---

@test "color variables are empty when NO_COLOR is set" {
  [ -z "$RED" ]
  [ -z "$GREEN" ]
  [ -z "$YELLOW" ]
  [ -z "$BLUE" ]
  [ -z "$RESET" ]
}

@test "color variables are set when color is supported" {
  run bash -c 'FORCE_COLOR=1 . "$1" && echo "$RED|$GREEN|$YELLOW|$BLUE|$RESET"' _ "${PROJECT_ROOT}/scripts/common/utils.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *'\033[0;31m'* ]]
  [[ "$output" == *'\033[0;32m'* ]]
  [[ "$output" == *'\033[1;33m'* ]]
  [[ "$output" == *'\033[0;34m'* ]]
  [[ "$output" == *'\033[0m'* ]]
}

@test "FORCE_COLOR overrides no-tty detection" {
  run bash -c 'export FORCE_COLOR=1; . "$1"; supports_color' _ "${PROJECT_ROOT}/scripts/common/utils.sh"
  [ "$status" -eq 0 ]
}

# --- log_info ---

@test "log_info outputs message with info prefix" {
  run log_info "hello world"
  [ "$status" -eq 0 ]
  [ "$output" = "ℹ  hello world" ]
}

# --- log_warn ---

@test "log_warn outputs message with warning prefix" {
  run log_warn "be careful"
  [ "$status" -eq 0 ]
  [ "$output" = "⚠  be careful" ]
}

# --- log_success ---

@test "log_success outputs message with success prefix" {
  run log_success "all good"
  [ "$status" -eq 0 ]
  [ "$output" = "✔  all good" ]
}

# --- log_error ---

@test "log_error outputs message with error prefix" {
  run log_error "something broke"
  [ "$status" -eq 0 ]
  [ "$output" = "✖  something broke" ]
}

# --- prompt_yn ---

@test "prompt_yn returns 0 on Y input" {
  run bash -c '. "$1" && echo "y" | prompt_yn "Continue?" "Aborted."' _ "${PROJECT_ROOT}/scripts/common/utils.sh"
  [ "$status" -eq 0 ]
}

@test "prompt_yn returns 1 on N input" {
  run bash -c '. "$1" && echo "n" | prompt_yn "Continue?" "Aborted."' _ "${PROJECT_ROOT}/scripts/common/utils.sh"
  [ "$status" -eq 1 ]
}

@test "prompt_yn returns 1 on empty input" {
  run bash -c '. "$1" && echo "" | prompt_yn "Continue?" "Aborted."' _ "${PROJECT_ROOT}/scripts/common/utils.sh"
  [ "$status" -eq 1 ]
}

@test "prompt_yn prints abort message on rejection" {
  run bash -c '. "$1" && echo "n" | prompt_yn "Continue?" "Aborted."' _ "${PROJECT_ROOT}/scripts/common/utils.sh"
  [[ "$output" == *"Aborted."* ]]
}

# --- require_command ---

@test "require_command passes for existing command" {
  run require_command "sh" "install sh"
  [ "$status" -eq 0 ]
}

@test "require_command exits 1 for missing command" {
  run bash -c '. "$1" && require_command "nonexistent_cmd_xyz" "brew install xyz"' _ "${PROJECT_ROOT}/scripts/common/utils.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"nonexistent_cmd_xyz is not installed"* ]]
  [[ "$output" == *"brew install xyz"* ]]
}

# --- is_protected_branch ---

@test "is_protected_branch returns 0 for main" {
  PROTECTED_BRANCHES="main master pre-main"
  run is_protected_branch "main"
  [ "$status" -eq 0 ]
}

@test "is_protected_branch returns 0 for pre-main" {
  PROTECTED_BRANCHES="main master pre-main"
  run is_protected_branch "pre-main"
  [ "$status" -eq 0 ]
}

@test "is_protected_branch returns 1 for feature branch" {
  PROTECTED_BRANCHES="main master pre-main"
  run is_protected_branch "feature/123-foo"
  [ "$status" -eq 1 ]
}

# --- get_remote_branch ---

@test "get_remote_branch returns origin/main when it exists" {
  init_test_repo
  echo "init" >README.md
  git add README.md
  git commit -m "init"
  git remote add origin "${TEST_TEMP_DIR}/repo"
  git fetch origin

  run get_remote_branch
  [ "$status" -eq 0 ]
  [ "$output" = "origin/main" ]
}

@test "get_remote_branch falls back to origin/master" {
  init_test_repo
  echo "init" >README.md
  git add README.md
  git commit -m "init"

  # Rename default branch to master so origin/main doesn't exist
  git branch -m main master
  git remote add origin "${TEST_TEMP_DIR}/repo"
  git fetch origin

  run get_remote_branch
  [ "$status" -eq 0 ]
  [ "$output" = "origin/master" ]
}

@test "get_remote_branch returns 1 when no remote exists" {
  init_test_repo
  echo "init" >README.md
  git add README.md
  git commit -m "init"

  run get_remote_branch
  [ "$status" -eq 1 ]
}

# --- is_skippable_file ---

@test "is_skippable_file returns 0 for png" {
  run is_skippable_file "image.png"
  [ "$status" -eq 0 ]
}

@test "is_skippable_file returns 0 for lock file" {
  run is_skippable_file "package-lock.json.lock"
  [ "$status" -eq 0 ]
}

@test "is_skippable_file returns 0 for min.js" {
  run is_skippable_file "bundle.min.js"
  [ "$status" -eq 0 ]
}

@test "is_skippable_file returns 1 for js file" {
  run is_skippable_file "app.js"
  [ "$status" -eq 1 ]
}

@test "is_skippable_file returns 1 for sh file" {
  run is_skippable_file "script.sh"
  [ "$status" -eq 1 ]
}

# --- is_rebasing ---

@test "is_rebasing returns 1 when not rebasing" {
  init_test_repo
  echo "init" >README.md
  git add README.md
  git commit -q -m "init"

  run is_rebasing
  [ "$status" -eq 1 ]
}

@test "is_rebasing returns 0 when rebase-merge exists" {
  init_test_repo
  echo "init" >README.md
  git add README.md
  git commit -q -m "init"

  mkdir -p "$(git rev-parse --git-dir)/rebase-merge"
  run is_rebasing
  [ "$status" -eq 0 ]
}

@test "is_rebasing returns 0 when rebase-apply exists" {
  init_test_repo
  echo "init" >README.md
  git add README.md
  git commit -q -m "init"

  mkdir -p "$(git rev-parse --git-dir)/rebase-apply"
  run is_rebasing
  [ "$status" -eq 0 ]
}

# --- strip_pr_suffix ---

@test "strip_pr_suffix removes single-digit PR number suffix" {
  run strip_pr_suffix "fix(scope): some message (#1)"
  [ "$status" -eq 0 ]
  [ "$output" = "fix(scope): some message" ]
}

@test "strip_pr_suffix removes multi-digit PR number suffix" {
  run strip_pr_suffix "fix(scope): some message (#9999)"
  [ "$status" -eq 0 ]
  [ "$output" = "fix(scope): some message" ]
}

@test "strip_pr_suffix is a no-op when no suffix present" {
  run strip_pr_suffix "fix(scope): some message"
  [ "$status" -eq 0 ]
  [ "$output" = "fix(scope): some message" ]
}

@test "strip_pr_suffix does not strip PR reference in the middle of message" {
  run strip_pr_suffix "fix(scope): some (#42) message"
  [ "$status" -eq 0 ]
  [ "$output" = "fix(scope): some (#42) message" ]
}

# --- get_file_content ---

@test "get_file_content returns full file in all mode" {
  echo "line one" >"${TEST_TEMP_DIR}/test.txt"
  echo "line two" >>"${TEST_TEMP_DIR}/test.txt"

  run get_file_content "${TEST_TEMP_DIR}/test.txt" "all"
  [ "$status" -eq 0 ]
  [[ "$output" == *"line one"* ]]
  [[ "$output" == *"line two"* ]]
}

@test "get_file_content returns added lines in staged mode" {
  init_test_repo
  echo "original" >test.txt
  git add test.txt
  git commit -m "add test"

  echo "new line" >>test.txt
  git add test.txt

  run get_file_content "test.txt" "staged"
  [ "$status" -eq 0 ]
  [[ "$output" == *"+new line"* ]]
}
