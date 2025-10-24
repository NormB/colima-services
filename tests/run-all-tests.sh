#!/bin/bash
#######################################
# Master Test Runner
#
# Orchestrates execution of all test suites in the Colima Services test
# infrastructure. Runs each test suite sequentially, tracks results, and
# provides comprehensive summary with pass/fail status for each suite.
#
# Globals:
#   SCRIPT_DIR - Absolute path to tests directory
#   TEST_RESULTS - Array of "suite_name:STATUS" pairs
#   TOTAL_SUITES - Total number of test suites executed
#   PASSED_SUITES - Number of suites that passed completely
#   FAILED_SUITES - Number of suites with failures
#   RED, GREEN, YELLOW, BLUE, CYAN, NC - Color codes for terminal output
#
# Dependencies:
#   - bash >= 3.2
#   - Individual test suite scripts in tests/ directory
#   - Docker and associated services
#
# Exit Codes:
#   0 - All test suites passed
#   1 - One or more test suites failed
#
# Usage:
#   ./tests/run-all-tests.sh
#
# Notes:
#   - Executes test suites in defined order (infrastructure, databases, apps)
#   - Continues execution even if individual suites fail (|| true)
#   - Each suite runs independently with own setup/teardown
#   - Total execution time depends on all suites combined
#   - Requires test environment setup via setup-test-env.sh first
#
# Test Suite Execution Order:
#   1. Infrastructure: Vault Integration
#   2. Databases: PostgreSQL, MySQL, MongoDB
#   3. Cache: Redis, Redis Cluster
#   4. Messaging: RabbitMQ
#   5. Applications: FastAPI Reference App
#   6. Performance: Load & Response Time Testing
#   7. Negative: Error Handling & Security Testing
#
# Examples:
#   # Run all tests
#   ./tests/run-all-tests.sh
#
#   # Run with debug output from individual tests
#   DEBUG=1 ./tests/run-all-tests.sh
#
#######################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test results (using simple arrays for bash 3.2 compatibility)
TEST_RESULTS=()
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

#######################################
# Print formatted section header in cyan
# Globals:
#   CYAN, NC - Color codes
# Arguments:
#   $1 - Header text to display
# Outputs:
#   Writes formatted header to stdout with border lines
#######################################
header() {
    echo
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}=========================================${NC}"
}

#######################################
# Print informational message in blue
# Globals:
#   BLUE, NC - Color codes
# Arguments:
#   $1 - Message to print
# Outputs:
#   Writes formatted message to stdout
#######################################
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

#######################################
# Print success message in green
# Globals:
#   GREEN, NC - Color codes
# Arguments:
#   $1 - Success message to print
# Outputs:
#   Writes formatted success message to stdout
#######################################
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

#######################################
# Print failure message in red
# Globals:
#   RED, NC - Color codes
# Arguments:
#   $1 - Failure message to print
# Outputs:
#   Writes formatted failure message to stdout
#######################################
fail() { echo -e "${RED}[FAIL]${NC} $1"; }

#######################################
# Print warning message in yellow
# Globals:
#   YELLOW, NC - Color codes
# Arguments:
#   $1 - Warning message to print
# Outputs:
#   Writes formatted warning message to stdout
#######################################
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

#######################################
# Execute a single test suite and track results
# Globals:
#   TOTAL_SUITES - Incremented by 1
#   PASSED_SUITES - Incremented if test passes
#   FAILED_SUITES - Incremented if test fails
#   TEST_RESULTS - Appended with "name:STATUS"
# Arguments:
#   $1 - Path to test script to execute
#   $2 - Display name for test suite
# Returns:
#   0 - Test suite passed (all tests in suite passed)
#   1 - Test suite failed (one or more tests failed)
# Outputs:
#   Writes header and test output to stdout
# Notes:
#   Executes test script with bash interpreter
#   Captures exit code to determine pass/fail
#   Always updates global tracking variables
#######################################
run_test_suite() {
    local test_script=$1
    local test_name=$2

    TOTAL_SUITES=$((TOTAL_SUITES + 1))

    header "Running: $test_name"

    if bash "$test_script"; then
        TEST_RESULTS+=("$test_name:PASSED")
        PASSED_SUITES=$((PASSED_SUITES + 1))
        return 0
    else
        TEST_RESULTS+=("$test_name:FAILED")
        FAILED_SUITES=$((FAILED_SUITES + 1))
        return 1
    fi
}

