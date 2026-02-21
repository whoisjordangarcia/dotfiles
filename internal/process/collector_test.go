package process

import (
	"fmt"
	"testing"
)

// fakeRunner returns canned output for ps and lsof commands.
type fakeRunner struct {
	psOutput   string
	lsofByPID map[int]string
}

func (f *fakeRunner) Run(name string, args ...string) (string, error) {
	if name == "ps" {
		return f.psOutput, nil
	}
	if name == "lsof" && len(args) >= 2 {
		pid := 0
		fmt.Sscanf(args[1], "%d", &pid)
		if out, ok := f.lsofByPID[pid]; ok {
			return out, nil
		}
		return "", fmt.Errorf("no lsof data for pid %d", pid)
	}
	return "", fmt.Errorf("unexpected command: %s", name)
}

func TestCollect_NxServe(t *testing.T) {
	runner := &fakeRunner{
		psOutput: `  PID ARGS
12345 node /path/to/nx serve my-app --port=4200
12346 node /path/to/nx serve api-gateway
99999 grep nx serve`,
		lsofByPID: map[int]string{
			12345: "p12345\nfcwd\nn/Users/nest/projects/nest/.worktrees/feature-x/.nx/cache\n",
			12346: "p12346\nfcwd\nn/Users/nest/projects/nest/apps/api-gateway\n",
		},
	}

	c := &Collector{Runner: runner, HomePath: "/Users/nest"}
	procs, err := c.Collect()
	if err != nil {
		t.Fatalf("Collect() error: %v", err)
	}

	if len(procs) != 2 {
		t.Fatalf("expected 2 processes, got %d", len(procs))
	}

	if procs[0].Service != "nx:my-app" {
		t.Errorf("procs[0].Service = %q, want %q", procs[0].Service, "nx:my-app")
	}
	if procs[0].Worktree != "feature-x" {
		t.Errorf("procs[0].Worktree = %q, want %q", procs[0].Worktree, "feature-x")
	}

	if procs[1].Service != "nx:api-gateway" {
		t.Errorf("procs[1].Service = %q, want %q", procs[1].Service, "nx:api-gateway")
	}
	if procs[1].Worktree != "repo-root" {
		t.Errorf("procs[1].Worktree = %q, want %q", procs[1].Worktree, "repo-root")
	}
}

func TestCollect_BackgroundServices(t *testing.T) {
	runner := &fakeRunner{
		psOutput: `  PID ARGS
55555 node /Users/nest/.cursor/mcp-server-extension/dist/index.js
66666 node /usr/lib/typescript-language-server --stdio`,
		lsofByPID: map[int]string{},
	}

	c := &Collector{Runner: runner, HomePath: "/Users/nest"}
	procs, err := c.Collect()
	if err != nil {
		t.Fatalf("Collect() error: %v", err)
	}

	if len(procs) != 2 {
		t.Fatalf("expected 2 processes, got %d", len(procs))
	}

	if procs[0].Kind != KindMCPServer {
		t.Errorf("procs[0].Kind = %q, want %q", procs[0].Kind, KindMCPServer)
	}
	if procs[0].Worktree != "background" {
		t.Errorf("procs[0].Worktree = %q, want %q", procs[0].Worktree, "background")
	}

	if procs[1].Kind != KindLanguageServer {
		t.Errorf("procs[1].Kind = %q, want %q", procs[1].Kind, KindLanguageServer)
	}
	if procs[1].Worktree != "background" {
		t.Errorf("procs[1].Worktree = %q, want %q", procs[1].Worktree, "background")
	}
}

func TestGroupByWorktree_PreservesOrder(t *testing.T) {
	procs := []NodeProcess{
		{PID: 1, Service: "nx:app-a", Worktree: "feature-x"},
		{PID: 2, Service: "nx:app-b", Worktree: "feature-y"},
		{PID: 3, Service: "storybook", Worktree: "feature-x"},
		{PID: 4, Service: "mcp:server", Worktree: "background"},
	}

	groups := GroupByWorktree(procs)

	if len(groups) != 3 {
		t.Fatalf("expected 3 groups, got %d", len(groups))
	}

	if groups[0].Name != "feature-x" || len(groups[0].Processes) != 2 {
		t.Errorf("groups[0]: name=%q procs=%d, want feature-x/2", groups[0].Name, len(groups[0].Processes))
	}
	if groups[1].Name != "feature-y" || len(groups[1].Processes) != 1 {
		t.Errorf("groups[1]: name=%q procs=%d, want feature-y/1", groups[1].Name, len(groups[1].Processes))
	}
	if groups[2].Name != "background" || len(groups[2].Processes) != 1 {
		t.Errorf("groups[2]: name=%q procs=%d, want background/1", groups[2].Name, len(groups[2].Processes))
	}
}

func TestParsePSLine(t *testing.T) {
	tests := []struct {
		line    string
		wantPID int
		wantArg string
	}{
		{"12345 node /path/to/nx serve my-app", 12345, "node /path/to/nx serve my-app"},
		{"  999 storybook --port 6006", 999, "storybook --port 6006"},
		{"bad line", 0, ""},
	}
	for _, tt := range tests {
		pid, args := parsePSLine(tt.line)
		if pid != tt.wantPID {
			t.Errorf("parsePSLine(%q) pid = %d, want %d", tt.line, pid, tt.wantPID)
		}
		if args != tt.wantArg {
			t.Errorf("parsePSLine(%q) args = %q, want %q", tt.line, args, tt.wantArg)
		}
	}
}
