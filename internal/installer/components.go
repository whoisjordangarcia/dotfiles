package installer

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// Component represents a single installable component parsed from
// a platform installation script.
type Component struct {
	Name string
}

var arrayRegex = regexp.MustCompile(`(?s)component_installation=\((.*?)\)`)

// ParseComponents reads the installation script for the given system
// and extracts the component_installation bash array entries.
// Commented-out entries (lines starting with #) are skipped.
func ParseComponents(dotfilesDir, system string) ([]Component, error) {
	scriptPath := filepath.Join(dotfilesDir, "script", system+"_installation.sh")
	data, err := os.ReadFile(scriptPath)
	if err != nil {
		return nil, fmt.Errorf("read installation script: %w", err)
	}

	matches := arrayRegex.FindSubmatch(data)
	if matches == nil {
		return nil, fmt.Errorf("no component_installation array found in %s", scriptPath)
	}

	var components []Component
	for _, line := range strings.Split(string(matches[1]), "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		// Skip fully commented lines
		if strings.HasPrefix(line, "#") {
			continue
		}
		// Strip inline comments
		if idx := strings.Index(line, "#"); idx > 0 {
			line = strings.TrimSpace(line[:idx])
		}
		if line != "" {
			components = append(components, Component{Name: line})
		}
	}

	return components, nil
}
