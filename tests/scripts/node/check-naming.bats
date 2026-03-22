#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup
  init_test_repo

  echo "init" >README.md
  git add README.md
  git commit -m "init"

  SCRIPT="${PROJECT_ROOT}/scripts/node/check-naming.sh"
}

teardown() {
  _common_teardown
}

# --- No staged files ---

@test "passes when no JS/TS files to check" {
  echo "" >config.yml
  git add config.yml

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No JS/TS files to check"* ]]
}

# --- Kebab-case files ---

@test "passes with kebab-case JS files" {
  echo "" >my-utils.ts
  echo "" >api-client.js
  echo "" >auth-handler.tsx
  git add my-utils.ts api-client.js auth-handler.tsx

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Node naming check passed"* ]]
}

# --- PascalCase React components ---

@test "passes with PascalCase jsx" {
  echo "" >MyComponent.jsx
  git add MyComponent.jsx

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "passes with PascalCase tsx" {
  echo "" >UserProfile.tsx
  git add UserProfile.tsx

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "passes with PascalCase js" {
  echo "" >App.js
  git add App.js

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

# --- useCamelCase hooks ---

@test "passes with useCamelCase hook ts" {
  echo "" >useTheme.ts
  git add useTheme.ts

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "passes with useCamelCase hook js" {
  echo "" >useAuth.js
  git add useAuth.js

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

# --- camelCase utilities ---

@test "passes with camelCase utility" {
  echo "" >setupTests.ts
  echo "" >reportWebVitals.js
  git add setupTests.ts reportWebVitals.js

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

# --- Config/test/spec files ---

@test "passes with config files" {
  echo "" >jest.config.ts
  echo "" >vite.config.js
  git add jest.config.ts vite.config.js

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "passes with test files" {
  echo "" >app.test.tsx
  echo "" >utils.test.ts
  git add app.test.tsx utils.test.ts

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "passes with spec files" {
  echo "" >auth.spec.ts
  echo "" >login.spec.jsx
  git add auth.spec.ts login.spec.jsx

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "passes with cjs/mjs config files" {
  echo "" >eslint.config.cjs
  echo "" >next.config.mjs
  git add eslint.config.cjs next.config.mjs

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

# --- Next.js dynamic routes ---

@test "passes with [slug] dynamic route" {
  echo "" >"[slug].tsx"
  git add "[slug].tsx"

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "passes with [...slug] catch-all route" {
  echo "" >"[...slug].tsx"
  git add "[...slug].tsx"

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "passes with [[...slug]] optional catch-all route" {
  echo "" >"[[...slug]].tsx"
  git add "[[...slug]].tsx"

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

# --- Next.js special files ---

@test "passes with _app.tsx" {
  echo "" >_app.tsx
  git add _app.tsx

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "passes with _document.tsx" {
  echo "" >_document.tsx
  git add _document.tsx

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "passes with _error.tsx" {
  echo "" >_error.tsx
  git add _error.tsx

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

# --- Dotfiles skipped ---

@test "skips dotfiles" {
  echo "" >.eslintrc.js
  git add .eslintrc.js

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

# --- .github/ excluded ---

@test "skips .github directory" {
  mkdir -p .github/workflows
  echo "" >.github/workflows/BadName.js
  git add .github/workflows/BadName.js

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

# --- Folder checks ---

@test "passes with kebab-case folders" {
  mkdir -p src/my-components
  echo "" >src/my-components/index.ts
  git add src/my-components/index.ts

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "passes with PascalCase component folders" {
  mkdir -p components/MyComponent
  echo "" >components/MyComponent/index.tsx
  git add components/MyComponent/index.tsx

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "passes with Next.js dynamic route folders" {
  mkdir -p "pages/[slug]"
  echo "" >"pages/[slug]/index.tsx"
  git add "pages/[slug]/index.tsx"

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "passes with catch-all route folders" {
  mkdir -p "pages/[...slug]"
  echo "" >"pages/[...slug]/index.tsx"
  git add "pages/[...slug]/index.tsx"

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "skips hidden folders" {
  mkdir -p .next
  echo "" >.next/cache.js
  git add .next/cache.js

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "skips double-underscore directories" {
  mkdir -p __tests__
  echo "" >__tests__/app.test.ts
  git add __tests__/app.test.ts

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "skips node_modules" {
  mkdir -p node_modules/pkg
  echo "" >node_modules/pkg/index.js
  git add node_modules/pkg/index.js

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "fails on invalid folder name" {
  mkdir -p "My Folder"
  echo "" >"My Folder/index.ts"
  git add "My Folder/index.ts"

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid JS/TS folder name"* ]]
}

# --- Invalid filenames ---

@test "fails on UPPER_SNAKE_CASE JS file" {
  echo "" >MY_CONSTANTS.js
  git add MY_CONSTANTS.js

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid JS/TS filename"* ]]
}

@test "fails on spaces in JS filename" {
  echo "" >"my component.tsx"
  git add "my component.tsx"

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid JS/TS filename"* ]]
}

# --- Mixed valid and invalid ---

@test "reports all invalid files" {
  echo "" >good-file.ts
  echo "" >MyComponent.tsx
  echo "" >MY_BAD.js
  echo "" >"bad name.ts"
  git add good-file.ts MyComponent.tsx MY_BAD.js "bad name.ts"

  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"MY_BAD.js"* ]]
  [[ "$output" == *"bad name.ts"* ]]
}
