#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  echo "init" >README.md
  git add README.md
  git commit -m "init"

  SCRIPT="${PROJECT_ROOT}/scripts/common/check-naming.sh"
}

teardown() {
  _common_teardown
}

# --- No staged files ---

@test "passes when no files staged" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No files staged"* ]]
}

# --- Kebab-case files ---

@test "passes with kebab-case files" {
  echo "" >my-config.yml
  echo "" >setup-data.json
  echo "" >hello-world.md
  git add my-config.yml setup-data.json hello-world.md

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Naming check passed"* ]]
}

@test "passes with dotted kebab-case files" {
  echo "" >my-app.config.yml
  echo "" >data.backup.json
  git add my-app.config.yml data.backup.json

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

# --- UPPER_SNAKE_CASE docs ---

@test "passes with UPPER_SNAKE_CASE markdown" {
  echo "" >CHANGELOG.md
  echo "" >CONTRIBUTING.md
  git add CHANGELOG.md CONTRIBUTING.md

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "passes with UPPER_SNAKE_CASE txt" {
  echo "" >NOTICE.txt
  git add NOTICE.txt

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

# --- No-extension uppercase files ---

@test "passes with LICENSE" {
  echo "" >LICENSE
  git add LICENSE

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "passes with CODEOWNERS" {
  echo "" >CODEOWNERS
  git add CODEOWNERS

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

# --- Known exceptions ---

@test "passes with Dockerfile" {
  echo "" >Dockerfile
  git add Dockerfile

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "passes with Makefile" {
  echo "" >Makefile
  git add Makefile

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "passes with Procfile" {
  echo "" >Procfile
  git add Procfile

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

# --- Dotfiles ---

@test "skips dotfiles" {
  echo "" >.env
  echo "" >.gitignore
  git add .env .gitignore

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

# --- Language-specific files skipped ---

@test "skips JS/TS files" {
  echo "" >MyComponent.tsx
  echo "" >useTheme.ts
  git add MyComponent.tsx useTheme.ts

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "skips Go files" {
  echo "" >UserService.go
  git add UserService.go

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "skips Python files" {
  echo "" >UserService.py
  git add UserService.py

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "skips shell files" {
  echo "" >My_Script.sh
  git add My_Script.sh

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

# --- Invalid filenames ---

@test "fails on PascalCase non-language file" {
  echo "" >MyConfig.yml
  git add MyConfig.yml

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid filename"* ]]
}

@test "fails on camelCase non-language file" {
  echo "" >myConfig.json
  git add myConfig.json

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid filename"* ]]
}

@test "fails on spaces in filename" {
  echo "" >"my file.md"
  git add "my file.md"

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Filename contains spaces"* ]]
}

@test "fails on UPPER_SNAKE_CASE with wrong extension" {
  echo "" >MY_CONFIG.yml
  git add MY_CONFIG.yml

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid filename"* ]]
}

# --- Folder checks ---

@test "fails on folder with spaces" {
  mkdir -p "my folder"
  echo "" >"my folder/config.yml"
  git add "my folder/config.yml"

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Folder name contains spaces"* ]]
}

@test "passes with kebab-case folders" {
  mkdir -p my-folder/sub-folder
  echo "" >my-folder/sub-folder/config.yml
  git add my-folder/sub-folder/config.yml

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

# --- .github/ excluded ---

@test "skips .github directory files" {
  mkdir -p .github/workflows
  echo "" >.github/workflows/MyWorkflow.yml
  git add .github/workflows/MyWorkflow.yml

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

# --- Mixed valid and invalid ---

@test "reports all invalid files" {
  echo "" >good-file.yml
  echo "" >BadFile.json
  echo "" >"has space.md"
  git add good-file.yml BadFile.json "has space.md"

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"BadFile.json"* ]]
  [[ "$output" == *"has space.md"* ]]
}
