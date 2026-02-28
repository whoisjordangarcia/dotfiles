package tui

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/whoisjordangarcia/dotfiles/internal/process"
	"github.com/whoisjordangarcia/dotfiles/internal/tui/theme"
)

type state int

const (
	stateLoading state = iota
	stateList
	stateKilling
	stateResults
	stateForcePrompt
)

// ProcessList is the main TUI screen showing grouped processes with selection.
type ProcessList struct {
	groups   []process.WorktreeGroup
	flatProc []process.NodeProcess // flattened for cursor indexing
	selected []bool
	cursor   int

	state    state
	spinner  spinner.Model
	killMsg  string
	results  []process.KillResult
	survivors []int

	width  int
	height int
}

// NewProcessList creates the process list view.
func NewProcessList() ProcessList {
	s := spinner.New()
	s.Spinner = spinner.MiniDot
	s.Style = theme.Spinner

	return ProcessList{
		state:   stateLoading,
		spinner: s,
	}
}

func (m *ProcessList) setGroups(groups []process.WorktreeGroup) {
	m.groups = groups
	m.flatProc = nil
	for _, g := range groups {
		m.flatProc = append(m.flatProc, g.Processes...)
	}
	m.selected = make([]bool, len(m.flatProc))
	m.cursor = 0
	m.state = stateList
}

func (m ProcessList) selectedPIDs() []int {
	var pids []int
	for i, sel := range m.selected {
		if sel {
			pids = append(pids, m.flatProc[i].PID)
		}
	}
	return pids
}

func (m ProcessList) Init() tea.Cmd {
	return m.spinner.Tick
}

func (m ProcessList) Update(msg tea.Msg) (ProcessList, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height

	case spinner.TickMsg:
		var cmd tea.Cmd
		m.spinner, cmd = m.spinner.Update(msg)
		return m, cmd

	case processesLoadedMsg:
		if msg.Err != nil {
			m.killMsg = theme.Error.Render("Error: " + msg.Err.Error())
			m.state = stateResults
			return m, nil
		}
		m.setGroups(msg.Groups)
		if len(m.flatProc) == 0 {
			m.state = stateResults
			m.killMsg = ""
		}
		return m, nil

	case killDoneMsg:
		m.results = msg.Results
		m.survivors = msg.Survivors
		if len(msg.Survivors) > 0 {
			m.state = stateForcePrompt
		} else {
			m.state = stateResults
			m.killMsg = theme.Success.Render("✓ All selected processes killed.")
		}
		return m, nil

	case forceKillDoneMsg:
		m.state = stateResults
		m.killMsg = theme.Success.Render("✓ Force killed all survivors.")
		return m, nil

	case tea.KeyMsg:
		return m.handleKey(msg)
	}

	return m, nil
}

func (m ProcessList) handleKey(msg tea.KeyMsg) (ProcessList, tea.Cmd) {
	switch m.state {
	case stateList:
		switch msg.String() {
		case "ctrl+c", "q":
			return m, tea.Quit
		case "up", "k":
			if m.cursor > 0 {
				m.cursor--
			}
		case "down", "j":
			if m.cursor < len(m.flatProc)-1 {
				m.cursor++
			}
		case " ", "x":
			if len(m.selected) > 0 {
				m.selected[m.cursor] = !m.selected[m.cursor]
			}
		case "a":
			for i := range m.selected {
				m.selected[i] = true
			}
		case "n":
			for i := range m.selected {
				m.selected[i] = false
			}
		case "enter", "d":
			pids := m.selectedPIDs()
			if len(pids) > 0 {
				m.state = stateKilling
				return m, killCmd(pids)
			}
		case "r":
			m.state = stateLoading
			return m, nil // caller handles refresh
		}

	case stateForcePrompt:
		switch msg.String() {
		case "y", "Y":
			m.state = stateKilling
			return m, forceKillCmd(m.survivors)
		case "n", "N", "q", "ctrl+c", "esc":
			m.state = stateResults
			m.killMsg = theme.Warning.Render(
				fmt.Sprintf("⚠ %d process(es) still alive.", len(m.survivors)))
			return m, nil
		}

	case stateResults:
		switch msg.String() {
		case "ctrl+c", "q":
			return m, tea.Quit
		case "r":
			m.state = stateLoading
			return m, nil
		}
	}

	return m, nil
}

func killCmd(pids []int) tea.Cmd {
	return func() tea.Msg {
		results := process.Kill(pids, process.DefaultKill)
		return killDoneMsg{
			Results:   results,
			Survivors: process.Survivors(results),
		}
	}
}

func forceKillCmd(pids []int) tea.Cmd {
	return func() tea.Msg {
		results := process.ForceKill(pids, process.DefaultKill)
		return forceKillDoneMsg{Results: results}
	}
}

