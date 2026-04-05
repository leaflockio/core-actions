# .hooks-config Reference

Configuration file at the root of each consumer repo. Controls hook behavior for all lefthook scripts sourced from `core-actions`.

---

## Format

Plain key=value pairs, one per line. Comments start with `#`.

```text
KEY=value
# this is a comment
```

**JSON values** must use compact format (no spaces) and must not contain `=` characters. No quoting required.

```bash
COVERAGE_CONFIG_NODE={"floor":{"lines":80,"statements":80,"functions":75,"branches":70},"delta":2}
```

---

## General Settings

| Key                     | Default                | Description                                                           |
| ----------------------- | ---------------------- | --------------------------------------------------------------------- |
| `PARTIAL_STAGE`         | `fail`                 | Behavior when only some files in a diff are staged. `fail` or `warn`. |
| `UNCOMMITTED_PUSH`      | `fail`                 | Behavior when uncommitted changes exist on push. `fail` or `warn`.    |
| `MAX_FILE_SIZE`         | `1000000`              | Max file size in bytes before a commit is blocked.                    |
| `MAX_FILE_LINES`        | `2000`                 | Max lines in a single file.                                           |
| `MAX_COMMIT_LINES`      | `400`                  | Max total lines changed in a single commit.                           |
| `MAX_COMMIT_MSG_LENGTH` | `72`                   | Max character length of a commit message subject line.                |
| `PROTECTED_BRANCHES`    | `main master pre-main` | Space-separated list of branches that cannot be pushed to directly.   |
| `LINK_CHECK_TIMEOUT`    | `5`                    | Timeout in seconds for markdown link checks.                          |
| `CHECK_MODE`            | `staged`               | File scope for checks. `staged`, `all`, or `pr`.                      |

---

## Coverage Settings (Legacy)

These apply to shell, go, and python runners. Node uses `COVERAGE_CONFIG_NODE` instead.

| Key                 | Default         | Description                                                                    |
| ------------------- | --------------- | ------------------------------------------------------------------------------ |
| `COVERAGE_FLOOR`    | `95`            | Minimum coverage percentage. Fails if any run drops below this.                |
| `COVERAGE_MAX_DROP` | `0.05`          | Maximum allowed drop from baseline before failing.                             |
| `COVERAGE_SCRIPT`   | `test:coverage` | npm script to run for node coverage.                                           |
| `COVERAGE_TAG`      | _(empty)_       | Tag to look up in `.coverage-baseline`. Used when a repo has multiple runners. |
| `COVERAGE_DIR`      | `coverage`      | Directory where the coverage report is written.                                |
| `COVERAGE_SRC`      | `scripts`       | Source directory passed to kcov for shell coverage.                            |

---

## Per-Runner Coverage Config

Replaces the legacy `COVERAGE_FLOOR` / `COVERAGE_MAX_DROP` globals on a per-runner basis. Each key holds a JSON object with `floor` and `delta`.

| Key                      | Applies to                 |
| ------------------------ | -------------------------- |
| `COVERAGE_CONFIG_NODE`   | Node.js (per-metric floor) |
| `COVERAGE_CONFIG_SHELL`  | Shell / bats-core          |
| `COVERAGE_CONFIG_GO`     | Go                         |
| `COVERAGE_CONFIG_PYTHON` | Python                     |

### Node

Node coverage is checked per-metric (lines, statements, functions, branches). The `floor` is a JSON object with a threshold per metric.

```bash
COVERAGE_CONFIG_NODE={"floor":{"lines":80,"statements":80,"functions":75,"branches":70},"delta":2}
```

| Field   | Type        | Description                                                               |
| ------- | ----------- | ------------------------------------------------------------------------- |
| `floor` | JSON object | Per-metric minimum percentage. Fails if any metric drops below its floor. |
| `delta` | number      | Maximum allowed drop from baseline for any single metric.                 |

If `COVERAGE_CONFIG_NODE` is not set, the legacy `COVERAGE_FLOOR` and `COVERAGE_MAX_DROP` values are used and the same floor applies to all four metrics.

### Shell / Go / Python

For these runners, `floor` is a plain number that applies to the single overall coverage percentage.

```bash
COVERAGE_CONFIG_SHELL={"floor":70,"delta":5}
COVERAGE_CONFIG_GO={"floor":80,"delta":2}
COVERAGE_CONFIG_PYTHON={"floor":80,"delta":2}
```

---

## .coverage-baseline

Stores the reference coverage values used for delta checks.

### Legacy format (shell, go, python)

Plain number for untagged repos:

```bash
88.0
```

Tagged (multiple runners in one repo):

```bash
js: 88.0
shell: 72.0
```

### JSON format (node)

Each value is a compact JSON object with one entry per metric:

```bash
js: {"lines":88.0,"statements":87.2,"functions":91.0,"branches":82.5}
```

Untagged node repo:

```json
{ "lines": 88.0, "statements": 87.2, "functions": 91.0, "branches": 82.5 }
```

> **Migration:** If a node baseline entry is still a plain number, the delta check is skipped and a warning is logged. Update the entry to JSON format to re-enable per-metric delta checks.

---

## Example

```bash
PARTIAL_STAGE=fail
UNCOMMITTED_PUSH=fail
MAX_FILE_SIZE=1000000
MAX_FILE_LINES=2000
MAX_COMMIT_LINES=400
MAX_COMMIT_MSG_LENGTH=72
PROTECTED_BRANCHES=main master pre-main
LINK_CHECK_TIMEOUT=5
CHECK_MODE=staged
# Legacy floor used by shell runner
COVERAGE_FLOOR=70
COVERAGE_MAX_DROP=0.05
COVERAGE_SRC=scripts
# Per-runner config for node
COVERAGE_CONFIG_NODE={"floor":{"lines":80,"statements":80,"functions":75,"branches":70},"delta":2}
```
