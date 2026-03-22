# Shell Scripts

All shell scripts live under `scripts/`. This convention enables consistent linting, formatting, and source resolution.

---

## Directory Structure

```text
scripts/
  common/        # shared across all stacks (hooks, utilities, config)
  shell/         # shell-specific hooks (naming, coverage)
  node/          # node-specific hooks (naming, lint-staged, coverage)
  go/            # go-specific hooks (naming, format, lint, coverage)
  python/        # python-specific hooks (naming, format, lint, coverage)
  release/       # release scripts (back-merge)
```

---

## Sourcing

Scripts source shared utilities using `dirname`:

```bash
# Common scripts source config.sh (which loads utils.sh)
. "$(dirname "$0")/config.sh"

# Language-specific scripts source config.sh for CHECK_FILES
. "$(dirname "$0")/../common/config.sh"

# Language-specific scripts that only need logging source utils.sh
. "$(dirname "$0")/../common/utils.sh"
```

- **`config.sh`** — loads utils.sh, reads `.hooks-config` overrides, populates `CHECK_FILES` based on `CHECK_MODE` (staged/pr/all)
- **`utils.sh`** — logging (`log_info`, `log_error`, `log_success`, `log_warn`), `require_command`, `is_rebasing`, `is_protected_branch`, `is_skippable_file`, `get_file_content`, `get_remote_branch`

Scripts that need the file list (naming, format, lint checks) source `config.sh`. Coverage scripts also source `config.sh` for `COVERAGE_TAG`, `COVERAGE_SCRIPT`, and other coverage config values.

---

## Why `scripts/` Only

shellcheck uses `--source-path=SCRIPTDIR` to resolve sourced files relative to the script being analyzed. If a script lives outside `scripts/`, shellcheck cannot resolve its sources and reports SC1091 errors.

---

## Adding a Script

1. Place it under the appropriate `scripts/` subdirectory
2. Use `#!/usr/bin/env bash` as the shebang
3. Source `config.sh` (common) or `../common/config.sh` (language-specific) for file checks, or `../common/utils.sh` for logging only
4. It will automatically be picked up by shfmt and shellcheck via lefthook

---

## Script Outside `scripts/`

Avoid this. If unavoidable, update `package.json` lint/format commands and `lefthook/shell.yml` globs to include the new path. Add the path to shellcheck's `--source-path` if the script sources files from `scripts/common/`.
