# Testing

Shell scripts are tested with [bats-core](https://github.com/bats-core/bats-core). Tests mirror the `scripts/` directory structure.

---

## Directory Structure

```text
tests/
  test_helper/
    common-setup.bash   # shared setup, teardown, and helpers
  scripts/
    common/             # tests for scripts/common/*.sh
    shell/              # tests for scripts/shell/*.sh
    node/               # tests for scripts/node/*.sh
    go/                 # tests for scripts/go/*.sh
    python/             # tests for scripts/python/*.sh
    release/            # tests for scripts/release/*.sh
```

---

## Running Tests

```bash
npm run test                                       # all tests (parallel)
npx bats tests/scripts/common/check-paths.bats     # single file
```

---

## Test Helper

Every `.bats` file loads the shared helper:

```bash
setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo
}

teardown() {
  _common_teardown
}
```

- **`_common_setup`** — creates `TEST_TEMP_DIR`, sets `NO_COLOR=1`, sets `LEFTHOOK=0` (prevents hooks in test repos), prepends `TEST_BIN_DIR` to `PATH`
- **`_common_teardown`** — removes `TEST_TEMP_DIR`
- **`init_test_repo`** — initializes a git repo inside `TEST_TEMP_DIR` with signing disabled

Scripts that don't interact with git state (e.g. `go/check-lint.sh` which runs `golangci-lint` on the whole module) skip `init_test_repo`.

---

## Mocking Commands

Use `create_mock` to shadow commands during a test:

```bash
create_mock prettier "echo 'mocked'"
create_mock golangci-lint "exit 0"
```

Mocks are placed in `TEST_BIN_DIR` which is prepended to `PATH`. For git mocks that need to pass most commands through:

```bash
create_mock git "
  REAL_GIT=\$(PATH=\"\${PATH#*:}\" command -v git)
  if [ \"\$1\" = \"log\" ]; then
    echo 'mocked output'
    exit 0
  fi
  exec \"\$REAL_GIT\" \"\$@\"
"
```

---

## Writing a New Test

1. Create `tests/scripts/<stack>/<script-name>.bats`
2. Load the helper and call `init_test_repo` in `setup()` (if the script uses git)
3. Set `SCRIPT="${PROJECT_ROOT}/scripts/<stack>/<script-name>.sh"`
4. Stage files with `git add` to simulate hook conditions
5. Assert on `$status` (exit code) and `$output` (stdout + stderr)
