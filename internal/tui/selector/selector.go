package selector

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/whoisjordangarcia/dotfiles/internal/installer"
	"github.com/whoisjordangarcia/dotfiles/internal/tui/theme"
)

// Result holds the user's module selection.
type Result struct {
	Components []installer.Component
	Selected   []bool
	Confirmed  bool
}

// Model is the Bubble Tea model for the module selector screen.
type Model struct {
	components []installer.Component
	selected   []bool
	cursor     int
	system     string
	done       bool
	quitting   bool
}

// New creates a new module selector model.
func New(system string, components []installer.Component) Model {
	selected := make([]bool, len(components))
	for i := range selected {
		selected[i] = true // all selected by default
	}
	return Model{
		components: components,
		selected:   selected,
		system:     system,
	}
}

// GetResult returns the selection result after the model is done.
func (m Model) GetResult() Result {
	return Result{
		Components: m.components,
		Selected:   m.selected,
		Confirmed:  m.done && !m.quitting,
	}
}

func (m Model) Init() tea.Cmd {
	return nil
}

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c", "q":
			m.quitting = true
			return m, tea.Quit
		case "up", "k":
			if m.cursor > 0 {
				m.cursor--
			}
		case "down", "j":
			if m.cursor < len(m.components)-1 {
				m.cursor++
			}
		case " ":
			m.selected[m.cursor] = !m.selected[m.cursor]
		case "a":
			for i := range m.selected {
				m.selected[i] = true
			}
		case "n":
			for i := range m.selected {
				m.selected[i] = false
			}
		case "enter":
			m.done = true
			return m, tea.Quit
		}
	}
	return m, nil
}

func (m Model) View() string {
	if m.done || m.quitting {
		return ""
	}

	var b strings.Builder

	title := theme.Title.Render("Module Selection")
	subtitle := theme.Subtitle.Render(fmt.Sprintf("System: %s", m.system))
	b.WriteString(title + "\n")
	b.WriteString(subtitle + "\n\n")

	for i, comp := range m.components {
		cursor := "  "
		if m.cursor == i {
			cursor = theme.ActiveItem.Render("▸ ")
		}

		checkbox := theme.Unselected.Render("[ ]")
		if m.selected[i] {
			checkbox = theme.Selected.Render("[✓]")
		}

		name := comp.Name
		if m.cursor == i {
			name = theme.ActiveItem.Render(name)
		}

		b.WriteString(fmt.Sprintf("%s%s %s\n", cursor, checkbox, name))
	}

	b.WriteString("\n")
	help := lipgloss.JoinHorizontal(lipgloss.Top,
		theme.HelpKey.Render("space"),
		theme.HelpValue.Render(" toggle  "),
		theme.HelpKey.Render("a"),
		theme.HelpValue.Render(" all  "),
		theme.HelpKey.Render("n"),
		theme.HelpValue.Render(" none  "),
		theme.HelpKey.Render("enter"),
		theme.HelpValue.Render(" confirm  "),
		theme.HelpKey.Render("q"),
		theme.HelpValue.Render(" quit"),
	)
	b.WriteString(help)

	return b.String()
}
