#!/bin/bash
#
# Test runner for dotfiles repository
# Runs basic validation tests for shell scripts and core functionality
#

set -e

# Get script directories
TEST_DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd -P)"
DOTFILES_DIR="$(cd "$( dirname "$TEST_DIR" )" && pwd -P)"

# Import logging functions
source "$DOTFILES_DIR/script/common/log.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test result tracking
declare -a FAILED_TESTS=()

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    info "Running test: $test_name"
    
    if eval "$test_command" > /dev/null 2>&1; then
        success "✓ $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        error "✗ $test_name"
        FAILED_TESTS+=("$test_name")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

run_test_with_output() {
    local test_name="$1"
    local test_command="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    info "Running test: $test_name"
    
    if eval "$test_command"; then
        success "✓ $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        error "✗ $test_name"
        FAILED_TESTS+=("$test_name")
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Run all test suites
main() {
    info "🧪 Starting dotfiles test suite"
    echo ""
    
    # Test 1: Script syntax validation
    info "=== Syntax Validation Tests ==="
    run_test "bin/dot syntax check" "bash -n '$DOTFILES_DIR/bin/dot'"
    run_test "bootstrap.sh syntax check" "bash -n '$DOTFILES_DIR/bootstrap.sh'"
    
    # Validate all installation scripts
    for script in "$DOTFILES_DIR/script"/*_installation.sh; do
        if [[ -f "$script" ]]; then
            local script_name=$(basename "$script")
            run_test "$script_name syntax check" "bash -n '$script'"
        fi
    done
    
    echo ""
    
    # Test 2: Core functionality tests
    info "=== Core Functionality Tests ==="
    run_test_with_output "System detection works" "$TEST_DIR/test_system_detection.sh"
    run_test_with_output "Config management works" "$TEST_DIR/test_config.sh"
    run_test_with_output "CLI help works" "$TEST_DIR/test_cli.sh"
    
    echo ""
    
    # Test results summary
    info "=== Test Results ==="
    echo "Tests run: $TESTS_RUN"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo ""
        error "Failed tests:"
        for test in "${FAILED_TESTS[@]}"; do
            echo "  - $test"
        done
        exit 1
    else
        echo ""
        success "All tests passed! ✨"
        exit 0
    fi
}

# Allow running individual test suites
case "${1:-all}" in
    "syntax")
        info "Running syntax validation tests only"
        # Run only syntax tests
        ;;
    "functionality") 
        info "Running functionality tests only"
        # Run only functionality tests
        ;;
    "all"|*)
        main
        ;;
esac