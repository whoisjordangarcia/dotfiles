package runner

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/whoisjordangarcia/dotfiles/internal/installer"
	"github.com/whoisjordangarcia/dotfiles/internal/tui/theme"
)

type componentDoneMsg struct {
	index  int
	output string
	err    error
}

// Model is the Bubble Tea model for the installation runner.
type Model struct {
	components []installer.Component
	runner     *installer.Runner
	current    int
	results    []result
	spinner    spinner.Model
	viewport   viewport.Model
	done       bool
	width      int
	height     int
}

type result struct {
	done    bool
	success bool
	output  string
	err     error
}

// New creates a new installation runner model.
func New(components []installer.Component, r *installer.Runner) Model {
	s := spinner.New()
	s.Spinner = spinner.MiniDot
	s.Style = theme.Spinner

	vp := viewport.New(80, 10)

	results := make([]result, len(components))

	return Model{
		components: components,
		runner:     r,
		results:    results,
		spinner:    s,
		viewport:   vp,
	}
}

func (m Model) Init() tea.Cmd {
	return tea.Batch(
		m.spinner.Tick,
		m.runComponent(0),
	)
}

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmds []tea.Cmd

	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c", "q":
			return m, tea.Quit
		}

	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		headerHeight := len(m.components) + 10
		vpHeight := m.height - headerHeight
		if vpHeight < 5 {
			vpHeight = 5
		}
		m.viewport.Width = m.width - 4
		m.viewport.Height = vpHeight

	case spinner.TickMsg:
		var cmd tea.Cmd
		m.spinner, cmd = m.spinner.Update(msg)
		cmds = append(cmds, cmd)

	case componentDoneMsg:
		m.results[msg.index] = result{
			done:    true,
			success: msg.err == nil,
			output:  msg.output,
			err:     msg.err,
		}

		m.viewport.SetContent(msg.output)
		m.viewport.GotoBottom()

		m.current++

		if m.current >= len(m.components) {
			m.done = true
			return m, nil
		}
		cmds = append(cmds, m.runComponent(m.current))
	}

	var cmd tea.Cmd
	m.viewport, cmd = m.viewport.Update(msg)
	cmds = append(cmds, cmd)

	return m, tea.Batch(cmds...)
}

func (m Model) View() string {
	var b strings.Builder

	// Title
	b.WriteString(theme.TitleAccent.Render("  ⚡ "))
	b.WriteString(theme.Title.Render("Installing dotfiles"))
	b.WriteString("\n\n")

	// Progress info
	completed := 0
	failed := 0
	for _, r := range m.results {
		if r.done {
			completed++
			if !r.success {
				failed++
			}
		}
	}

	total := len(m.components)
	percent := float64(completed) / float64(total)

	// Progress bar
	barWidth := 40
	if m.width > 60 {
		barWidth = m.width - 30
	}
	progressLabel := theme.Badge.Render(fmt.Sprintf("  %d/%d", completed, total))
	bar := theme.ProgressBar(barWidth, percent)
	b.WriteString("  " + bar + progressLabel + "\n\n")

	// Component list
	for i, comp := range m.components {
		var icon string
		switch {
		case m.results[i].done && m.results[i].success:
			icon = theme.Success.Render(" ✓ ")
		case m.results[i].done && !m.results[i].success:
			icon = theme.Error.Render(" ✗ ")
		case i == m.current && !m.done:
			icon = " " + m.spinner.View() + " "
		default:
			icon = theme.Unselected.Render(" · ")
		}

		name := theme.Unselected.Render(comp.Name)
		if m.results[i].done && m.results[i].success {
			name = theme.Success.Render(comp.Name)
		} else if m.results[i].done && !m.results[i].success {
			name = theme.Error.Render(comp.Name)
		} else if i == m.current && !m.done {
			name = theme.ActiveItem.Render(comp.Name)
		}

		b.WriteString(fmt.Sprintf("  %s %s\n", icon, name))
	}

	// Output viewport
	b.WriteString("\n")
	w := m.width
	if w < 40 {
		w = 40
	}
	outputLabel := theme.Subtitle.Render("  output ")
	lineWidth := w - 12
	if lineWidth < 10 {
		lineWidth = 10
	}
	b.WriteString(outputLabel + theme.HelpSep.Render(strings.Repeat("─", lineWidth)) + "\n")
	b.WriteString("  " + m.viewport.View() + "\n")

	// Summary when done
	if m.done {
		b.WriteString("\n")
		succeeded := completed - failed

		var summaryParts []string
		if succeeded > 0 {
			summaryParts = append(summaryParts, theme.Success.Render(fmt.Sprintf("✓ %d succeeded", succeeded)))
		}
		if failed > 0 {
			summaryParts = append(summaryParts, theme.Error.Render(fmt.Sprintf("✗ %d failed", failed)))
		}

		b.WriteString("  " + theme.TitleAccent.Render("⚡ Done! ") + strings.Join(summaryParts, "  ") + "\n\n")
		b.WriteString("  " + theme.HelpKey.Render("q") + theme.HelpValue.Render(" quit"))
	}

	return b.String()
}

func (m *Model) runComponent(index int) tea.Cmd {
	comp := m.components[index]
	runner := m.runner

	return func() tea.Msg {
		var output strings.Builder
		err := runner.RunComponent(comp.Name, &output)

		return componentDoneMsg{
			index:  index,
			output: output.String(),
			err:    err,
		}
	}
}
