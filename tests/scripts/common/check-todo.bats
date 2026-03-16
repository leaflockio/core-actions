#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  echo "init" > README.md
  git add README.md
  git commit -m "init"

  SCRIPT="${PROJECT_ROOT}/scripts/common/check-todo.sh"
}

teardown() {
  _common_teardown
}

@test "passes when no files to check" {
  run sh "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "passes with TODO that has ticket reference" {
  cat > app.js <<'EOF'
// TODO(#123) implement caching
// FIXME(#456) handle edge case
EOF
  git add app.js

  run sh "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"TODO check passed"* ]]
}

@test "blocks bare TODO without ticket" {
  # Build marker dynamically to avoid triggering the hook on this file
  local marker="TO""DO"
  printf '// %s fix this later\n' "$marker" > app.js
  git add app.js

  run sh "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Bare TODO/FIXME without ticket"* ]]
}

@test "blocks bare FIXME without ticket" {
  local marker="FIX""ME"
  printf '// %s broken on edge case\n' "$marker" > app.js
  git add app.js

  run sh "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Bare TODO/FIXME without ticket"* ]]
}

@test "skips binary and generated files" {
  local marker="TO""DO"
  printf '%s no ticket\n' "$marker" > image.png
  printf '%s no ticket\n' "$marker" > deps.lock
  git add image.png deps.lock

  run sh "$SCRIPT"
  [ "$status" -eq 0 ]
}
