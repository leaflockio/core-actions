#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  echo "init" >README.md
  git add README.md
  git commit -m "init"

  SCRIPT="${PROJECT_ROOT}/scripts/go/check-naming.sh"
}

teardown() {
  _common_teardown
}

@test "passes when no Go files staged" {
  echo "" >config.yml
  git add config.yml

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No Go files staged"* ]]
}

@test "passes with snake_case Go file" {
  echo "" >user_service.go
  git add user_service.go

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Go naming check passed"* ]]
}

@test "passes with snake_case test file" {
  echo "" >user_service_test.go
  git add user_service_test.go

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "passes with single word file" {
  echo "" >main.go
  git add main.go

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "passes with multiple valid files" {
  echo "" >main.go
  echo "" >db_conn.go
  echo "" >http_handler_test.go
  git add main.go db_conn.go http_handler_test.go

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "fails with PascalCase file" {
  echo "" >UserService.go
  git add UserService.go

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid Go filename"* ]]
  [[ "$output" == *"UserService.go"* ]]
}

@test "fails with camelCase file" {
  echo "" >userService.go
  git add userService.go

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid Go filename"* ]]
}

@test "fails with kebab-case file" {
  echo "" >user-service.go
  git add user-service.go

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid Go filename"* ]]
}

@test "fails with uppercase start" {
  echo "" >Main.go
  git add Main.go

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid Go filename"* ]]
}

@test "shows fix hint on failure" {
  echo "" >BadName.go
  git add BadName.go

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"snake_case"* ]]
}

@test "reports all invalid files" {
  echo "" >good_file.go
  echo "" >BadFile.go
  echo "" >another-bad.go
  git add good_file.go BadFile.go another-bad.go

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"BadFile.go"* ]]
  [[ "$output" == *"another-bad.go"* ]]
}

# --- Folder checks ---

@test "passes with lowercase folders" {
  mkdir -p internal/httputil
  echo "" >internal/httputil/client.go
  git add internal/httputil/client.go

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "passes with common Go folders" {
  mkdir -p cmd/server
  echo "" >cmd/server/main.go
  git add cmd/server/main.go

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "passes with testdata folder" {
  mkdir -p testdata
  echo "" >testdata/fixture.go
  git add testdata/fixture.go

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "skips hidden folders" {
  mkdir -p .build
  echo "" >.build/gen.go
  git add .build/gen.go

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "fails with PascalCase folder" {
  mkdir -p MyPackage
  echo "" >MyPackage/main.go
  git add MyPackage/main.go

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid Go folder name"* ]]
  [[ "$output" == *"MyPackage"* ]]
}

@test "fails with kebab-case folder" {
  mkdir -p my-package
  echo "" >my-package/main.go
  git add my-package/main.go

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid Go folder name"* ]]
}

@test "fails with snake_case folder" {
  mkdir -p my_package
  echo "" >my_package/main.go
  git add my_package/main.go

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid Go folder name"* ]]
}

@test "shows folder fix hint on failure" {
  mkdir -p Bad_Folder
  echo "" >Bad_Folder/main.go
  git add Bad_Folder/main.go

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"lowercase"* ]]
}

# --- Other ---

@test "only checks staged Go files" {
  echo "" >staged.go
  echo "" >BadUnstaged.go
  git add staged.go

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}
