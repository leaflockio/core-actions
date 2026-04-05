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

import { Octokit } from '@octokit/rest';
import * as childProcess from 'child_process';
import * as fs from 'fs';
import { resolve } from 'path';

function parseRepo(repositoryUrl) {
  const match = repositoryUrl.match(/(?:github\.com)[/:]([^/]+)\/([^/.]+?)(?:\.git)?$/);
  if (!match) throw new Error(`Cannot parse repository URL: ${repositoryUrl}`);
  return { owner: match[1], repo: match[2] };
}

async function prepare(pluginConfig, context) {
  const { branch, cwd, env, lastRelease, logger, nextRelease, options } = context;
  const token = env.GH_TOKEN || env.GITHUB_TOKEN;
  const { owner, repo } = parseRepo(options.repositoryUrl);
  const octokit = new Octokit({ auth: token });
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
    ref: `heads/${branchName}`,
    repo,
  });
  const currentCommitSha = ref.object.sha;

  // 2. Get the base tree
  const { data: commit } = await octokit.git.getCommit({
    commit_sha: currentCommitSha,
    owner,
    repo,
  });
  const baseTreeSha = commit.tree.sha;

  // 3. Create blobs for each file
  const treeEntries = [];
  const resolvedCwd = resolve(cwd);
  for (const filePath of assets) {
    const fullPath = resolve(cwd, filePath);
    if (!fullPath.startsWith(resolvedCwd + '/') && fullPath !== resolvedCwd) {
      throw new Error(`Asset path '${filePath}' resolves outside the working directory.`);
    }
    let content;
    try {
      content = fs.readFileSync(fullPath, 'utf-8');
    } catch {
      logger.log(`Skipping ${filePath} (not found or not modified)`);
      continue;
    }

    const { data: blob } = await octokit.git.createBlob({
      content,
      encoding: 'utf-8',
      owner,
      repo,
    });

    treeEntries.push({
      mode: '100644',
      path: filePath,
      sha: blob.sha,
      type: 'blob',
    });
  }

  if (treeEntries.length === 0) {
    logger.log('No files to commit.');
    return;
  }

  // 4. Create tree
  const { data: tree } = await octokit.git.createTree({
    base_tree: baseTreeSha,
    owner,
    repo,
    tree: treeEntries,
  });

  // 5. Create commit
  const { data: newCommit } = await octokit.git.createCommit({
    message,
    owner,
    parents: [currentCommitSha],
    repo,
    tree: tree.sha,
  });

  logger.log(
    `Created verified commit ${newCommit.sha.substring(0, 7)} (verified: ${newCommit.verification?.verified})`,
  );

  // 6. Update branch ref
  try {
    await octokit.git.updateRef({
      force: false,
      owner,
      ref: `heads/${branchName}`,
      repo,
      sha: newCommit.sha,
    });
  } catch (err) {
    throw new Error(
      `Failed to update ref heads/${branchName} to ${newCommit.sha.substring(0, 7)}: ${err.message}`,
      { cause: err },
    );
  }

  // Update git HEAD locally so semantic-release tags the correct commit
  childProcess.execFileSync('git', ['fetch', 'origin', branchName], { cwd });
  childProcess.execFileSync('git', ['reset', '--hard', `origin/${branchName}`], { cwd });

  logger.log(`Pushed verified commit to ${branchName}`);
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

export { parseRepo, prepare, renderMessage, verify as verifyConditions };
