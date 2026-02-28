package process

import (
	"os/exec"
	"regexp"
	"strconv"
	"strings"
	"sync"
)

// CommandRunner abstracts shell command execution for testability.
type CommandRunner interface {
	Run(name string, args ...string) (string, error)
}

// ExecRunner is the real implementation that shells out.
type ExecRunner struct{}

func (ExecRunner) Run(name string, args ...string) (string, error) {
	out, err := exec.Command(name, args...).Output()
	return string(out), err
}

// Collector discovers running node/nx processes.
type Collector struct {
	Runner   CommandRunner
	HomePath string // e.g. "/Users/nest"
}

// pattern matches the process kinds we care about
var processPatterns = []struct {
	re   *regexp.Regexp
	kind ServiceKind
	// extract returns the service display name from the matched args line
	extract func(args string, homePath string) string
}{
	{
		re:   regexp.MustCompile(`nx serve\s+(\S+)`),
		kind: KindNxServe,
		extract: func(args string, _ string) string {
			m := regexp.MustCompile(`nx serve\s+(\S+)`).FindStringSubmatch(args)
			if len(m) > 1 {
				return "nx:" + m[1]
			}
			return "nx:unknown"
		},
	},
	{
		re:   regexp.MustCompile(`storybook`),
		kind: KindStorybook,
		extract: func(_ string, _ string) string {
			return "storybook"
		},
	},
	{
		re:   regexp.MustCompile(`mcp-server`),
		kind: KindMCPServer,
		extract: func(args string, homePath string) string {
			// Extract meaningful name: strip home path prefix, isolate package/script name
			cleaned := strings.ReplaceAll(args, homePath+"/", "")
			// Try to find the mcp-server package name
			if idx := strings.Index(cleaned, "mcp-server"); idx >= 0 {
				rest := cleaned[idx:]
				parts := strings.Fields(rest)
				if len(parts) > 0 {
					return "mcp:" + parts[0]
				}
			}
			return "mcp:unknown"
		},
	},
	{
		re:   regexp.MustCompile(`language-server`),
		kind: KindLanguageServer,
		extract: func(args string, _ string) string {
			// Extract the server binary name
			parts := strings.Fields(args)
			for _, p := range parts {
				if strings.Contains(p, "language-server") {
					segments := strings.Split(p, "/")
					return "lsp:" + segments[len(segments)-1]
				}
			}
			return "lsp:unknown"
		},
	},
}

// Collect discovers running node/nx processes by parsing `ps` output and
// concurrently resolving worktrees via `lsof`.
func (c *Collector) Collect() ([]NodeProcess, error) {
	psOut, err := c.Runner.Run("ps", "-eo", "pid,args")
	if err != nil {
		return nil, err
	}

	// Parse ps output into candidate processes
	var procs []NodeProcess
	for _, line := range strings.Split(psOut, "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "PID") {
			continue
		}

		// Skip grep processes
		if strings.Contains(line, "grep") {
			continue
		}

		for _, pat := range processPatterns {
			if pat.re.MatchString(line) {
				pid, args := parsePSLine(line)
				if pid <= 0 {
					break
				}
				procs = append(procs, NodeProcess{
					PID:     pid,
					Kind:    pat.kind,
					Service: pat.extract(args, c.HomePath),
					RawArgs: args,
				})
				break // first match wins
			}
		}
	}

	// Resolve worktrees concurrently with bounded parallelism
	c.resolveWorktrees(procs)

	return procs, nil
}

// parsePSLine extracts PID and args from a ps output line.
func parsePSLine(line string) (int, string) {
	line = strings.TrimSpace(line)
	fields := strings.SplitN(line, " ", 2)
	if len(fields) < 2 {
		return 0, ""
	}
	pid, err := strconv.Atoi(strings.TrimSpace(fields[0]))
	if err != nil {
		return 0, ""
	}
	return pid, strings.TrimSpace(fields[1])
}

const maxLsofWorkers = 8

func (c *Collector) resolveWorktrees(procs []NodeProcess) {
	sem := make(chan struct{}, maxLsofWorkers)
	var wg sync.WaitGroup

	for i := range procs {
		// MCP servers and language servers are always "background"
		if procs[i].Kind == KindMCPServer || procs[i].Kind == KindLanguageServer {
			procs[i].Worktree = "background"
			continue
		}

		wg.Add(1)
		sem <- struct{}{} // acquire
		go func(idx int) {
			defer wg.Done()
			defer func() { <-sem }() // release

			procs[idx].Worktree = c.resolveWorktree(procs[idx].PID)
		}(i)
	}
	wg.Wait()
}

func (c *Collector) resolveWorktree(pid int) string {
	out, err := c.Runner.Run("lsof", "-p", strconv.Itoa(pid), "-Fn")
	if err != nil {
		return "unknown"
	}

	for _, line := range strings.Split(out, "\n") {
		if !strings.HasPrefix(line, "n/") {
			continue
		}
		path := strings.TrimPrefix(line, "n")
		path = trimToProjectRoot(path)

		if path == "" {
			continue
		}

		return c.shortenPath(path)
	}
	return "unknown"
}

// trimToProjectRoot strips trailing path segments like /.nx/*, /apps/*, /node_modules/*, /dist/*
func trimToProjectRoot(path string) string {
	for _, suffix := range []string{"/.nx/", "/apps/", "/node_modules/", "/dist/"} {
		if idx := strings.Index(path, suffix); idx >= 0 {
			path = path[:idx]
		}
	}
	return path
}

func (c *Collector) shortenPath(path string) string {
	worktreePrefix := c.HomePath + "/projects/nest/.worktrees/"
	repoRoot := c.HomePath + "/projects/nest"

	if strings.HasPrefix(path, worktreePrefix) {
		return strings.TrimPrefix(path, worktreePrefix)
	}
	if path == repoRoot || strings.HasPrefix(path, repoRoot+"/") {
		return "repo-root"
	}
	return strings.TrimPrefix(path, c.HomePath+"/")
}

// GroupByWorktree groups processes by worktree name, preserving first-seen order.
func GroupByWorktree(procs []NodeProcess) []WorktreeGroup {
	seen := map[string]int{}
	var groups []WorktreeGroup

	for _, p := range procs {
		if idx, ok := seen[p.Worktree]; ok {
			groups[idx].Processes = append(groups[idx].Processes, p)
		} else {
			seen[p.Worktree] = len(groups)
			groups = append(groups, WorktreeGroup{
				Name:      p.Worktree,
				Processes: []NodeProcess{p},
			})
		}
	}
	return groups
}
