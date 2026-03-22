#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  echo "init" >README.md
  git add README.md
  git commit -m "init"

  SCRIPT="${PROJECT_ROOT}/scripts/python/check-naming.sh"
}

teardown() {
  _common_teardown
}

@test "passes when no Python files to check" {
  echo "" >config.yml
  git add config.yml

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No Python files to check"* ]]
}

@test "passes with snake_case file" {
  echo "" >user_service.py
  git add user_service.py

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Python naming check passed"* ]]
}

@test "passes with single word file" {
  echo "" >main.py
  git add main.py

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "passes with __init__.py" {
  echo "" >__init__.py
  git add __init__.py

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "passes with __main__.py" {
  echo "" >__main__.py
  git add __main__.py

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "fails with PascalCase file" {
  echo "" >UserService.py
  git add UserService.py

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid Python filename"* ]]
}

@test "fails with camelCase file" {
  echo "" >userService.py
  git add userService.py

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid Python filename"* ]]
}

@test "fails with kebab-case file" {
  echo "" >user-service.py
  git add user-service.py

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid Python filename"* ]]
}

@test "shows fix hint on failure" {
  echo "" >BadName.py
  git add BadName.py

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"snake_case"* ]]
}

@test "reports all invalid files" {
  echo "" >good_file.py
  echo "" >BadFile.py
  echo "" >another-bad.py
  git add good_file.py BadFile.py another-bad.py

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"BadFile.py"* ]]
  [[ "$output" == *"another-bad.py"* ]]
}

# --- Folder checks ---

@test "passes with snake_case folders" {
  mkdir -p my_package/sub_module
  echo "" >my_package/sub_module/main.py
  git add my_package/sub_module/main.py

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "passes with single word folders" {
  mkdir -p utils
  echo "" >utils/helpers.py
  git add utils/helpers.py

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "skips hidden folders" {
  mkdir -p .venv
  echo "" >.venv/config.py
  git add .venv/config.py

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "skips double-underscore directories" {
  mkdir -p __pycache__
  echo "" >__pycache__/module.py
  git add __pycache__/module.py

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "fails with PascalCase folder" {
  mkdir -p MyPackage
  echo "" >MyPackage/main.py
  git add MyPackage/main.py

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid Python folder name"* ]]
}

@test "fails with kebab-case folder" {
  mkdir -p my-package
  echo "" >my-package/main.py
  git add my-package/main.py

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid Python folder name"* ]]
}

@test "only checks staged Python files" {
  echo "" >staged.py
  echo "" >BadUnstaged.py
  git add staged.py

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}