#######################################
# Print comprehensive summary of all test suite results
# Globals:
#   TOTAL_SUITES - Total test suites executed
#   PASSED_SUITES - Number of suites that passed
#   FAILED_SUITES - Number of suites that failed
#   TEST_RESULTS - Array of suite results
#   GREEN, RED, CYAN, NC - Color codes
# Arguments:
#   None
# Returns:
#   0 - All test suites passed
#   1 - One or more test suites failed
# Outputs:
#   Writes formatted summary to stdout with:
#   - Total suite counts
#   - Pass/fail breakdown
#   - Per-suite status with checkmarks/crosses
#   - Overall pass/fail verdict
# Notes:
#   Should be called after all test suites complete
#   Return code suitable for script exit code
#######################################
print_summary() {
    header "Test Summary"

    echo
    echo "Test Suites Run: $TOTAL_SUITES"
    echo -e "${GREEN}Passed: $PASSED_SUITES${NC}"

    if [ $FAILED_SUITES -gt 0 ]; then
        echo -e "${RED}Failed: $FAILED_SUITES${NC}"
    fi

    echo
    echo "Results by suite:"
    for result_pair in "${TEST_RESULTS[@]}"; do
        local suite="${result_pair%%:*}"
        local status="${result_pair##*:}"

        if [ "$status" = "PASSED" ]; then
            echo -e "  ${GREEN}✓${NC} $suite"
        else
            echo -e "  ${RED}✗${NC} $suite"
        fi
    done

    echo
    echo -e "${CYAN}=========================================${NC}"

    if [ $FAILED_SUITES -eq 0 ]; then
        echo -e "${GREEN}✓ ALL TESTS PASSED!${NC}"
        echo -e "${CYAN}=========================================${NC}"
        return 0
    else
        echo -e "${RED}✗ SOME TESTS FAILED${NC}"
        echo -e "${CYAN}=========================================${NC}"
        return 1
    fi
}

#######################################
# Main orchestration function for all test suites
# Globals:
#   SCRIPT_DIR - Used to locate test scripts
#   All tracking variables updated via run_test_suite
# Arguments:
#   None (ignores command line args)
# Returns:
#   0 - All test suites passed
#   1 - One or more test suites failed
# Outputs:
#   Writes test execution output and summary to stdout
# Notes:
#   Executes test suites in specific order
#   Uses || true to continue after failures
#   Always runs print_summary at end
#   Order: Infrastructure -> Databases -> Cache -> Messaging -> Apps
#######################################
main() {
    header "Colima Services - Test Suite"

    info "Starting all test suites..."
    echo

    # Infrastructure Tests
    run_test_suite "$SCRIPT_DIR/test-vault.sh" "Vault Integration" || true

    # Database Tests
    run_test_suite "$SCRIPT_DIR/test-postgres.sh" "PostgreSQL Vault Integration" || true
    run_test_suite "$SCRIPT_DIR/test-mysql.sh" "MySQL Vault Integration" || true
    run_test_suite "$SCRIPT_DIR/test-mongodb.sh" "MongoDB Vault Integration" || true

    # Cache Tests
    run_test_suite "$SCRIPT_DIR/test-redis.sh" "Redis Vault Integration" || true
    run_test_suite "$SCRIPT_DIR/test-redis-cluster.sh" "Redis Cluster" || true

    # Messaging Tests
    run_test_suite "$SCRIPT_DIR/test-rabbitmq.sh" "RabbitMQ Integration" || true

    # Application Tests
    run_test_suite "$SCRIPT_DIR/test-fastapi.sh" "FastAPI Reference App" || true

    # Performance Tests
    run_test_suite "$SCRIPT_DIR/test-performance.sh" "Performance & Load Testing" || true

    # Negative Tests
    run_test_suite "$SCRIPT_DIR/test-negative.sh" "Negative Testing & Error Handling" || true

    # Print summary
    print_summary
}

# Run main
main "$@"
