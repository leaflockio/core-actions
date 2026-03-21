#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  echo "init" >README.md
  git add README.md
  git commit -m "init"

  SCRIPT="${PROJECT_ROOT}/scripts/common/check-todo.sh"
}

teardown() {
  _common_teardown
}

@test "passes when no files to check" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "passes with TODO that has ticket reference" {
  cat >app.js <<'EOF'
// TODO(#123) implement caching
// FIXME(#456) handle edge case
EOF
  git add app.js

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"TODO check passed"* ]]
}

@test "blocks bare TODO without ticket" {
  # Build marker dynamically to avoid triggering the hook on this file
  local marker="TO""DO"
  printf '// %s fix this later\n' "$marker" >app.js
  git add app.js

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Bare TODO/FIXME without ticket"* ]]
}

@test "blocks bare FIXME without ticket" {
  local marker="FIX""ME"
  printf '// %s broken on edge case\n' "$marker" >app.js
  git add app.js

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Bare TODO/FIXME without ticket"* ]]
}

@test "passes with PROJ-style ticket reference" {
  cat >app.js <<'EOF'
// TODO(PROJ-789) migrate to new API
EOF
  git add app.js

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"TODO check passed"* ]]
}

@test "blocks TODO with bare number" {
  local marker="TO""DO"
  printf '// %s(123) missing hash prefix\n' "$marker" >app.js
  git add app.js

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Bare TODO/FIXME without ticket"* ]]
}

@test "skips TODO inside quoted strings" {
  local marker="TO""DO"
  printf "const msg = '%s: not a real marker'\n" "$marker" >app.js
  git add app.js

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "skips TODO as part of variable name" {
  local marker="TO""DO"
  printf '%s_LIST="items"\n' "$marker" >app.sh
  git add app.sh

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "blocks bare TODO in all mode" {
  local marker="TO""DO"
  printf '// %s fix later\n' "$marker" >app.js
  git add app.js
  git commit -m "add file"

  echo "CHECK_MODE=all" >.hooks-config

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Bare TODO/FIXME without ticket"* ]]
}

@test "prints line without number when grep cannot match" {
  local marker="TO""DO"
  # Stage a file with the marker
  printf '// %s fix this\n' "$marker" >app.js
  git add app.js
  # Overwrite the file so the staged content no longer matches the working copy
  echo "completely different content" >app.js

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  # Should show the line without a line number prefix
  [[ "$output" == *"fix this"* ]]
}

@test "skips binary and generated files" {
  local marker="TO""DO"
  printf '%s no ticket\n' "$marker" >image.png
  printf '%s no ticket\n' "$marker" >deps.lock
  git add image.png deps.lock

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}
