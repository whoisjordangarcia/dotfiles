package installer

import (
	"os"
	"path/filepath"
	"testing"
)

func TestParseComponents(t *testing.T) {
	dir := t.TempDir()
	scriptDir := filepath.Join(dir, "script")
	os.MkdirAll(scriptDir, 0755)

	content := `#!/bin/bash
source ./script/common/log.sh

component_installation=(
	apps/arch
	# code
	git
	node
	lazygit/linux
	# essentials
	zsh
	vim
	tmux
)

for component in "${component_installation[@]}"; do
	section "$component"
done
`
	err := os.WriteFile(filepath.Join(scriptDir, "linux_arch_installation.sh"), []byte(content), 0644)
	if err != nil {
		t.Fatal(err)
	}

	components, err := ParseComponents(dir, "linux_arch")
	if err != nil {
		t.Fatalf("ParseComponents failed: %v", err)
	}

	expected := []string{"apps/arch", "git", "node", "lazygit/linux", "zsh", "vim", "tmux"}
	if len(components) != len(expected) {
		t.Fatalf("got %d components, want %d: %v", len(components), len(expected), components)
	}

	for i, c := range components {
		if c.Name != expected[i] {
			t.Errorf("component[%d] = %q, want %q", i, c.Name, expected[i])
		}
	}
}

func TestParseComponentsCommentedOut(t *testing.T) {
	dir := t.TempDir()
	scriptDir := filepath.Join(dir, "script")
	os.MkdirAll(scriptDir, 0755)

	content := `#!/bin/bash
component_installation=(
	git
	#zsh
	tmux
	#vim
)
`
	os.WriteFile(filepath.Join(scriptDir, "mac_installation.sh"), []byte(content), 0644)

	components, err := ParseComponents(dir, "mac")
	if err != nil {
		t.Fatalf("ParseComponents failed: %v", err)
	}

	expected := []string{"git", "tmux"}
	if len(components) != len(expected) {
		t.Fatalf("got %d components, want %d: %v", len(components), len(expected), components)
	}
}

func TestParseComponentsMissingScript(t *testing.T) {
	dir := t.TempDir()
	_, err := ParseComponents(dir, "nonexistent")
	if err == nil {
		t.Error("expected error for missing script")
	}
}
