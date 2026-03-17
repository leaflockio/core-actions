#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  echo "init" >README.md
  git add README.md
  git commit -m "init"

  SCRIPT="${PROJECT_ROOT}/scripts/common/check-paths.sh"
}

teardown() {
  _common_teardown
}

@test "passes when no files to check" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "passes with relative paths" {
  cat >app.js <<'EOF'
const config = require("./config");
const data = require("../shared/data");
EOF
  git add app.js

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Path check passed"* ]]
}

@test "detects hardcoded UNIX absolute path" {
  # Build path dynamically to avoid triggering the hook on this file
  printf 'const dir = "%s";\n' "/Us""ers/john/projects/app" >app.js
  git add app.js

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Hardcoded UNIX path"* ]]
}

@test "detects hardcoded Windows absolute path" {
  # Build path dynamically to avoid triggering the hook on this file
  local winpath='C:'"\\Us"'ers'"\\j"'ohn'"\\p"'rojects'
  printf 'const dir = "%s";\n' "$winpath" >app.js
  git add app.js

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Hardcoded Windows path"* ]]
}

@test "skips URLs" {
  cat >app.js <<'EOF'
const url = "https://example.com/api/data";
EOF
  git add app.js

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "skips binary files" {
  echo "binary" >image.png
  git add image.png

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}
