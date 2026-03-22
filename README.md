# core-actions

![CI](https://github.com/leaflockio/core-actions/actions/workflows/ci.yml/badge.svg)
![Release](https://github.com/leaflockio/core-actions/actions/workflows/release.yml/badge.svg)
![Pre-release](https://github.com/leaflockio/core-actions/actions/workflows/pre-release.yml/badge.svg)
![Version](https://img.shields.io/badge/version-v1.0.0-blue)
![License](https://img.shields.io/badge/License-Apache_2.0-blue)
![Shell](https://img.shields.io/badge/Shell-Bash-green)

Reusable GitHub Actions workflows, composite actions, lefthook configs, and shared hook scripts for Leaflock repositories. Provides standardized CI, release, back-merge pipelines, and git hooks so every repo follows the same flow without duplicating logic.

---

## Tech Stack

- GitHub Actions (composite actions + reusable workflows)
- Shell scripts (Bash)
- [semantic-release](https://github.com/semantic-release/semantic-release) v24
- [cycjimmy/semantic-release-action](https://github.com/cycjimmy/semantic-release-action) v4
- [Lefthook](https://github.com/evilmartians/lefthook) (git hooks)
- [Gitleaks](https://github.com/gitleaks/gitleaks) (secret scanning)
- [Prettier](https://prettier.io) (formatting)
- [cspell](https://cspell.org) (spell checking)
- [markdownlint-cli2](https://github.com/DavidAnson/markdownlint-cli2) (markdown linting)
- [ShellCheck](https://www.shellcheck.net) (shell linting)
- [shfmt](https://github.com/mvdan/sh) (shell formatting)
- [bats-core](https://github.com/bats-core/bats-core) (shell testing)
- [Vitest](https://vitest.dev) (JS testing)
- [kcov](https://github.com/SimonKagstrom/kcov) (shell coverage)

---

## Local Setup

No build step required. This repo contains only YAML workflow definitions and shell scripts. Clone, install hooks, and edit directly.

```bash
git clone git@github.com:leaflockio/core-actions.git
cd core-actions
lefthook install
```

Prerequisites (system): `lefthook`, `gitleaks`, `shfmt`, `shellcheck`. Node tools (`prettier`, `cspell`, `markdownlint-cli2`, `bats`) are installed via `npm ci`.

---

## Environment Variables

These are configured as **repository secrets** in consumer repos, not local env vars.

| Variable                | Description                             | Required | Example        |
| ----------------------- | --------------------------------------- | -------- | -------------- |
| `LOCKET_CI_APP_ID`      | GitHub App ID for locket-ci             | Yes      | `123456`       |
| `LOCKET_CI_PRIVATE_KEY` | GitHub App private key for locket-ci    | Yes      | PEM key        |
| `GITLEAKS_LICENSE`      | License key for Gitleaks secret scanner | No       | `gitleaks-key` |

Values are stored in the GitHub organization secrets. Ask the platform team for access.

---

## Available Commands

```bash
npm run format              # fix formatting (prettier)
npm run format:check        # check formatting (prettier)
npm run format:sh           # fix formatting (shfmt)
npm run format:sh:check     # check formatting (shfmt)
npm run spell               # check spelling
npm run lint:sh             # lint shell scripts
npm run lint:md             # lint markdown
npm run lint:md:fix         # fix markdown lint issues
npm run test                       # run bats tests
npm run test:js                    # run JS tests (vitest)
npm run test:js:coverage           # run JS tests with coverage
npm run test:js:coverage:check     # run JS tests + baseline check
npm run test:sh:coverage           # run shell tests with coverage (CI)
npm run test:sh:coverage:local     # run shell tests with coverage (Docker)
```

---

## Usage in Consumer Repos

### Git Hooks

Consumer repos pull hook configs via lefthook remotes:

```yaml
# lefthook.yml
remotes:
  - git_url: https://github.com/leaflockio/core-actions
    ref: v1
    configs:
      - lefthook/common.yml
      - lefthook/node.yml # swap for your stack: go.yml, python.yml, shell.yml
```

See [docs/lefthook.md](docs/lefthook.md) for available configs and what each stack requires.

### Workflows

Consumer repos call reusable workflow templates via a pinned version tag (e.g. `@v1`).

### Example: CI workflow

```yaml
on:
  pull_request:
    branches: [pre-main, main]
jobs:
  quality:
    uses: leaflockio/core-actions/.github/workflows/tpl-common-ci.yml@v1
    secrets:
      GITLEAKS_LICENSE: ${{ secrets.GITLEAKS_LICENSE }}
  node:
    uses: leaflockio/core-actions/.github/workflows/tpl-node-ci.yml@v1
```

### Example: Pre-release workflow

```yaml
on:
  push:
    branches: [pre-main]
jobs:
  release:
    uses: leaflockio/core-actions/.github/workflows/tpl-release.yml@v1
    with:
      release: true
    secrets:
      APP_ID: ${{ secrets.LOCKET_CI_APP_ID }}
      APP_PRIVATE_KEY: ${{ secrets.LOCKET_CI_PRIVATE_KEY }}
```

### Example: Production release with back-merge

```yaml
on:
  push:
    branches: [main]
jobs:
  release:
    uses: leaflockio/core-actions/.github/workflows/tpl-release.yml@v1
    with:
      release: true
    secrets:
      APP_ID: ${{ secrets.LOCKET_CI_APP_ID }}
      APP_PRIVATE_KEY: ${{ secrets.LOCKET_CI_PRIVATE_KEY }}
  back-merge:
    needs: release
    if: needs.release.outputs.new_release_published == 'true'
    uses: leaflockio/core-actions/.github/workflows/tpl-back-merge.yml@v1
    with:
      strategy: merge
    secrets:
      APP_ID: ${{ secrets.LOCKET_CI_APP_ID }}
      APP_PRIVATE_KEY: ${{ secrets.LOCKET_CI_PRIVATE_KEY }}
```

---

## Documentation

| Document                                             | What it covers                                       |
| ---------------------------------------------------- | ---------------------------------------------------- |
| [docs/shell-scripts.md](docs/shell-scripts.md)       | Script directory structure, sourcing patterns        |
| [docs/testing.md](docs/testing.md)                   | Bats test structure, helpers, mocking, writing tests |
| [docs/coverage.md](docs/coverage.md)                 | kcov setup, configuration, baseline system           |
| [docs/lefthook.md](docs/lefthook.md)                 | Available hook configs, consumer repo setup          |
| [docs/semantic-release.md](docs/semantic-release.md) | Per-stack release setup, plugins, secrets            |

---

## Deployment and Rollback

Releases are automated via semantic-release. Consumer repos pin to version tags (e.g. `@v1`) for stability.

To roll back, consumer repos change their pinned tag to a previous version (e.g. `@v1.1.0`). To fix forward, revert the breaking commit on `main` — semantic-release will publish a new version with the fix.