func (m ProcessList) View() string {
	var b strings.Builder

	// Title
	b.WriteString(theme.TitleAccent.Render("  ⚡ "))
	b.WriteString(theme.Title.Render("nxps"))
	b.WriteString("  ")
	b.WriteString(theme.Subtitle.Render("node/nx process manager"))
	b.WriteString("\n")
	b.WriteString(theme.HelpSep.Render("  " + strings.Repeat("─", 55)))
	b.WriteString("\n\n")

	switch m.state {
	case stateLoading:
		b.WriteString("  " + m.spinner.View() + " Scanning processes...")
		b.WriteString("\n")

	case stateList:
		m.renderProcessList(&b)

	case stateKilling:
		b.WriteString("  " + m.spinner.View() + " Killing selected processes...")
		b.WriteString("\n")

	case stateForcePrompt:
		b.WriteString(theme.Warning.Render(fmt.Sprintf(
			"  ⚠ %d process(es) survived SIGTERM.", len(m.survivors))))
		b.WriteString("\n\n")
		b.WriteString("  Force kill with SIGKILL? ")
		b.WriteString(theme.HelpKey.Render("y"))
		b.WriteString(theme.HelpValue.Render("/"))
		b.WriteString(theme.HelpKey.Render("n"))
		b.WriteString("\n")

	case stateResults:
		if len(m.flatProc) == 0 && m.killMsg == "" {
			b.WriteString(theme.Subtitle.Render("  No node services running."))
			b.WriteString("\n\n")
			b.WriteString(theme.HelpValue.Render("  Press "))
			b.WriteString(theme.HelpKey.Render("r"))
			b.WriteString(theme.HelpValue.Render(" to refresh, "))
			b.WriteString(theme.HelpKey.Render("q"))
			b.WriteString(theme.HelpValue.Render(" to quit"))
			b.WriteString("\n")
		} else if m.killMsg != "" {
			b.WriteString("  " + m.killMsg)
			b.WriteString("\n\n")
			b.WriteString(theme.HelpValue.Render("  Press "))
			b.WriteString(theme.HelpKey.Render("r"))
			b.WriteString(theme.HelpValue.Render(" to refresh, "))
			b.WriteString(theme.HelpKey.Render("q"))
			b.WriteString(theme.HelpValue.Render(" to quit"))
			b.WriteString("\n")
		}
	}

	return b.String()
}

func (m ProcessList) renderProcessList(b *strings.Builder) {
	selectedCount := 0
	for _, s := range m.selected {
		if s {
			selectedCount++
		}
	}

	globalIdx := 0
	for _, group := range m.groups {
		icon := "📂"
		if group.Name == "background" {
			icon = "⚙️ "
		}

		b.WriteString(theme.HelpSep.Render("  ╭─ "))
		b.WriteString(theme.Title.Render(fmt.Sprintf("%s %s", icon, group.Name)))
		b.WriteString("\n")

		for _, proc := range group.Processes {
			isCursor := globalIdx == m.cursor
			isSelected := m.selected[globalIdx]

			b.WriteString(theme.HelpSep.Render("  │ "))

			// Cursor indicator
			if isCursor {
				b.WriteString(theme.CursorStyle.Render("❯ "))
			} else {
				b.WriteString("  ")
			}

			// Checkbox
			if isSelected {
				b.WriteString(theme.Selected.Render("● "))
			} else {
				b.WriteString(theme.Unselected.Render("○ "))
			}

			// PID
			pidStr := fmt.Sprintf("%-7d", proc.PID)
			if isCursor {
				b.WriteString(theme.ActiveItem.Render(pidStr))
			} else {
				b.WriteString(theme.Unselected.Render(pidStr))
			}

			// Service name
			if isCursor {
				b.WriteString(theme.ActiveItem.Render(proc.Service))
			} else if isSelected {
				b.WriteString(lipgloss.NewStyle().Foreground(theme.White).Render(proc.Service))
			} else {
				b.WriteString(theme.Unselected.Render(proc.Service))
			}

			b.WriteString("\n")
			globalIdx++
		}

		b.WriteString(theme.HelpSep.Render("  ╰" + strings.Repeat("─", 55)))
		b.WriteString("\n\n")
	}

	// Help bar
	b.WriteString(theme.HelpSep.Render("  " + strings.Repeat("─", 55)))
	b.WriteString("\n")

	badge := theme.Badge.Render(fmt.Sprintf("  [%d/%d selected]", selectedCount, len(m.flatProc)))
	b.WriteString(badge)
	b.WriteString("\n")

	helpItems := []struct{ key, desc string }{
		{"space", "toggle"},
		{"a", "all"},
		{"n", "none"},
		{"↵/d", "kill"},
		{"r", "refresh"},
		{"q", "quit"},
	}
	var helpParts []string
	for _, h := range helpItems {
		helpParts = append(helpParts,
			theme.HelpKey.Render(h.key)+theme.HelpValue.Render(" "+h.desc))
	}
	b.WriteString("  " + strings.Join(helpParts, theme.HelpSep.Render(" · ")))
	b.WriteString("\n")
}
