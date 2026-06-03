#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "$SCRIPT_DIR/script/common/log.sh"

# Check for --reconfigure flag
if [[ "$1" == "--reconfigure" ]]; then
	./bin/dot --reconfigure
else
	# Run dotfiles setup (will use existing config if available, or prompt if not)
	./bin/dot
fi

echo "✨ Dotfiles installation completed successfully!"
