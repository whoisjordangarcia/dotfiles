package detector

import (
	"runtime"
	"testing"
)

func TestDetectSystem(t *testing.T) {
	result := Detect()

	if result.OS == "" {
		t.Error("OS should not be empty")
	}

	switch runtime.GOOS {
	case "darwin":
		if result.OS != "mac" {
			t.Errorf("OS = %q, want 'mac' on darwin", result.OS)
		}
		if result.System != "mac" {
			t.Errorf("System = %q, want 'mac' on darwin", result.System)
		}
	case "linux":
		if result.OS != "linux" {
			t.Errorf("OS = %q, want 'linux' on linux", result.OS)
		}
		if result.Distro == "" {
			t.Error("Distro should not be empty on linux")
		}
	}
}

func TestParseOSRelease(t *testing.T) {
	content := `NAME="Arch Linux"
ID=arch
PRETTY_NAME="Arch Linux"
`
	distro := parseOSReleaseContent(content)
	if distro != "arch" {
		t.Errorf("distro = %q, want 'arch'", distro)
	}
}

func TestParseOSReleaseUbuntu(t *testing.T) {
	content := `NAME="Ubuntu"
VERSION="22.04.3 LTS (Jammy Jellyfish)"
ID=ubuntu
`
	distro := parseOSReleaseContent(content)
	if distro != "ubuntu" {
		t.Errorf("distro = %q, want 'ubuntu'", distro)
	}
}

func TestParseOSReleaseFedora(t *testing.T) {
	content := `NAME="Fedora Linux"
ID=fedora
`
	distro := parseOSReleaseContent(content)
	if distro != "fedora" {
		t.Errorf("distro = %q, want 'fedora'", distro)
	}
}
