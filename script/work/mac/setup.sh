#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"

git config --global user.email "jordan.garcia@labcorp.com"

### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
export PATH="/Users/jordan.garcia/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)

info "dummy work shell"
