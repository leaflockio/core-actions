# Lefthook Configs

This repo provides lefthook hook configurations that consumer repos pull via remotes. Configs live in `lefthook/`.

---

## Available Configs

| Config       | Stack         | What it adds                                                                   |
| ------------ | ------------- | ------------------------------------------------------------------------------ |
| `common.yml` | All repos     | Branch checks, naming, secrets, formatting, spelling, license headers, signing |
| `shell.yml`  | Shell         | kebab-case naming, shfmt, shellcheck, kcov coverage                            |
| `node.yml`   | Node/TS/React | PascalCase/camelCase naming, test coverage                                     |
| `go.yml`     | Go            | snake_case naming, gofmt, golangci-lint, test coverage                         |
| `python.yml` | Python        | snake_case naming, ruff format, ruff check, pytest coverage                    |

Every language config must be used alongside `common.yml`.

---

## Consumer Repo Setup

Add to your `lefthook.yml`:

```yaml
remotes:
  - git_url: https://github.com/leaflockio/core-actions
    ref: v1
    configs:
      - lefthook/common.yml
      - lefthook/node.yml # swap for your stack
```

Then run:

```bash
lefthook install   # first-time setup
lefthook install   # re-run after changing lefthook.yml or updating remote ref
```

To pull the latest hooks from core-actions, bump the `ref` in your `lefthook.yml` (e.g. `v1` → `v2`) and re-run `lefthook install`.

---

## How Configs Are Structured

### common.yml

Common checks are wrapped in a piped group so `check-partial-stage` blocks quality gates, but stack checks from extended configs run concurrently at the hook level (no broken pipe):

```yaml
pre-commit:
  jobs:
    - name: common-checks
      group:
        piped: true
        jobs:
          - name: check-partial-stage
            run: bash scripts/common/check-partial-stage.sh
            interactive: true
          - name: quality-gates
            group:
              parallel: true
              jobs:
                - name: check-branch
                  run: bash scripts/common/check-branch.sh
                # ... more checks
```

Pre-push uses the same pattern (`common-push-checks` piped group).

### Stack configs

Stack configs add their checks as top-level jobs. Without `piped: true` at the hook level, they run concurrently with `common-checks`:

```yaml
pre-commit:
  jobs:
    - name: <stack>-checks
      group:
        parallel: true
        jobs:
          - name: check-naming
            run: bash scripts/<stack>/check-naming.sh

pre-push:
  jobs:
    - name: <stack>-coverage
      run: bash scripts/<stack>/coverage.sh
```

- **`group: piped: true`** (common.yml) — sequential within the group, stops on failure
- **`group: parallel: true`** — jobs within the group run in parallel
- Pre-commit runs fast checks (naming, format, lint)
- Pre-push runs slow checks (coverage)

---

## What Consumer Repos Must Provide

Each stack expects certain tools and config in the consumer repo. See [repo-requirements.md](https://github.com/leaflockio/core-docs/blob/main/standards/development/repo-requirements.md) in core-docs for the full contract.
