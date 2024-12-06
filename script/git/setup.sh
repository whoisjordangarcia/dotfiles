#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "$SCRIPT_DIR/../common/log.sh"

if [ ! -d "~/git" ]; then
	mkdir ~/dev
fi
