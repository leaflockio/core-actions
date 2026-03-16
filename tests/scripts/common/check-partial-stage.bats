#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  echo "init" > README.md
  git add README.md
  git commit -m "init"

  SCRIPT="${PROJECT_ROOT}/scripts/common/check-partial-stage.sh"
}

teardown() {
  _common_teardown
}

@test "exits 0 when no patch file exists" {
  run sh "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "exits 0 when patch file is empty" {
  mkdir -p "$(git rev-parse --git-dir)/info"
  touch "$(git rev-parse --git-dir)/info/lefthook-unstaged.patch"

  run sh "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "exits 0 when patch has files not in staging" {
  mkdir -p "$(git rev-parse --git-dir)/info"
  cat > "$(git rev-parse --git-dir)/info/lefthook-unstaged.patch" <<'EOF'
diff --git a/untracked.txt b/untracked.txt
--- a/untracked.txt
+++ b/untracked.txt
@@ -1 +1 @@
-old
+new
EOF

  run sh "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "blocks when staged file also has unstaged changes" {
  echo "original" > app.js
  git add app.js

  mkdir -p "$(git rev-parse --git-dir)/info"
  cat > "$(git rev-parse --git-dir)/info/lefthook-unstaged.patch" <<'EOF'
diff --git a/app.js b/app.js
--- a/app.js
+++ b/app.js
@@ -1 +1 @@
-original
+modified
EOF

  run sh "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"modified after staging"* ]]
}
