package selector

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/whoisjordangarcia/dotfiles/internal/installer"
	"github.com/whoisjordangarcia/dotfiles/internal/tui/theme"
)

const logo = `  ▄▄█▀▀██▄   ██            ▄██
▄██▀    ▀██▄ ██             ██
██▀      ▀███████  ▄██▀██▄  ██▄████▄ ▀███  ▀███ ▀████████▄
██        ██ ██   ██▀   ▀██ ██    ▀██  ██    ██   ██    ██
██▄      ▄██ ██   ██     ██ ██     ██  ██    ██   ██    ██
▀██▄    ▄██▀ ██   ██▄   ▄██ ██▄   ▄██  ██    ██   ██    ██
  ▀▀████▀▀   ▀████ ▀█████▀  █▀█████▀   ▀████▀███▄████  ████▄`

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
	width      int
	height     int
}

// New creates a new module selector model.
func New(system string, components []installer.Component) Model {
	selected := make([]bool, len(components))
	for i := range selected {
		selected[i] = true
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
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
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
		case " ", "x":
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

	// Logo
	b.WriteString(theme.Logo.Render(logo))
	b.WriteString("\n\n")

	// Header
	selectedCount := 0
	for _, s := range m.selected {
		if s {
			selectedCount++
		}
	}

	header := theme.Title.Render("  Module Selection") + "  " +
		theme.Badge.Render(fmt.Sprintf("[%d/%d]", selectedCount, len(m.components))) + "  " +
		theme.Subtitle.Render(m.system)
	b.WriteString(header)
	b.WriteString("\n")
	b.WriteString(theme.HelpSep.Render("  " + strings.Repeat("─", 50)))
	b.WriteString("\n\n")

	// Module list
	for i, comp := range m.components {
		var line string

		if m.cursor == i {
			cursor := theme.CursorStyle.Render("❯ ")
			checkbox := theme.Unselected.Render("○")
			if m.selected[i] {
				checkbox = theme.Selected.Render("●")
			}
			name := theme.ActiveItem.Render(comp.Name)
			line = fmt.Sprintf("  %s%s  %s", cursor, checkbox, name)
		} else {
			checkbox := theme.Unselected.Render("○")
			if m.selected[i] {
				checkbox = theme.Selected.Render("●")
			}
			name := comp.Name
			if m.selected[i] {
				name = lipgloss.NewStyle().Foreground(theme.White).Render(name)
			} else {
				name = theme.Unselected.Render(name)
			}
			line = fmt.Sprintf("    %s  %s", checkbox, name)
		}

		b.WriteString(line + "\n")
	}

	// Help bar
	b.WriteString("\n")
	b.WriteString(theme.HelpSep.Render("  " + strings.Repeat("─", 50)))
	b.WriteString("\n")

	helpItems := []struct{ key, desc string }{
		{"space", "toggle"},
		{"a", "all"},
		{"n", "none"},
		{"↵", "install"},
		{"q", "quit"},
	}
	var helpParts []string
	for _, h := range helpItems {
		helpParts = append(helpParts,
			theme.HelpKey.Render(h.key)+theme.HelpValue.Render(" "+h.desc))
	}
	help := "  " + strings.Join(helpParts, theme.HelpSep.Render(" · "))
	b.WriteString(help)

	return b.String()
}
