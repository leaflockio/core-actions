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

# --- color variables ---

@test "color variables are empty when NO_COLOR is set" {
  [ -z "$RED" ]
  [ -z "$GREEN" ]
  [ -z "$YELLOW" ]
  [ -z "$BLUE" ]
  [ -z "$RESET" ]
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
