package process

import (
	"fmt"
	"strings"
)

// ServiceKind classifies a discovered node process.
type ServiceKind string

const (
	KindNxServe        ServiceKind = "nx"
	KindStorybook      ServiceKind = "storybook"
	KindMCPServer      ServiceKind = "mcp"
	KindLanguageServer ServiceKind = "lsp"
)

// NodeProcess represents a single discovered node/nx process.
type NodeProcess struct {
	PID       int
	Service   string      // e.g. "nx:my-app", "storybook", "mcp:cursor-server"
	Kind      ServiceKind // category for display styling
	Worktree  string      // resolved worktree name or "background"
	Ports     []int       // listening TCP ports (may be empty)
	MemoryKB  int         // resident set size in KB (0 if unknown)
	Uptime    string      // elapsed time string from ps (e.g. "02:13:45")
	RawArgs   string      // full process args from ps
}

// PortsString returns a display string for the process's listening ports.
func (p NodeProcess) PortsString() string {
	if len(p.Ports) == 0 {
		return ""
	}
	parts := make([]string, len(p.Ports))
	for i, port := range p.Ports {
		parts[i] = fmt.Sprintf(":%d", port)
	}
	return strings.Join(parts, ",")
}

// MemoryString returns a human-readable memory string (e.g. "42 MB").
func (p NodeProcess) MemoryString() string {
	if p.MemoryKB <= 0 {
		return ""
	}
	mb := float64(p.MemoryKB) / 1024
	if mb >= 1024 {
		return fmt.Sprintf("%.1f GB", mb/1024)
	}
	if mb >= 10 {
		return fmt.Sprintf("%.0f MB", mb)
	}
	return fmt.Sprintf("%.1f MB", mb)
}

// Hyperlink wraps text in an OSC 8 terminal hyperlink escape sequence.
func Hyperlink(url, text string) string {
	return fmt.Sprintf("\033]8;;%s\033\\%s\033]8;;\033\\", url, text)
}

// PortsHyperlinks returns port strings as clickable localhost links.
func (p NodeProcess) PortsHyperlinks() string {
	if len(p.Ports) == 0 {
		return ""
	}
	parts := make([]string, len(p.Ports))
	for i, port := range p.Ports {
		label := fmt.Sprintf(":%d", port)
		url := fmt.Sprintf("http://localhost:%d", port)
		parts[i] = Hyperlink(url, label)
	}
	return strings.Join(parts, ",")
}

// WorktreeGroup is an ordered group of processes sharing a worktree.
type WorktreeGroup struct {
	Name      string
	Processes []NodeProcess
}
