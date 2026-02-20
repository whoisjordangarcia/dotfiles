#!/bin/bash

source "./script/common/log.sh"

# Check for --reconfigure flag
if [[ "$1" == "--reconfigure" ]]; then
	./bin/dot --reconfigure
else
	# Run dotfiles setup (will use existing config if available, or prompt if not)
	./bin/dot
fi

# Build Go CLI tools (otobun, nxps) if Go is available
if command -v go &>/dev/null; then
	echo "🔨 Building Go tools..."
	make build 2>/dev/null || true
fi

echo "✨ Dotfiles installation completed successfully!"
