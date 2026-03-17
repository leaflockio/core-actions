#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  # Initial commit on main
  echo "init" >README.md
  git add README.md
  git commit -m "init"

  # Create bare remote
  git clone --bare "${TEST_TEMP_DIR}/repo" "${TEST_TEMP_DIR}/remote.git" 2>/dev/null
  git remote add origin "${TEST_TEMP_DIR}/remote.git"
  git push -u origin main 2>/dev/null

  # Create pre-main branch and push it
  git checkout -b pre-main
  git push -u origin pre-main 2>/dev/null

  # Go back to main
  git checkout main

  # Set env vars the script expects
  export GITHUB_TOKEN="fake-token"
  export GITHUB_REPOSITORY="leaflockio/core-actions"

  SCRIPT="${PROJECT_ROOT}/scripts/release/back-merge.sh"

  # Override git remote set-url to use our local remote instead of GitHub URL
  create_mock_git_wrapper
}

teardown() {
  _common_teardown
}

# Creates a git wrapper that intercepts "remote set-url" to keep the local
# remote path, but passes everything else through to real git.
create_mock_git_wrapper() {
  REAL_GIT="$(which git)"
  export REAL_GIT

  cat >"${TEST_BIN_DIR}/git" <<'WRAPPER'
#!/bin/sh
if [ "$1" = "remote" ] && [ "$2" = "set-url" ]; then
  exit 0
fi
exec "$REAL_GIT" "$@"
WRAPPER
  chmod +x "${TEST_BIN_DIR}/git"
}

@test "back-merges main into pre-main on clean merge" {
  # Add a commit to main that pre-main doesn't have
  echo "release v1.0.0" >VERSION
  git add VERSION
  git commit -m "chore: release v1.0.0"
  git push origin main 2>/dev/null

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Back-merge complete"* ]]

  # Verify pre-main has the commit
  git checkout pre-main
  [ -f VERSION ]
  [ "$(cat VERSION)" = "release v1.0.0" ]
}

@test "creates a merge commit not a fast-forward" {
  echo "release v1.0.0" >VERSION
  git add VERSION
  git commit -m "chore: release v1.0.0"
  git push origin main 2>/dev/null

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]

  # Check merge commit message on pre-main
  git checkout pre-main
  LAST_MSG=$(git log -1 --pretty=%s)
  [[ "$LAST_MSG" == *"back-merge main into pre-main"* ]]
}

@test "merge commit includes skip ci tag" {
  echo "release v1.0.0" >VERSION
  git add VERSION
  git commit -m "chore: release v1.0.0"
  git push origin main 2>/dev/null

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]

  git checkout pre-main
  LAST_MSG=$(git log -1 --pretty=%s)
  [[ "$LAST_MSG" == *"[skip ci]"* ]]
}

@test "pushes merged pre-main to remote" {
  echo "release v1.0.0" >VERSION
  git add VERSION
  git commit -m "chore: release v1.0.0"
  git push origin main 2>/dev/null

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]

  # Verify remote pre-main has the VERSION file
  VERIFY_DIR=$(mktemp -d)
  git clone --branch pre-main "${TEST_TEMP_DIR}/remote.git" "$VERIFY_DIR" 2>/dev/null
  [ -f "$VERIFY_DIR/VERSION" ]
}

@test "fails with conflict instructions when merge conflicts" {
  # Create diverging changes on both branches
  echo "main content" >CONFLICT.txt
  git add CONFLICT.txt
  git commit -m "chore: add on main"
  git push origin main 2>/dev/null

  git checkout pre-main
  echo "pre-main content" >CONFLICT.txt
  git add CONFLICT.txt
  git commit -m "chore: add on pre-main"
  git push origin pre-main 2>/dev/null

  git checkout main

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Back-merge conflict detected"* ]]
  [[ "$output" == *"Manual resolution required"* ]]
}

@test "succeeds when main and pre-main are already in sync" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Back-merge complete"* ]]
}

@test "preserves existing pre-main commits after merge" {
  # Add a commit to pre-main
  git checkout pre-main
  echo "feature work" >FEATURE.txt
  git add FEATURE.txt
  git commit -m "feat: add feature"
  git push origin pre-main 2>/dev/null

  # Add a different commit to main
  git checkout main
  echo "release v1.0.0" >VERSION
  git add VERSION
  git commit -m "chore: release v1.0.0"
  git push origin main 2>/dev/null

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]

  # Verify both files exist on pre-main
  git checkout pre-main
  [ -f FEATURE.txt ]
  [ -f VERSION ]
}
