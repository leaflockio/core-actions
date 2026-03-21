# Coverage

Shell script coverage uses [kcov](https://github.com/SimonKagstrom/kcov) to instrument bats test runs. The coverage script lives at `scripts/shell/coverage.sh`.

---

## Running Coverage

```bash
npm run test:coverage:local    # local (Docker, required on macOS)
npm run test:coverage          # CI (native kcov, Linux only)
```

---

## How It Works

1. kcov wraps bats, tracing which script lines execute during tests
2. Untested scripts appear at 0% (via `--bash-parse-files-in-dir`)
3. `coverage.sh` extracts the percentage from kcov output and calls `check-coverage.sh`
4. `check-coverage.sh` enforces floor threshold and delta regression check

---

## Configuration

Set in `.hooks-config` at repo root:

| Key                 | Default   | Description                                        |
| ------------------- | --------- | -------------------------------------------------- |
| `COVERAGE_SRC`      | `scripts` | Space-separated directories to include in coverage |
| `COVERAGE_FLOOR`    | `95`      | Minimum coverage percentage                        |
| `COVERAGE_MAX_DROP` | `0.05`    | Maximum allowed drop from baseline                 |

---

## Baseline

`.coverage-baseline` is a committed file containing the previous coverage percentage (single number, e.g. `78.84`). Updated manually after running coverage locally or in CI.

To update:

```bash
npm run test:coverage:local   # note the percentage
echo "78.84" > .coverage-baseline
```

- No baseline file: delta check is skipped, only floor is enforced
- Empty baseline file: same behavior

---

## Lefthook Integration

Coverage runs on pre-push via `lefthook/shell.yml`:

```yaml
- name: coverage
  run: bash scripts/shell/coverage.sh --docker
```

The `--docker` flag runs kcov inside a Docker container (required locally since kcov is Linux-only). The script calls `check-coverage.sh` internally.
