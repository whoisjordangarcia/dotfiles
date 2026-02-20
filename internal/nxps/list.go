package nxps

import (
	"fmt"
	"strings"
	"time"

	"github.com/charmbracelet/lipgloss"
	"github.com/whoisjordangarcia/dotfiles/internal/process"
	"github.com/whoisjordangarcia/dotfiles/internal/tui/theme"
)

var (
	headerBox = lipgloss.NewStyle().
			Border(lipgloss.ThickBorder()).
			BorderForeground(theme.Highlight).
			Padding(0, 2)

	groupHeader = lipgloss.NewStyle().
			Foreground(theme.Cyan).
			Bold(true)

	groupBorderTop = lipgloss.NewStyle().
			Foreground(theme.Dim)

	groupBorderMid = lipgloss.NewStyle().
			Foreground(theme.Dim)

	groupBorderBot = lipgloss.NewStyle().
			Foreground(theme.Dim)

	pidStyle = lipgloss.NewStyle().
			Foreground(theme.Muted).
			Width(7)

	serviceStyle = lipgloss.NewStyle().
			Foreground(theme.White)

	emptyStyle = lipgloss.NewStyle().
			Foreground(theme.Muted).
			Italic(true).
			Padding(1, 2)

	hintStyle = lipgloss.NewStyle().
			Foreground(theme.Muted)
)

// PrintListView renders a non-interactive styled list of running services.
func PrintListView(groups []process.WorktreeGroup) string {
	if len(groups) == 0 {
		return emptyStyle.Render("No node services running.") + "\n" +
			hintStyle.Render("  Run nxps again to refresh.") + "\n"
	}

	var b strings.Builder

	// Header
	title := theme.TitleAccent.Render("  ") +
		theme.Title.Render("Node Services") + "  " +
		theme.Subtitle.Render(time.Now().Format("15:04:05"))
	b.WriteString(headerBox.Render(title))
	b.WriteString("\n\n")

	// Groups
	globalIdx := 0
	for _, group := range groups {
		icon := "📂"
		if group.Name == "background" {
			icon = "⚙️ "
		}

		b.WriteString(groupBorderTop.Render("╭─ "))
		b.WriteString(groupHeader.Render(fmt.Sprintf("%s %s", icon, group.Name)))
		b.WriteString("\n")

		for _, proc := range group.Processes {
			globalIdx++
			b.WriteString(groupBorderMid.Render("│  "))
			b.WriteString(theme.Badge.Render(fmt.Sprintf("%2d)", globalIdx)))
			b.WriteString(" ")
			b.WriteString(pidStyle.Render(fmt.Sprintf("%d", proc.PID)))
			b.WriteString(serviceStyle.Render(proc.Service))
			b.WriteString("\n")
		}

		b.WriteString(groupBorderBot.Render("╰" + strings.Repeat("─", 60)))
		b.WriteString("\n\n")
	}

	b.WriteString(hintStyle.Render("  nxps → interactive TUI"))
	b.WriteString("\n")

	return b.String()
}
