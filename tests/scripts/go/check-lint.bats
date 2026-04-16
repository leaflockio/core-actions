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

@test "lints root package for root-level Go file" {
  create_mock "golangci-lint" 'echo "called: $*"; exit 0'

  cat >main.go <<'EOF'
package main
EOF
  git add main.go

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"called: run ."* ]]
}

@test "lints correct package for subdirectory Go file" {
  create_mock "golangci-lint" 'echo "called: $*"; exit 0'

  mkdir -p cmd
  cat >cmd/main.go <<'EOF'
package main
EOF
  git add cmd/main.go

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"./cmd"* ]]
}

@test "deduplicates packages when multiple files in same directory are staged" {
  create_mock "golangci-lint" 'echo "called: $*"; exit 0'

  mkdir -p internal/foo
  cat >internal/foo/a.go <<'EOF'
package foo
EOF
  cat >internal/foo/b.go <<'EOF'
package foo
EOF
  git add internal/foo/a.go internal/foo/b.go

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  # ./internal/foo should appear exactly once
  count=$(echo "$output" | grep -o '\./internal/foo' | wc -l)
  [ "$count" -eq 1 ]
}

@test "lints multiple packages when files from different directories are staged" {
  create_mock "golangci-lint" 'echo "called: $*"; exit 0'

  mkdir -p cmd internal/foo
  cat >cmd/main.go <<'EOF'
package main
EOF
  cat >internal/foo/bar.go <<'EOF'
package foo
EOF
  git add cmd/main.go internal/foo/bar.go

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"./cmd"* ]]
  [[ "$output" == *"./internal/foo"* ]]
}

@test "does not lint unstaged Go files" {
  create_mock "golangci-lint" 'echo "called: $*"; exit 0'

  cat >staged.go <<'EOF'
package main
EOF
  cat >unstaged.go <<'EOF'
package main
EOF
  git add staged.go

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" != *"unstaged"* ]]
}

@test "lints all packages in CHECK_MODE=all" {
  create_mock "golangci-lint" 'echo "called: $*"; exit 0'

  mkdir -p cmd
  cat >main.go <<'EOF'
package main
EOF
  cat >cmd/run.go <<'EOF'
package cmd
EOF
  git add main.go cmd/run.go
  git commit -m "add go files"

  CHECK_MODE=all run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"."* ]]
  [[ "$output" == *"./cmd"* ]]
}
