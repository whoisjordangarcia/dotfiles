package process

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
	RawArgs   string      // full process args from ps
}

// WorktreeGroup is an ordered group of processes sharing a worktree.
type WorktreeGroup struct {
	Name      string
	Processes []NodeProcess
}
