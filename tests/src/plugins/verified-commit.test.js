// Copyright 2026 Leaflock. All rights reserved.
// This source code is proprietary and confidential.
// Unauthorized copying, modification, distribution, or use of this
// software, via any medium, is strictly prohibited without prior
// written permission from Leaflock.

import { beforeEach, describe, expect, it, vi } from 'vitest';

// Mock @octokit/rest before importing the module under test
const mockGit = {
  createBlob: vi.fn(),
  createCommit: vi.fn(),
  createTree: vi.fn(),
  getCommit: vi.fn(),
  getRef: vi.fn(),
  updateRef: vi.fn(),
};

vi.mock('@octokit/rest', () => ({
  Octokit: class {
    constructor() {
      this.git = mockGit;
    }
  },
}));

vi.mock('child_process', async (importOriginal) => {
  const actual = await importOriginal();
  return { ...actual, execFileSync: vi.fn() };
});

vi.mock('fs', async (importOriginal) => {
  const actual = await importOriginal();
  return { ...actual, readFileSync: vi.fn() };
});

import * as childProcess from 'child_process';
import * as fs from 'fs';

import {
  parseRepo,
  prepare,
  renderMessage,
  verifyConditions,
} from '../../../src/plugins/verified-commit.js';

const mockReadFileSync = fs.readFileSync;
const mockExecFileSync = childProcess.execFileSync;

// ---------------------------------------------------------------------------
// Unit tests — parseRepo
// ---------------------------------------------------------------------------
describe('parseRepo', () => {
  it('parses HTTPS URL', () => {
    expect(parseRepo('https://github.com/leaflockio/core-actions')).toEqual({
      owner: 'leaflockio',
      repo: 'core-actions',
    });
  });

  it('parses SSH URL', () => {
    expect(parseRepo('git@github.com:leaflockio/core-actions')).toEqual({
      owner: 'leaflockio',
      repo: 'core-actions',
    });
  });

  it('strips .git suffix', () => {
    expect(parseRepo('https://github.com/leaflockio/core-actions.git')).toEqual({
      owner: 'leaflockio',
      repo: 'core-actions',
    });
  });

  it('throws on invalid URL', () => {
    expect(() => parseRepo('not-a-url')).toThrow('Cannot parse repository URL');
  });
});

// ---------------------------------------------------------------------------
// Unit tests — renderMessage
// ---------------------------------------------------------------------------
describe('renderMessage', () => {
  it('interpolates nextRelease.version', () => {
    const result = renderMessage('release ${nextRelease.version}', {
      nextRelease: { version: '1.2.3' },
    });
    expect(result).toBe('release 1.2.3');
  });

  it('interpolates nextRelease.notes', () => {
    const result = renderMessage('${nextRelease.notes}', {
      nextRelease: { notes: 'bug fixes' },
    });
    expect(result).toBe('bug fixes');
  });

  it('returns empty string for missing path', () => {
    const result = renderMessage('v${missing.path}', {});
    expect(result).toBe('v');
  });
});

// ---------------------------------------------------------------------------
// Unit tests — verifyConditions
// ---------------------------------------------------------------------------
describe('verifyConditions', () => {
  it('throws when no token is set', async () => {
    await expect(verifyConditions({ assets: ['file.txt'] }, { env: {} })).rejects.toThrow(
      'GitHub token not found',
    );
  });

  it('throws when assets is missing', async () => {
    await expect(verifyConditions({}, { env: { GH_TOKEN: 'tok' } })).rejects.toThrow(
      "The 'assets' option must be a non-empty array",
    );
  });

  it('throws when assets is empty', async () => {
    await expect(verifyConditions({ assets: [] }, { env: { GH_TOKEN: 'tok' } })).rejects.toThrow(
      "The 'assets' option must be a non-empty array",
    );
  });

  it('passes with valid config', async () => {
    await expect(
      verifyConditions({ assets: ['package.json'] }, { env: { GH_TOKEN: 'tok' } }),
    ).resolves.toBeUndefined();
  });
});

