# Coverage

## How It Works

1. Each stack coverage script (`scripts/shell/coverage.sh`, `scripts/node/coverage.sh`) runs tests and extracts a coverage percentage
2. The percentage is passed to `scripts/common/check-coverage.sh` along with an optional tag
3. `check-coverage.sh` enforces the floor threshold and delta regression check against `.coverage-baseline`

---

## Configuration

Set in `.hooks-config` at repo root:

| Key                 | Default          | Description                                        |
| ------------------- | ---------------- | -------------------------------------------------- |
| `COVERAGE_SRC`      | `scripts`        | Space-separated directories to include in coverage |
| `COVERAGE_FLOOR`    | `95`             | Minimum coverage percentage                        |
| `COVERAGE_MAX_DROP` | `0.05`           | Maximum allowed drop from baseline                 |
| `COVERAGE_SCRIPT`   | `test:coverage`  | npm script for node coverage                       |
| `COVERAGE_TAG`      | _(empty)_        | Tag for baseline lookup (empty = legacy mode)      |

These can also be set as environment variables (e.g., in lefthook job `env` blocks) which take precedence over `.hooks-config`.

---

## Baseline

`.coverage-baseline` supports two formats:

### Tagged format (multi-domain)

For repos with multiple coverage domains (e.g., shell + JS):

```
# Coverage baselines
shell: 78.82
js: 94.11
```

- Each line is `tag: percent`
- Tags are arbitrary strings (e.g., `shell`, `js`, `api`, `worker`)
- Lines starting with `#` are comments, blank lines are ignored
- Pass the tag to `check-coverage.sh`: `bash check-coverage.sh 88.07 shell`

### Legacy format (single number)

For repos with a single coverage domain:

```
78.82
```

- When no tag is passed to `check-coverage.sh`, the first non-comment, non-blank line is used as the baseline
- No baseline file or empty file: delta check is skipped, only floor is enforced

### Updating the baseline

```bash
# Shell coverage
npm run test:sh:coverage:local   # note the percentage
# Update the shell tag in .coverage-baseline

# JS coverage
npm run test:js:coverage         # note the percentage
# Update the js tag in .coverage-baseline
```

---

## Lefthook Integration

Coverage runs on pre-push via stack-specific lefthook configs:

```yaml
# lefthook/shell.yml
- name: shell-coverage
  run: bash scripts/shell/coverage.sh --docker

# lefthook/node.yml
- name: node-coverage
  run: bash scripts/node/coverage.sh
```

For repos with multiple domains, override jobs in `lefthook.yml` with per-job env:

```yaml
pre-push:
  jobs:
    - name: shell-coverage
      env:
        COVERAGE_TAG: shell
      run: bash scripts/shell/coverage.sh --docker
    - name: node-coverage
      env:
        COVERAGE_TAG: js
        COVERAGE_SCRIPT: test:js:coverage
      run: bash scripts/node/coverage.sh
```

The `--docker` flag runs kcov inside a Docker container (required locally since kcov is Linux-only). Each script calls `check-coverage.sh` internally.

### Multiple services on the same stack

If a repo has multiple Node services (e.g., `api` and `worker`), each needing its own coverage baseline, override the single `node-coverage` job with multiple jobs in the consumer's `lefthook.yml`:

```yaml
remotes:
  - git_url: https://github.com/leaflockio/core-actions
    ref: v1
    configs:
      - lefthook/common.yml
      - lefthook/node.yml

pre-push:
  jobs:
    - name: api-coverage
      env:
        COVERAGE_TAG: api
        COVERAGE_SCRIPT: test:api:coverage
      run: bash scripts/node/coverage.sh
    - name: worker-coverage
      env:
        COVERAGE_TAG: worker
        COVERAGE_SCRIPT: test:worker:coverage
      run: bash scripts/node/coverage.sh
```

With matching baselines:

```
# .coverage-baseline
api: 85.0
worker: 92.0
```

Each job runs a different npm script and checks against its own tagged baseline. The test tool config (vitest, jest, etc.) controls where reports are written — the coverage script doesn't manage that.
