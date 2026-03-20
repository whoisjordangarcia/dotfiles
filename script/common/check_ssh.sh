#!/bin/bash

# check_github_ssh - Verifies SSH access to GitHub and prints fix steps if it fails.
# Source this file and call check_github_ssh from any setup script.

check_github_ssh() {
    local ssh_output
    ssh_output=$(ssh -T -o ConnectTimeout=5 -o BatchMode=yes git@github.com 2>&1 || true)

    if echo "$ssh_output" | grep -q "successfully authenticated"; then
        success "GitHub SSH access confirmed"
        return 0
    fi

    warn "GitHub SSH authentication failed"
    info ""
    info "To fix this, follow these steps:"
    step "Check if a key is loaded:  ssh-add -l"
    step "If no keys, add yours:     ssh-add ~/.ssh/id_ed25519"
    step "If no key exists, create:  ssh-keygen -t ed25519 -C \"your@email.com\""
    step "Add public key to GitHub:  cat ~/.ssh/id_ed25519.pub"
    step "                           https://github.com/settings/keys"
    step "Verify connection:         ssh -T git@github.com"
    info ""
    fail "SSH check failed — fix GitHub SSH access and re-run"
}
