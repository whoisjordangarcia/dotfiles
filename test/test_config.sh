#!/bin/bash
#
# Test configuration management functionality
#

set -e

# Get directories
TEST_DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd -P)"
DOTFILES_DIR="$(cd "$( dirname "$TEST_DIR" )" && pwd -P)"

# Create a temporary config file for testing
TEST_CONFIG_FILE="/tmp/test_dotconfig_$$"

# Source logging functions
source "$DOTFILES_DIR/script/common/log.sh"

# Override config file path for testing
export configFile="$TEST_CONFIG_FILE"

# Extract the config functions we need
load_config() {
    if [[ -f "$configFile" ]]; then
        source "$configFile"
    fi
}

save_config() {
    cat > "$configFile" << EOF
# Dotfiles configuration
DOT_NAME="$DOT_NAME"
DOT_EMAIL="$DOT_EMAIL"
DOT_ENVIRONMENT="$DOT_ENVIRONMENT"
DOT_SYSTEM="$DOT_SYSTEM"
EOF
}

cleanup() {
    rm -f "$TEST_CONFIG_FILE"
}

trap cleanup EXIT

# Test config saving and loading
test_config_management() {
    # Set test values
    DOT_NAME="Test User"
    DOT_EMAIL="test@example.com"
    DOT_ENVIRONMENT="personal"
    DOT_SYSTEM="test_system"
    
    echo "Testing config save..."
    save_config
    
    if [[ ! -f "$TEST_CONFIG_FILE" ]]; then
        echo "Error: Config file was not created"
        return 1
    fi
    
    echo "Config file created successfully"
    
    # Clear variables
    unset DOT_NAME DOT_EMAIL DOT_ENVIRONMENT DOT_SYSTEM
    
    echo "Testing config load..."
    load_config
    
    # Verify values were loaded
    if [[ "$DOT_NAME" != "Test User" ]]; then
        echo "Error: DOT_NAME not loaded correctly. Expected 'Test User', got '$DOT_NAME'"
        return 1
    fi
    
    if [[ "$DOT_EMAIL" != "test@example.com" ]]; then
        echo "Error: DOT_EMAIL not loaded correctly. Expected 'test@example.com', got '$DOT_EMAIL'"
        return 1
    fi
    
    if [[ "$DOT_ENVIRONMENT" != "personal" ]]; then
        echo "Error: DOT_ENVIRONMENT not loaded correctly. Expected 'personal', got '$DOT_ENVIRONMENT'"
        return 1
    fi
    
    if [[ "$DOT_SYSTEM" != "test_system" ]]; then
        echo "Error: DOT_SYSTEM not loaded correctly. Expected 'test_system', got '$DOT_SYSTEM'"
        return 1
    fi
    
    echo "All configuration values loaded correctly"
    return 0
}

# Test config file format
test_config_format() {
    DOT_NAME="Test User"
    DOT_EMAIL="test@example.com"
    DOT_ENVIRONMENT="personal"
    DOT_SYSTEM="test_system"
    
    save_config
    
    # Check that the config file has the expected format
    if ! grep -q "DOT_NAME=\"Test User\"" "$TEST_CONFIG_FILE"; then
        echo "Error: Config file missing DOT_NAME"
        return 1
    fi
    
    if ! grep -q "DOT_EMAIL=\"test@example.com\"" "$TEST_CONFIG_FILE"; then
        echo "Error: Config file missing DOT_EMAIL"
        return 1
    fi
    
    if ! grep -q "DOT_ENVIRONMENT=\"personal\"" "$TEST_CONFIG_FILE"; then
        echo "Error: Config file missing DOT_ENVIRONMENT"
        return 1
    fi
    
    if ! grep -q "DOT_SYSTEM=\"test_system\"" "$TEST_CONFIG_FILE"; then
        echo "Error: Config file missing DOT_SYSTEM"
        return 1
    fi
    
    echo "Config file format is correct"
    return 0
}

# Run all tests
main() {
    echo "Testing configuration management..."
    test_config_management
    
    echo ""
    echo "Testing config file format..."
    test_config_format
    
    echo ""
    echo "Configuration management tests completed successfully"
}

main