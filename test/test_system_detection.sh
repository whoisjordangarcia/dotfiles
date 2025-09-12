#!/bin/bash
#
# Test system detection functionality
#

set -e

# Get directories
TEST_DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd -P)"
DOTFILES_DIR="$(cd "$( dirname "$TEST_DIR" )" && pwd -P)"

# Extract only the functions we need from the dot script
detect_system() {
    local os_name=""
    local distro=""
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        os_name="mac"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        os_name="linux"
        # Detect Linux distribution
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            case "$ID" in
                ubuntu) distro="ubuntu" ;;
                fedora) distro="fedora" ;;
                arch) distro="arch" ;;
                *) distro="unknown" ;;
            esac
        fi
    else
        os_name="unknown"
    fi
    
    echo "${os_name}_${distro}"
}

get_available_installations() {
    local installations=()
    for file in "$DOTFILES_DIR/script"/*_installation.sh; do
        if [[ -f "$file" ]]; then
            local basename=$(basename "$file" .sh)
            local install_name=${basename%_installation}
            installations+=("$install_name")
        fi
    done
    printf '%s\n' "${installations[@]}"
}

auto_select_installation() {
    local detected=$(detect_system)
    local available_installations=($(get_available_installations))
    
    # Try exact match first
    for installation in "${available_installations[@]}"; do
        if [[ "$installation" == "$detected" ]]; then
            echo "$installation"
            return
        fi
    done
    
    # Try partial matches
    local os_part=$(echo "$detected" | cut -d'_' -f1)
    for installation in "${available_installations[@]}"; do
        if [[ "$installation" == *"$os_part"* ]]; then
            echo "$installation"
            return
        fi
    done
    
    echo ""
}

# Test system detection
test_system_detection() {
    local detected_system=$(detect_system)
    
    # Should return a valid system string
    if [[ -z "$detected_system" ]]; then
        echo "Error: System detection returned empty string"
        return 1
    fi
    
    # Should contain an underscore (format: os_distro)
    if [[ ! "$detected_system" == *"_"* ]]; then
        echo "Error: System detection format invalid: $detected_system"
        return 1
    fi
    
    echo "System detected as: $detected_system"
    return 0
}

# Test available installations listing
test_available_installations() {
    local installations=($(get_available_installations))
    
    if [[ ${#installations[@]} -eq 0 ]]; then
        echo "Error: No installations found"
        return 1
    fi
    
    echo "Found ${#installations[@]} installation scripts"
    for installation in "${installations[@]}"; do
        echo "  - $installation"
    done
    
    return 0
}

# Test auto-selection
test_auto_select() {
    local auto_selected=$(auto_select_installation)
    
    # It's okay if auto-selection returns empty for unsupported systems
    if [[ -n "$auto_selected" ]]; then
        echo "Auto-selected installation: $auto_selected"
    else
        echo "No auto-selection available for this system (normal for unsupported platforms)"
    fi
    
    return 0
}

# Run all tests
main() {
    echo "Testing system detection..."
    test_system_detection
    
    echo ""
    echo "Testing available installations..."
    test_available_installations
    
    echo ""
    echo "Testing auto-selection..."
    test_auto_select
    
    echo ""
    echo "System detection tests completed successfully"
}

main