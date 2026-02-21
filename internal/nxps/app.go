package nxps

import (
	"fmt"
	"os"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/whoisjordangarcia/dotfiles/internal/nxps/tui"
	"github.com/whoisjordangarcia/dotfiles/internal/process"
)

// RunTUI launches the interactive TUI.
func RunTUI() error {
	p := tea.NewProgram(tui.New(), tea.WithAltScreen())
	_, err := p.Run()
	return err
}

// PrintList collects processes and prints a non-interactive styled list.
func PrintList() error {
	home, _ := os.UserHomeDir()
	c := &process.Collector{
		Runner:   process.ExecRunner{},
		HomePath: home,
	}

	procs, err := c.Collect()
	if err != nil {
		return fmt.Errorf("collecting processes: %w", err)
	}

	groups := process.GroupByWorktree(procs)
	fmt.Print(PrintListView(groups))
	return nil
}
