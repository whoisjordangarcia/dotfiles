package installer

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestRunComponentSuccess(t *testing.T) {
	dir := t.TempDir()

	commonDir := filepath.Join(dir, "script", "common")
	os.MkdirAll(commonDir, 0755)

	os.WriteFile(filepath.Join(commonDir, "log.sh"), []byte(`
info() { echo "$1"; }
success() { echo "OK $1"; }
section() { echo "▶ $1"; }
step() { echo "• $1"; }
debug() { :; }
user() { :; }
warn() { :; }
fail() { echo "FAIL $1"; exit 1; }
`), 0755)

	os.WriteFile(filepath.Join(commonDir, "symlink.sh"), []byte(`
link_file() { echo "link $1 -> $2"; }
`), 0755)

	compDir := filepath.Join(dir, "script", "testcomp")
	os.MkdirAll(compDir, 0755)
	os.WriteFile(filepath.Join(compDir, "setup.sh"), []byte(`
info "installing testcomp"
success "testcomp installed"
`), 0755)

	var output strings.Builder
	r := NewRunner(dir, nil)
	err := r.RunComponent("testcomp", &output)
	if err != nil {
		t.Fatalf("RunComponent failed: %v", err)
	}

	if !strings.Contains(output.String(), "testcomp installed") {
		t.Errorf("output missing expected text: %s", output.String())
	}
}

func TestRunComponentFailure(t *testing.T) {
	dir := t.TempDir()

	commonDir := filepath.Join(dir, "script", "common")
	os.MkdirAll(commonDir, 0755)
	os.WriteFile(filepath.Join(commonDir, "log.sh"), []byte(""), 0755)
	os.WriteFile(filepath.Join(commonDir, "symlink.sh"), []byte(""), 0755)

	compDir := filepath.Join(dir, "script", "failcomp")
	os.MkdirAll(compDir, 0755)
	os.WriteFile(filepath.Join(compDir, "setup.sh"), []byte(`exit 1`), 0755)

	var output strings.Builder
	r := NewRunner(dir, nil)
	err := r.RunComponent("failcomp", &output)
	if err == nil {
		t.Error("expected error for failing component")
	}
}
