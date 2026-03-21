#!/usr/bin/env bash
# Copyright 2026 Leaflock. All rights reserved.
# This source code is proprietary and confidential.
# Unauthorized copying, modification, distribution, or use of this
# software, via any medium, is strictly prohibited without prior
# written permission from Leaflock.

# Runs bats tests under kcov for shell script coverage.
# Outputs coverage percentage to stdout on success.
# All logs go to stderr so callers can capture the percentage.
# Usage:
#   bash scripts/shell/coverage.sh            # native (CI / Linux)
#   bash scripts/shell/coverage.sh --docker   # via Docker container (local macOS)

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IMAGE_NAME="leaflock/kcov-bats"
CONTAINER_ROOT="/repo"
USE_DOCKER=false

# Parse flags
for arg in "$@"; do
  case "$arg" in
  --docker) USE_DOCKER=true ;;
  esac
done

. "$REPO_ROOT/scripts/common/config.sh"

COVERAGE_OUTPUT_DIR="${COVERAGE_OUTPUT_DIR:-$REPO_ROOT/coverage}"

# Clean stale coverage data so reports always reflect the current run
rm -rf "$COVERAGE_OUTPUT_DIR"
mkdir -p "$COVERAGE_OUTPUT_DIR"

# Get expected test count before running
EXPECTED_TESTS=$(npx bats --count --recursive "$REPO_ROOT/tests/")
if [ -z "$EXPECTED_TESTS" ] || [ "$EXPECTED_TESTS" -eq 0 ]; then
  log_error "No tests found." >&2
  exit 1
fi

# Build kcov flags from COVERAGE_SRC (space-separated paths)
KCOV_DOCKER_FLAGS=()
KCOV_NATIVE_FLAGS=()
for src in $COVERAGE_SRC; do
  KCOV_DOCKER_FLAGS+=(--bash-parse-files-in-dir="$CONTAINER_ROOT/$src/" --include-pattern="$CONTAINER_ROOT/$src/")
  KCOV_NATIVE_FLAGS+=(--bash-parse-files-in-dir="$REPO_ROOT/$src/" --include-pattern="$REPO_ROOT/$src/")
done

log_info "Running tests under kcov (${EXPECTED_TESTS} tests)..." >&2
START_TIME=$(date +%s)

JUNIT_DIR="${COVERAGE_OUTPUT_DIR}/junit"
mkdir -p "$JUNIT_DIR"

OUTPUT_FILE=$(mktemp)
KCOV_EXIT=0

if [ "$USE_DOCKER" = true ]; then
  # Verify Docker daemon is running
  if ! docker info >/dev/null 2>&1; then
    log_error "Docker is not running." >&2
    log_warn "Please start Docker Desktop (or the Docker daemon) and try again." >&2
    rm -f "$OUTPUT_FILE"
    exit 1
  fi

  # Build the image once if it doesn't exist
  if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    log_info "Building coverage image (one-time setup)..." >&2
    docker build -t "$IMAGE_NAME" - <<'DOCKERFILE'
FROM kcov/kcov
RUN apt-get update -qq && apt-get install -y -qq bats git parallel >/dev/null 2>&1
DOCKERFILE
  fi

  docker run --rm \
    -v "${REPO_ROOT}:${CONTAINER_ROOT}" \
    -w "$CONTAINER_ROOT" \
    "$IMAGE_NAME" \
    sh -c "kcov --bash-dont-parse-binary-dir ${KCOV_DOCKER_FLAGS[*]} ${CONTAINER_ROOT}/coverage \$(which bats) --jobs 1 --timing --report-formatter junit --output ${CONTAINER_ROOT}/coverage/junit --recursive ${CONTAINER_ROOT}/tests/" \
    >"$OUTPUT_FILE" 2>&1 || KCOV_EXIT=$?
else
  kcov --bash-dont-parse-binary-dir "${KCOV_NATIVE_FLAGS[@]}" "$REPO_ROOT/coverage" npx bats --jobs 1 --timing --report-formatter junit --output "$JUNIT_DIR" --recursive "$REPO_ROOT/tests/" \
    >"$OUTPUT_FILE" 2>&1 || KCOV_EXIT=$?
fi

# Parse test results from JUnit XML report (reliable regardless of parallel output)
JUNIT_FILE="$JUNIT_DIR/report.xml"
if [ -f "$JUNIT_FILE" ]; then
  TOTAL=$(grep -oE 'tests="[0-9]+"' "$JUNIT_FILE" | grep -oE '[0-9]+' | awk '{s+=$1} END {print s+0}')
  FAILED=$(grep -oE 'failures="[0-9]+"' "$JUNIT_FILE" | grep -oE '[0-9]+' | awk '{s+=$1} END {print s+0}')
  SKIPPED=$(grep -oE 'skipped="[0-9]+"' "$JUNIT_FILE" | grep -oE '[0-9]+' | awk '{s+=$1} END {print s+0}')
  PASSED=$((TOTAL - FAILED - SKIPPED))
else
  log_error "JUnit report not found at $JUNIT_FILE" >&2
  log_warn "kcov exit code: ${KCOV_EXIT}" >&2
  cat "$OUTPUT_FILE" >&2
  rm -f "$OUTPUT_FILE"
  exit 1
fi

ELAPSED=$(($(date +%s) - START_TIME))

if [ "$FAILED" -gt 0 ]; then
  log_error "Tests: ${PASSED} passed, ${FAILED} failed (${TOTAL} total) in ${ELAPSED}s" >&2
  echo "" >&2
  grep '^not ok ' "$OUTPUT_FILE" | while read -r line; do
    log_error "  $line" >&2
  done
  grep -A 3 '^not ok ' "$OUTPUT_FILE" | grep '^#' | while read -r line; do
    log_info "  $line" >&2
  done
  echo "" >&2
else
  log_success "Tests: ${PASSED} passed (${TOTAL} total) in ${ELAPSED}s" >&2
fi

# Validate all tests were discovered and executed
if [ "$TOTAL" -ne "$EXPECTED_TESTS" ]; then
  log_error "Expected ${EXPECTED_TESTS} tests but only ${TOTAL} ran." >&2
  log_warn "kcov exit code: ${KCOV_EXIT}" >&2
  log_warn "Full output:" >&2
  cat "$OUTPUT_FILE" >&2
  rm -f "$OUTPUT_FILE"
  exit 1
fi

rm -f "$OUTPUT_FILE"

# Fail if kcov or tests failed
if [ "$KCOV_EXIT" -ne 0 ] || [ "$FAILED" -gt 0 ]; then
  log_error "kcov exited with code ${KCOV_EXIT}." >&2
  exit 1
fi

# Extract total coverage percentage from kcov JSON summary
COVERAGE_FILE=$(find "$REPO_ROOT/coverage" -name "coverage.json" -not -path "*/kcov-merged/*" | head -1)
if [ -n "$COVERAGE_FILE" ]; then
  REPORT_DIR=$(dirname "$COVERAGE_FILE")
  PERCENT=$(jq -r '.percent_covered' "$COVERAGE_FILE")
  log_info "Report: ${REPORT_DIR}/index.html" >&2

  # Check against baseline
  bash "$REPO_ROOT/scripts/common/check-coverage.sh" "$PERCENT"
else
  log_error "Could not determine coverage." >&2
  exit 1
fi
