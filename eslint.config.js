// Copyright 2026 Leaflock. All rights reserved.
// This source code is proprietary and confidential.
// Unauthorized copying, modification, distribution, or use of this
// software, via any medium, is strictly prohibited without prior
// written permission from Leaflock.

import { includeIgnoreFile } from '@eslint/compat';
import js from '@eslint/js';
import prettierConfig from 'eslint-config-prettier';
import perfectionist from 'eslint-plugin-perfectionist';
import security from 'eslint-plugin-security';
import globals from 'globals';
import { resolve } from 'path';
import { fileURLToPath } from 'url';

const gitignorePath = resolve(fileURLToPath(import.meta.url), '..', '.gitignore');

const config = [
  includeIgnoreFile(gitignorePath),

  js.configs.recommended,

  {
    files: ['**/*.js'],
    languageOptions: {
      globals: {
        ...globals.node,
      },
    },
    plugins: {
      perfectionist,
      security,
    },
    rules: {
      ...security.configs.recommended.rules,
      ...perfectionist.configs['recommended-alphabetical'].rules,
      eqeqeq: ['error', 'always'],
      'no-console': 'error',
      'no-shadow': 'error',
      'security/detect-non-literal-fs-filename': 'off',
      'security/detect-object-injection': 'off',
    },
  },

  {
    files: ['tests/**/*.js'],
    languageOptions: {
      globals: {
        ...globals.node,
        ...globals.vitest,
      },
    },
  },

  prettierConfig,
];

export default config;
