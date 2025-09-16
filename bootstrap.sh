#!/bin/bash

source "./script/common/log.sh"

# Display ASCII art logo
show_logo() {
    local logo_file="./art/logo"
    if [[ -f "$logo_file" ]]; then
        echo ""
        # Display logo in blue color
        while IFS= read -r line; do
            printf "${BLUE}%s${RESET}\n" "$line"
        done < "$logo_file"
        echo ""
    fi
}

# Show the logo
show_logo

# Run interactive dotfiles setup
./bin/dot -i

success "✨✨ -- Dotfiles installation completed successfully! -- ✨✨"