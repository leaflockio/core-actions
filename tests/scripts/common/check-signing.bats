#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  echo "init" >README.md
  git add README.md
  git commit -m "init"

  SCRIPT="${PROJECT_ROOT}/scripts/common/check-signing.sh"
}

teardown() {
  _common_teardown
}

@test "fails when commit is not signed" {
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"is not signed"* ]]
}

@test "passes when commit has good GPG signature" {
  create_mock git "
    REAL_GIT=\$(PATH=\"\${PATH#*:}\" command -v git)
    if [ \"\$1\" = \"log\" ] && [ \"\$2\" = \"--show-signature\" ]; then
      echo 'gpg: Good signature from \"User <user@example.com>\"'
      exit 0
    fi
    exec \"\$REAL_GIT\" \"\$@\"
  "
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"is signed"* ]]
}

@test "passes when commit has gitsign signature" {
  create_mock git "
    REAL_GIT=\$(PATH=\"\${PATH#*:}\" command -v git)
    if [ \"\$1\" = \"log\" ] && [ \"\$2\" = \"--show-signature\" ]; then
      echo 'gitsign: Good signature from \"User\"'
      exit 0
    fi
    exec \"\$REAL_GIT\" \"\$@\"
  "
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"is signed"* ]]
}

@test "passes with warning when key not in local keyring" {
  create_mock git "
    REAL_GIT=\$(PATH=\"\${PATH#*:}\" command -v git)
    if [ \"\$1\" = \"log\" ] && [ \"\$2\" = \"--show-signature\" ]; then
      echo 'gpg: Signature made Thu 01 Jan 2026 12:00:00 AM UTC'
      exit 0
    fi
    exec \"\$REAL_GIT\" \"\$@\"
  "
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"key not in local keyring"* ]]
}

@test "uses PR_BASE_SHA when set" {
  BASE_SHA=$(git rev-parse HEAD)

  echo "change" >file.txt
  git add file.txt
  git commit -m "feat: pr commit"

  run env PR_BASE_SHA="$BASE_SHA" bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"is not signed"* ]]
}

@test "checks commits against remote when remote exists" {
  git remote add origin "${TEST_TEMP_DIR}/repo"
  git fetch origin

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"is not signed"* ]]
}
