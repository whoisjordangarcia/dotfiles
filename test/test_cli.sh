#!/bin/bash
#
# Test CLI functionality
#

set -e

# Get directories
TEST_DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd -P)"
DOTFILES_DIR="$(cd "$( dirname "$TEST_DIR" )" && pwd -P)"

# Source logging functions for error handling
source "$DOTFILES_DIR/script/common/log.sh"

DOT_SCRIPT="$DOTFILES_DIR/bin/dot"

# Test help functionality
test_help() {
    echo "Testing --help flag..."
    
    # Capture help output
    if ! help_output=$("$DOT_SCRIPT" --help 2>&1); then
        echo "Error: --help flag failed"
        return 1
    fi
    
    # Check for expected content in help
    if [[ ! "$help_output" == *"dot -- Enhanced dotfiles management"* ]]; then
        echo "Error: Help output missing expected title"
        return 1
    fi
    
    if [[ ! "$help_output" == *"Usage: dot [options]"* ]]; then
        echo "Error: Help output missing usage information"
        return 1
    fi
    
    if [[ ! "$help_output" == *"--help"* ]]; then
        echo "Error: Help output missing --help option"
        return 1
    fi
    
    echo "Help functionality works correctly"
    return 0
}

# Test list functionality
test_list() {
    echo "Testing --list flag..."
    
    # Capture list output
    if ! list_output=$("$DOT_SCRIPT" --list 2>&1); then
        echo "Error: --list flag failed"
        return 1
    fi
    
    # Should contain "Available installations:"
    if [[ ! "$list_output" == *"Available installations:"* ]]; then
        echo "Error: List output missing expected header"
        return 1
    fi
    
    echo "List functionality works correctly"
    return 0
}

# Test system detection output
test_system_flag() {
    echo "Testing --system flag..."
    
    # Capture system output
    if ! system_output=$("$DOT_SCRIPT" --system 2>&1); then
        echo "Error: --system flag failed"
        return 1
    fi
    
    # Should contain "System Detection:"
    if [[ ! "$system_output" == *"System Detection:"* ]]; then
        echo "Error: System output missing expected header"
        return 1
    fi
    
    # Should contain "Detected:"
    if [[ ! "$system_output" == *"Detected:"* ]]; then
        echo "Error: System output missing detection information"
        return 1
    fi
    
    echo "System detection flag works correctly"
    return 0
}

# Test invalid option handling
test_invalid_option() {
    echo "Testing invalid option handling..."
    
    # Test with invalid option - this should fail
    if "$DOT_SCRIPT" --invalid-option > /dev/null 2>&1; then
        echo "Error: Invalid option was accepted (should have failed)"
        return 1
    fi
    
    echo "Invalid option handling works correctly"
    return 0
}

# Run all tests
main() {
    echo "Testing CLI functionality..."
    test_help
    
    echo ""
    test_list
    
    echo ""
    test_system_flag
    
    echo ""
    test_invalid_option
    
    echo ""
    echo "CLI functionality tests completed successfully"
}

main