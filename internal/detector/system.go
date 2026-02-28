package detector

import (
	"os"
	"runtime"
	"strings"
)

type DetectedSystem struct {
	OS     string // "mac" or "linux"
	Distro string // "arch", "ubuntu", "fedora", "" (empty on mac)
	System string // Combined: "mac", "linux_arch", "linux_ubuntu", etc.
}

func Detect() DetectedSystem {
	result := DetectedSystem{}

	switch runtime.GOOS {
	case "darwin":
		result.OS = "mac"
		result.System = "mac"
	case "linux":
		result.OS = "linux"
		result.Distro = detectLinuxDistro()
		if result.Distro != "" {
			result.System = "linux_" + result.Distro
		} else {
			result.System = "linux"
		}
	default:
		result.OS = "unknown"
		result.System = "unknown"
	}

	return result
}

func detectLinuxDistro() string {
	data, err := os.ReadFile("/etc/os-release")
	if err != nil {
		return "unknown"
	}
	return parseOSReleaseContent(string(data))
}

func parseOSReleaseContent(content string) string {
	for _, line := range strings.Split(content, "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "ID=") {
			value := strings.TrimPrefix(line, "ID=")
			value = strings.Trim(value, `"'`)
			return value
		}
	}
	return "unknown"
}
