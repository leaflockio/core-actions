#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  echo "init" >README.md
  git add README.md
  git commit -m "init"

  SCRIPT="${PROJECT_ROOT}/scripts/common/check-markdown-links.sh"
}

teardown() {
  _common_teardown
}

@test "passes when no markdown files staged" {
  echo "data" >file.txt
  git add file.txt

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No markdown files to check"* ]]
}

@test "passes with valid internal link" {
  echo "target content" >guide.md
  cat >docs.md <<'EOF'
See the [guide](guide.md) for details.
EOF
  git add docs.md guide.md

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Markdown link check passed"* ]]
}

@test "detects broken internal link" {
  cat >docs.md <<'EOF'
See the [guide](nonexistent.md) for details.
EOF
  git add docs.md

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Broken link"* ]]
}

@test "warns on broken external link" {
  create_mock curl 'echo "404"'
  cat >docs.md <<'EOF'
Check [example](https://broken.invalid/page) link.
EOF
  git add docs.md

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"External link may be broken"* ]]
}

@test "passes with reachable external link" {
  create_mock curl 'echo "200"'
  cat >docs.md <<'EOF'
Check [example](https://example.com) link.
EOF
  git add docs.md

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Markdown link check passed"* ]]
}

@test "skips pure anchor links" {
  cat >docs.md <<'EOF'
See the [section](#overview) below.
EOF
  git add docs.md

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}
