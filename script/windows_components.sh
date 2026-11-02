#!/bin/bash
#
# Single source of truth for the Windows (Git Bash) component list.
# Sourced by windows_installation.sh and bin/dot (module selection menu) —
# edit here, never in the installer.
#
# Side-effect-free: it only defines component_installation. Add a component here
# in the same change that adds its script/<component>/setup.sh (windows_test.sh
# enforces it). Design: docs/superpowers/specs/2026-11-02-windows-native-design.md

component_installation=(
	git
)
