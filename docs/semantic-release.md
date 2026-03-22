# Semantic Release

The `actions/release/semantic-release` action handles versioning, tagging, and changelog generation for all stacks. It uses [semantic-release](https://github.com/semantic-release/semantic-release) under the hood — a Node-based tool that works with any language.

---

## How It Works

1. Reads commit messages since the last release
2. Determines the next version based on conventional commits (`fix:` → patch, `feat:` → minor, `feat!:` → major)
3. Updates version files, generates changelog, creates a git tag
4. Pushes the commit and tag back to the branch

The branch determines the release type:

- `main` → stable release (`1.2.0`)
- `pre-main` → beta release (`1.2.0-beta.1`)

This is configured in each repo's `.releaserc.json`, not in the action.

---

## Per-Stack Setup

### Node

Node is the simplest — semantic-release handles `package.json` natively.

**`.releaserc.json`:**

```json
{
  "branches": ["main", { "name": "pre-main", "prerelease": "beta" }],
  "plugins": [
    "@semantic-release/commit-analyzer",
    "@semantic-release/release-notes-generator",
    "@semantic-release/changelog",
    ["@semantic-release/npm", { "npmPublish": false }],
    [
      "@semantic-release/git",
      {
        "assets": ["package.json", "CHANGELOG.md"],
        "message": "chore(release): ${nextRelease.version}"
      }
    ],
    "@semantic-release/github"
  ]
}
```

**Workflow usage:**

```yaml
- uses: leaflockio/core-actions/actions/common/app-token@v1
  id: app-token
  with:
    app-id: ${{ secrets.LOCKET_CI_APP_ID }}
    private-key: ${{ secrets.LOCKET_CI_PRIVATE_KEY }}

- uses: leaflockio/core-actions/actions/release/semantic-release@v1
  with:
    token: ${{ steps.app-token.outputs.token }}
    extra-plugins: '@semantic-release/changelog @semantic-release/git'
```

No extra setup — `@semantic-release/npm` updates `package.json` automatically.

---

### Go

Go has no standard version file. Two approaches:

#### Option A — Git tags only (recommended)

No version file. The release creates a git tag (`v1.2.0`) and Go modules resolve the version from the tag. This is the Go convention.

**`.releaserc.json`:**

```json
{
  "branches": ["main", { "name": "pre-main", "prerelease": "beta" }],
  "plugins": [
    "@semantic-release/commit-analyzer",
    "@semantic-release/release-notes-generator",
    "@semantic-release/changelog",
    [
      "@semantic-release/git",
      {
        "assets": ["CHANGELOG.md"],
        "message": "chore(release): ${nextRelease.version}"
      }
    ],
    "@semantic-release/github"
  ]
}
```

#### Option B — Version file

If you need a version constant in code, use `@semantic-release/exec` to write it:

**`.releaserc.json`:**

```json
{
  "branches": ["main", { "name": "pre-main", "prerelease": "beta" }],
  "plugins": [
    "@semantic-release/commit-analyzer",
    "@semantic-release/release-notes-generator",
    "@semantic-release/changelog",
    [
      "@semantic-release/exec",
      {
        "prepareCmd": "sed -i 's/Version = \".*\"/Version = \"${nextRelease.version}\"/' version.go"
      }
    ],
    [
      "@semantic-release/git",
      {
        "assets": ["CHANGELOG.md", "version.go"],
        "message": "chore(release): ${nextRelease.version}"
      }
    ],
    "@semantic-release/github"
  ]
}
```

**Workflow usage:**

```yaml
- uses: leaflockio/core-actions/actions/release/semantic-release@v1
  with:
    token: ${{ steps.app-token.outputs.token }}
    extra-plugins: '@semantic-release/changelog @semantic-release/git @semantic-release/exec'
```

---

### Python

Python uses `pyproject.toml` for versioning. Use `@semantic-release/exec` to update it.

**`.releaserc.json`:**

```json
{
  "branches": ["main", { "name": "pre-main", "prerelease": "beta" }],
  "plugins": [
    "@semantic-release/commit-analyzer",
    "@semantic-release/release-notes-generator",
    "@semantic-release/changelog",
    [
      "@semantic-release/exec",
      {
        "prepareCmd": "sed -i 's/^version = \".*\"/version = \"${nextRelease.version}\"/' pyproject.toml"
      }
    ],
    [
      "@semantic-release/git",
      {
        "assets": ["CHANGELOG.md", "pyproject.toml"],
        "message": "chore(release): ${nextRelease.version}"
      }
    ],
    "@semantic-release/github"
  ]
}
```

**Workflow usage:**

```yaml
- uses: leaflockio/core-actions/actions/release/semantic-release@v1
  with:
    token: ${{ steps.app-token.outputs.token }}
    extra-plugins: '@semantic-release/changelog @semantic-release/git @semantic-release/exec'
```

If you publish to PyPI, add a `publishCmd` to the exec plugin:

```json
[
  "@semantic-release/exec",
  {
    "prepareCmd": "sed -i 's/^version = \".*\"/version = \"${nextRelease.version}\"/' pyproject.toml",
    "publishCmd": "python -m build && twine upload dist/*"
  }
]
```

---

## Required Secrets

All stacks need the same secrets:

| Secret                  | Purpose                            |
| ----------------------- | ---------------------------------- |
| `LOCKET_CI_APP_ID`      | GitHub App ID for verified commits |
| `LOCKET_CI_PRIVATE_KEY` | GitHub App private key             |

These are org-level secrets shared across all repos.

---

## Common Plugins

| Plugin                                      | What it does                                    |
| ------------------------------------------- | ----------------------------------------------- |
| `@semantic-release/commit-analyzer`         | Determines version bump from commits            |
| `@semantic-release/release-notes-generator` | Generates release notes                         |
| `@semantic-release/changelog`               | Writes CHANGELOG.md                             |
| `@semantic-release/git`                     | Commits version bump and changelog              |
| `@semantic-release/github`                  | Creates GitHub release                          |
| `@semantic-release/npm`                     | Updates package.json version (Node only)        |
| `@semantic-release/exec`                    | Runs custom commands (Go, Python version files) |
