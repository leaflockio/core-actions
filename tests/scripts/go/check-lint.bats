#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  echo "init" >README.md
  git add README.md
  git commit -m "init"

  SCRIPT="${PROJECT_ROOT}/scripts/go/check-lint.sh"
}

teardown() {
  _common_teardown
}

@test "passes silently when no Go files are staged" {
  echo "" >config.yml
  git add config.yml

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No Go files to lint"* ]]
}

@test "passes when golangci-lint succeeds" {
  create_mock "golangci-lint" 'exit 0'

  cat >main.go <<'EOF'
package main
EOF
  git add main.go

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Go lint check passed"* ]]
}

@test "fails when golangci-lint fails" {
  create_mock "golangci-lint" 'exit 1'

  cat >main.go <<'EOF'
package main
EOF
  git add main.go

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Go lint check failed"* ]]
}

@test "passes --new-from-patch flag to golangci-lint" {
  create_mock "golangci-lint" 'echo "args: $*"; exit 0'

  cat >main.go <<'EOF'
package main
EOF
  git add main.go

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"--new-from-patch"* ]]
}

@test "passes ./... as lint target to golangci-lint" {
  create_mock "golangci-lint" 'echo "args: $*"; exit 0'

  cat >main.go <<'EOF'
package main
EOF
  git add main.go

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"./..."* ]]
}

@test "patch contains only staged Go files" {
  create_mock "golangci-lint" 'cat "$3"; exit 0'

  cat >staged.go <<'EOF'
package main
EOF
  cat >unstaged.go <<'EOF'
package main
EOF
  git add staged.go

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"staged.go"* ]]
  [[ "$output" != *"unstaged.go"* ]]
}

@test "cleans up patch file after success" {
  create_mock "golangci-lint" 'echo "PATCH_PATH=$3"; exit 0'

  cat >main.go <<'EOF'
package main
EOF
  git add main.go

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  patch_path=$(echo "$output" | grep "PATCH_PATH=" | sed 's/PATCH_PATH=//')
  [ ! -f "$patch_path" ]
}

@test "cleans up patch file after failure" {
  create_mock "golangci-lint" 'echo "PATCH_PATH=$3"; exit 1'

  cat >main.go <<'EOF'
package main
EOF
  git add main.go

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  patch_path=$(echo "$output" | grep "PATCH_PATH=" | sed 's/PATCH_PATH=//')
  [ ! -f "$patch_path" ]
}
