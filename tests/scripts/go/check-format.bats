#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  echo "init" >README.md
  git add README.md
  git commit -m "init"

  SCRIPT="${PROJECT_ROOT}/scripts/go/check-format.sh"
}

teardown() {
  _common_teardown
}

@test "passes when no Go files to check" {
  echo "" >config.yml
  git add config.yml

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No Go files to check"* ]]
}

@test "passes with formatted Go file" {
  create_mock "gofmt" 'echo ""'

  cat >main.go <<'EOF'
package main

func main() {
}
EOF
  git add main.go

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Go format check passed"* ]]
}

@test "fails with unformatted Go file" {
  create_mock "gofmt" 'for f in "$@"; do echo "$f"; done'

  cat >main.go <<'EOF'
package main

func main() {
}
EOF
  git add main.go

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unformatted Go files detected"* ]]
  [[ "$output" == *"main.go"* ]]
}

@test "only checks staged Go files" {
  create_mock "gofmt" 'echo ""'

  cat >staged.go <<'EOF'
package main
EOF
  cat >unstaged.go <<'EOF'
package main
EOF
  git add staged.go

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "shows fix hint on failure" {
  create_mock "gofmt" 'for f in "$@"; do echo "$f"; done'

  cat >bad.go <<'EOF'
package main
EOF
  git add bad.go

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"gofmt -w"* ]]
}
