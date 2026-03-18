#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  echo "init" >README.md
  git add README.md
  git commit -m "init"

  SCRIPT="${PROJECT_ROOT}/scripts/shell/check-naming.sh"
}

teardown() {
  _common_teardown
}

@test "passes when no shell files staged" {
  echo "" >config.yml
  git add config.yml

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No shell files staged"* ]]
}

@test "passes with kebab-case file" {
  echo "" >check-branch.sh
  git add check-branch.sh

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Shell naming check passed"* ]]
}

@test "passes with single word file" {
  echo "" >setup.sh
  git add setup.sh

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "passes with dotted file" {
  echo "" >common-setup.bash.sh
  git add common-setup.bash.sh

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "fails with PascalCase file" {
  echo "" >CheckBranch.sh
  git add CheckBranch.sh

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid shell filename"* ]]
}

@test "fails with camelCase file" {
  echo "" >checkBranch.sh
  git add checkBranch.sh

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid shell filename"* ]]
}

@test "fails with snake_case file" {
  echo "" >check_branch.sh
  git add check_branch.sh

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid shell filename"* ]]
}

@test "shows fix hint on failure" {
  echo "" >Bad_Name.sh
  git add Bad_Name.sh

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"kebab-case"* ]]
}

@test "reports all invalid files" {
  echo "" >good-file.sh
  echo "" >Bad_File.sh
  echo "" >anotherBad.sh
  git add good-file.sh Bad_File.sh anotherBad.sh

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Bad_File.sh"* ]]
  [[ "$output" == *"anotherBad.sh"* ]]
}

@test "only checks staged shell files" {
  echo "" >staged.sh
  echo "" >BadUnstaged.sh
  git add staged.sh

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}
