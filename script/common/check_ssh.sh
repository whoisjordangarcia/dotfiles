#!/bin/bash

# check_github_ssh - Reports whether SSH access to GitHub works. Advisory only.
# Source this file and call check_github_ssh from any setup script.

check_github_ssh() {
    local ssh_output
    ssh_output=$(ssh -T -o ConnectTimeout=5 -o BatchMode=yes git@github.com 2>&1 || true)

    if echo "$ssh_output" | grep -q "successfully authenticated"; then
        success "GitHub SSH access confirmed"
        return 0
    fi

    # Deliberately NOT fatal. boot.sh clones over HTTPS precisely so a fresh,
    # keyless machine can bootstrap, and the `ssh` component — ordered before
    # every component that needs SSH (e.g. `notes`) — generates the key and walks
    # you through adding it to GitHub. Aborting here deadlocked a new machine:
    # the install refused to run the one thing that fixes its own precondition.
    warn "GitHub SSH not working yet — the 'ssh' component will set up a key"
    step "Verify afterwards:  ssh -T git@github.com"
    return 0
}
