package tui

import (
	"os"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/whoisjordangarcia/dotfiles/internal/process"
)

// Model is the root Bubble Tea model for nxps.
type Model struct {
	processList ProcessList
	collector   *process.Collector
}

// New creates the root nxps TUI model.
func New() Model {
	home, _ := os.UserHomeDir()
	return Model{
		processList: NewProcessList(),
		collector: &process.Collector{
			Runner:   process.ExecRunner{},
			HomePath: home,
		},
	}
}

func (m Model) Init() tea.Cmd {
	return tea.Batch(
		m.processList.Init(),
		m.collectCmd(),
	)
}

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmd tea.Cmd

	prevState := m.processList.state
	m.processList, cmd = m.processList.Update(msg)

	// If the process list transitioned to loading (user pressed 'r'), re-collect
	if m.processList.state == stateLoading && prevState != stateLoading {
		return m, tea.Batch(cmd, m.processList.Init(), m.collectCmd())
	}

	return m, cmd
}

func (m Model) View() string {
	return m.processList.View()
}

func (m Model) collectCmd() tea.Cmd {
	collector := m.collector
	return func() tea.Msg {
		procs, err := collector.Collect()
		if err != nil {
			return processesLoadedMsg{Err: err}
		}
		groups := process.GroupByWorktree(procs)
		return processesLoadedMsg{Groups: groups}
	}
}
