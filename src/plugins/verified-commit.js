// Copyright 2026 Leaflock. All rights reserved.
// This source code is proprietary and confidential.
// Unauthorized copying, modification, distribution, or use of this
// software, via any medium, is strictly prohibited without prior
// written permission from Leaflock.

// Semantic-release plugin that creates verified (signed) commits via
// the GitHub Git Database API. Replaces @semantic-release/git to
// produce commits that GitHub marks as "Verified" when authenticated
// with a GitHub App token.
//
// Usage in .releaserc.json:
//   ["./src/plugins/verified-commit.js", {
//     "assets": ["package.json", "package-lock.json", "CHANGELOG.md"],
//     "message": "chore(release): ${nextRelease.version} [skip ci]"
//   }]

const { readFileSync } = require('fs');
const { join } = require('path');
const { execFileSync } = require('child_process');

function parseRepo(repositoryUrl) {
  const match = repositoryUrl.match(/(?:github\.com)[/:]([^/]+)\/([^/.]+?)(?:\.git)?$/);
  if (!match) throw new Error(`Cannot parse repository URL: ${repositoryUrl}`);
  return { owner: match[1], repo: match[2] };
}

async function getOctokit(token) {
  const { Octokit } = await import('@octokit/rest');
  return new Octokit({ auth: token });
}

function renderMessage(msg, context) {
  return msg.replace(/\$\{([^}]+)\}/g, (_, path) => {
    const value = path.split('.').reduce((obj, key) => obj?.[key], context);
    return value !== undefined && value !== null ? String(value) : '';
  });
}

async function verify(pluginConfig, context) {
  const token = context.env.GH_TOKEN || context.env.GITHUB_TOKEN;
  if (!token) {
    throw new Error('GitHub token not found. Set GH_TOKEN or GITHUB_TOKEN env var.');
  }
  if (
    !pluginConfig.assets ||
    !Array.isArray(pluginConfig.assets) ||
    pluginConfig.assets.length === 0
  ) {
    throw new Error("The 'assets' option must be a non-empty array of files.");
  }
}

async function prepare(pluginConfig, context) {
  const { env, cwd, options, logger, nextRelease, lastRelease, branch } = context;
  const token = env.GH_TOKEN || env.GITHUB_TOKEN;
  const { owner, repo } = parseRepo(options.repositoryUrl);
  const octokit = await getOctokit(token);
  const branchName = branch.name;
  const assets = pluginConfig.assets;

  const msg =
    pluginConfig.message ||
    'chore(release): ${nextRelease.version} [skip ci]\n\n${nextRelease.notes}';
  const message = renderMessage(msg, {
    branch,
    lastRelease,
    nextRelease,
  });

  // 1. Get current branch ref
  const { data: ref } = await octokit.git.getRef({
    owner,
    repo,
    ref: `heads/${branchName}`,
  });
  const currentCommitSha = ref.object.sha;

  // 2. Get the base tree
  const { data: commit } = await octokit.git.getCommit({
    owner,
    repo,
    commit_sha: currentCommitSha,
  });
  const baseTreeSha = commit.tree.sha;

  // 3. Create blobs for each file
  const treeEntries = [];
  for (const filePath of assets) {
    const fullPath = join(cwd, filePath);
    let content;
    try {
      content = readFileSync(fullPath, 'utf-8');
    } catch {
      logger.log(`Skipping ${filePath} (not found or not modified)`);
      continue;
    }

    const { data: blob } = await octokit.git.createBlob({
      owner,
      repo,
      content,
      encoding: 'utf-8',
    });

    treeEntries.push({
      path: filePath,
      mode: '100644',
      type: 'blob',
      sha: blob.sha,
    });
  }

  if (treeEntries.length === 0) {
    logger.log('No files to commit.');
    return;
  }

  // 4. Create tree
  const { data: tree } = await octokit.git.createTree({
    owner,
    repo,
    base_tree: baseTreeSha,
    tree: treeEntries,
  });

  // 5. Create commit
  const { data: newCommit } = await octokit.git.createCommit({
    owner,
    repo,
    message,
    tree: tree.sha,
    parents: [currentCommitSha],
  });

  logger.log(
    `Created verified commit ${newCommit.sha.substring(0, 7)} (verified: ${newCommit.verification?.verified})`,
  );

  // 6. Update branch ref
  try {
    await octokit.git.updateRef({
      owner,
      repo,
      ref: `heads/${branchName}`,
      sha: newCommit.sha,
      force: false,
    });
  } catch (err) {
    throw new Error(
      `Failed to update ref heads/${branchName} to ${newCommit.sha.substring(0, 7)}: ${err.message}`,
    );
  }

  // Update git HEAD locally so semantic-release tags the correct commit
  execFileSync('git', ['fetch', 'origin', branchName], { cwd });
  execFileSync('git', ['reset', '--hard', `origin/${branchName}`], { cwd });

  logger.log(`Pushed verified commit to ${branchName}`);
}

module.exports = { verifyConditions: verify, prepare, parseRepo, renderMessage };