// ---------------------------------------------------------------------------
// Integration tests — prepare (mocked Octokit + fs)
// ---------------------------------------------------------------------------
describe('prepare', () => {
  const baseSha = 'aaa111';
  const treeSha = 'bbb222';
  const blobSha = 'ccc333';
  const newTreeSha = 'ddd444';
  const newCommitSha = 'eee555';

  const baseContext = {
    branch: { name: 'main' },
    cwd: '/workspace',
    env: { GH_TOKEN: 'test-token' },
    lastRelease: { version: '1.0.0' },
    logger: { log: vi.fn() },
    nextRelease: { notes: 'release notes', version: '2.0.0' },
    options: { repositoryUrl: 'https://github.com/leaflockio/core-actions' },
  };

  beforeEach(() => {
    vi.clearAllMocks();

    mockGit.getRef.mockResolvedValue({ data: { object: { sha: baseSha } } });
    mockGit.getCommit.mockResolvedValue({ data: { tree: { sha: treeSha } } });
    mockGit.createBlob.mockResolvedValue({ data: { sha: blobSha } });
    mockGit.createTree.mockResolvedValue({ data: { sha: newTreeSha } });
    mockGit.createCommit.mockResolvedValue({
      data: { sha: newCommitSha, verification: { verified: true } },
    });
    mockGit.updateRef.mockResolvedValue({});

    mockReadFileSync.mockReturnValue('file content');
  });

  it('calls the full API sequence for each asset', async () => {
    await prepare({ assets: ['package.json', 'CHANGELOG.md'] }, baseContext);

    expect(mockGit.getRef).toHaveBeenCalledWith({
      owner: 'leaflockio',
      ref: 'heads/main',
      repo: 'core-actions',
    });
    expect(mockGit.getCommit).toHaveBeenCalledWith({
      commit_sha: baseSha,
      owner: 'leaflockio',
      repo: 'core-actions',
    });
    expect(mockGit.createBlob).toHaveBeenCalledTimes(2);
    expect(mockGit.createTree).toHaveBeenCalledWith({
      base_tree: treeSha,
      owner: 'leaflockio',
      repo: 'core-actions',
      tree: [
        { mode: '100644', path: 'package.json', sha: blobSha, type: 'blob' },
        { mode: '100644', path: 'CHANGELOG.md', sha: blobSha, type: 'blob' },
      ],
    });
    expect(mockGit.createCommit).toHaveBeenCalledWith({
      message: expect.stringContaining('2.0.0'),
      owner: 'leaflockio',
      parents: [baseSha],
      repo: 'core-actions',
      tree: newTreeSha,
    });
    expect(mockGit.updateRef).toHaveBeenCalledWith({
      force: false,
      owner: 'leaflockio',
      ref: 'heads/main',
      repo: 'core-actions',
      sha: newCommitSha,
    });
  });

  it('throws when asset path resolves outside working directory', async () => {
    await expect(prepare({ assets: ['../outside.txt'] }, baseContext)).rejects.toThrow(
      'resolves outside the working directory',
    );
  });

  it('skips files that do not exist on disk', async () => {
    mockReadFileSync.mockImplementation((path) => {
      if (path.includes('missing')) throw new Error('ENOENT');
      return 'content';
    });

    await prepare({ assets: ['package.json', 'missing.txt'] }, baseContext);

    expect(mockGit.createBlob).toHaveBeenCalledTimes(1);
    expect(baseContext.logger.log).toHaveBeenCalledWith(
      expect.stringContaining('Skipping missing.txt'),
    );
  });

  it('returns early when all files are missing', async () => {
    mockReadFileSync.mockImplementation(() => {
      throw new Error('ENOENT');
    });

    await prepare({ assets: ['a.txt', 'b.txt'] }, baseContext);

    expect(mockGit.createTree).not.toHaveBeenCalled();
    expect(mockGit.createCommit).not.toHaveBeenCalled();
    expect(baseContext.logger.log).toHaveBeenCalledWith('No files to commit.');
  });

  it('uses default message template when none provided', async () => {
    await prepare({ assets: ['package.json'] }, baseContext);

    expect(mockGit.createCommit).toHaveBeenCalledWith(
      expect.objectContaining({
        message: expect.stringContaining('2.0.0'),
      }),
    );
    // default template includes release notes
    const commitCall = mockGit.createCommit.mock.calls[0][0];
    expect(commitCall.message).toContain('release notes');
  });

  it('falls back to GITHUB_TOKEN when GH_TOKEN is not set', async () => {
    const ctx = { ...baseContext, env: { GITHUB_TOKEN: 'fallback-token' } };
    await prepare({ assets: ['package.json'] }, ctx);

    expect(mockGit.createCommit).toHaveBeenCalled();
  });

  it('uses execFileSync with array args to prevent command injection', async () => {
    await prepare({ assets: ['package.json'] }, baseContext);

    expect(mockExecFileSync).toHaveBeenCalledWith('git', ['fetch', 'origin', 'main'], {
      cwd: '/workspace',
    });
    expect(mockExecFileSync).toHaveBeenCalledWith('git', ['reset', '--hard', 'origin/main'], {
      cwd: '/workspace',
    });
  });

  it('throws when updateRef fails', async () => {
    mockGit.updateRef.mockRejectedValue(new Error('branch protection'));

    await expect(prepare({ assets: ['package.json'] }, baseContext)).rejects.toThrow(
      'Failed to update ref',
    );
  });
});
