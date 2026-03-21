#!/usr/bin/env bats

setup() {
  load "../../test_helper/common-setup"
  _common_setup

  SCRIPT="${PROJECT_ROOT}/scripts/shell/coverage.sh"

  # Point coverage output to temp dir so tests don't touch real coverage/
  export COVERAGE_OUTPUT_DIR="${TEST_TEMP_DIR}/coverage"

  # Create coverage JSON in temp dir (not the real project coverage/)
  COVERAGE_DIR="${TEST_TEMP_DIR}/coverage/bats.test"
  mkdir -p "$COVERAGE_DIR"
  cat >"${COVERAGE_DIR}/coverage.json" <<'JSON'
{
  "percent_covered": "88.07",
  "covered_lines": 406,
  "total_lines": 461,
  "command": "bats"
}
JSON

  # Mock find to return our temp coverage JSON
  create_mock find "echo \"${COVERAGE_DIR}/coverage.json\""
}

teardown() {
  _common_teardown
}

# Write a JUnit report.xml to the expected location
write_junit_report() {
  local tests="${1:-3}" failures="${2:-0}" skipped="${3:-0}"
  local junit_dir="${COVERAGE_OUTPUT_DIR}/junit"
  mkdir -p "$junit_dir"
  cat >"${junit_dir}/report.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuites time="0.5">
  <testsuite name="tests" tests="${tests}" failures="${failures}" errors="0" skipped="${skipped}">
  </testsuite>
</testsuites>
EOF
}

# Mock bats --count to return expected test count
mock_bats_count() {
  local count="${1:-3}"
  create_mock bats "
    if [ \"\$1\" = \"--count\" ]; then
      echo \"${count}\"
      exit 0
    fi
  "
  create_mock npx "
    CMD=\"\$1\"
    shift
    exec \"\$(dirname \"\$0\")/\$CMD\" \"\$@\"
  "
}

# Helper: create a mock kcov that produces TAP output and JUnit report
mock_kcov_passing() {
  create_mock kcov "
    printf '1..3\nok 1 test one in 100ms\nok 2 test two in 200ms\nok 3 test three in 150ms\n'
    mkdir -p \"${COVERAGE_OUTPUT_DIR}/junit\"
    cat >\"${COVERAGE_OUTPUT_DIR}/junit/report.xml\" <<'JUNIT'
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<testsuites time=\"0.5\">
  <testsuite name=\"tests\" tests=\"3\" failures=\"0\" errors=\"0\" skipped=\"0\">
  </testsuite>
</testsuites>
JUNIT
  "
}

mock_kcov_failing() {
  create_mock kcov "
    printf '1..3\nok 1 test one in 100ms\nnot ok 2 test two in 200ms\n# (in test file tests/foo.bats, line 10)\nok 3 test three in 150ms\n'
    mkdir -p \"${COVERAGE_OUTPUT_DIR}/junit\"
    cat >\"${COVERAGE_OUTPUT_DIR}/junit/report.xml\" <<'JUNIT'
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<testsuites time=\"0.5\">
  <testsuite name=\"tests\" tests=\"3\" failures=\"1\" errors=\"0\" skipped=\"0\">
  </testsuite>
</testsuites>
JUNIT
    exit 1
  "
}

mock_docker_all_passing() {
  create_mock docker "
    case \"\$1\" in
      info) exit 0 ;;
      image) exit 0 ;;
      run)
        printf '1..3\nok 1 test one in 100ms\nok 2 test two in 200ms\nok 3 test three in 150ms\n'
        mkdir -p \"${COVERAGE_OUTPUT_DIR}/junit\"
        cat >\"${COVERAGE_OUTPUT_DIR}/junit/report.xml\" <<'JUNIT'
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<testsuites time=\"0.5\">
  <testsuite name=\"tests\" tests=\"3\" failures=\"0\" errors=\"0\" skipped=\"0\">
  </testsuite>
</testsuites>
JUNIT
        ;;
    esac
  "
}

@test "fails when --docker and Docker is not running" {
  mock_bats_count 1
  create_mock docker 'exit 1'
  run bash "$SCRIPT" --docker
  [ "$status" -eq 1 ]
  [[ "$output" == *"Docker is not running"* ]]
}

@test "native mode runs kcov and outputs coverage percent" {
  mock_bats_count 3
  mock_kcov_passing
  create_mock jq 'echo "88.07"'
  create_mock nproc 'echo "4"'
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"88.07"* ]]
}

@test "exits non-zero when tests fail in native mode" {
  mock_bats_count 3
  mock_kcov_failing
  create_mock nproc 'echo "4"'
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
}

@test "reports test failure count in stderr" {
  mock_bats_count 3
  mock_kcov_failing
  create_mock nproc 'echo "4"'
  run bash -c "export PATH=\"${TEST_BIN_DIR}:\$PATH\"; bash \"$SCRIPT\" 2>&1"
  [ "$status" -eq 1 ]
  [[ "$output" == *"1 failed"* ]]
}

@test "docker mode runs kcov via docker and outputs coverage percent" {
  mock_bats_count 3
  mock_docker_all_passing
  create_mock jq 'echo "88.07"'
  run bash "$SCRIPT" --docker
  [ "$status" -eq 0 ]
  [[ "$output" == *"88.07"* ]]
}

@test "docker mode builds image when it does not exist" {
  mock_bats_count 1
  create_mock docker "
    case \"\$1\" in
      info) exit 0 ;;
      image) exit 1 ;;
      build) exit 0 ;;
      run)
        printf '1..1\nok 1 test one in 100ms\n'
        mkdir -p \"${COVERAGE_OUTPUT_DIR}/junit\"
        cat >\"${COVERAGE_OUTPUT_DIR}/junit/report.xml\" <<'JUNIT'
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<testsuites time=\"0.1\">
  <testsuite name=\"tests\" tests=\"1\" failures=\"0\" errors=\"0\" skipped=\"0\">
  </testsuite>
</testsuites>
JUNIT
        ;;
    esac
  "
  create_mock jq 'echo "88.07"'
  run bash "$SCRIPT" --docker
  [ "$status" -eq 0 ]
  [[ "$output" == *"Building coverage image"* ]]
}

@test "fails when no coverage JSON found" {
  mock_bats_count 3
  mock_kcov_passing
  create_mock nproc 'echo "4"'
  create_mock find ''
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Could not determine coverage"* ]]
}

@test "fails when test count does not match expected" {
  mock_bats_count 10
  mock_kcov_passing
  create_mock nproc 'echo "4"'
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Expected 10 tests but only 3 ran"* ]]
}

@test "fails when no tests found" {
  mock_bats_count 0
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"No tests found"* ]]
}

@test "fails when JUnit report is missing" {
  mock_bats_count 3
  create_mock kcov 'printf "1..3\nok 1 test one in 100ms\nok 2 test two in 200ms\nok 3 test three in 150ms\n"'
  create_mock nproc 'echo "4"'
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"JUnit report not found"* ]]
}
