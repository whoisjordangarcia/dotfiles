package theme

import "github.com/charmbracelet/lipgloss"

var (
	// Brand colors
	Blue   = lipgloss.Color("#5B9BD5")
	Green  = lipgloss.Color("#6BCB77")
	Red    = lipgloss.Color("#FF6B6B")
	Yellow = lipgloss.Color("#FFD93D")
	Purple = lipgloss.Color("#C084FC")
	Muted  = lipgloss.Color("#666666")
	White  = lipgloss.Color("#FAFAFA")

	// Component styles
	Title = lipgloss.NewStyle().
		Bold(true).
		Foreground(Blue)

	Subtitle = lipgloss.NewStyle().
			Foreground(Muted)

	Success = lipgloss.NewStyle().
		Foreground(Green)

	Error = lipgloss.NewStyle().
		Foreground(Red)

	Warning = lipgloss.NewStyle().
		Foreground(Yellow)

	Selected = lipgloss.NewStyle().
			Foreground(Green).
			Bold(true)

	Unselected = lipgloss.NewStyle().
			Foreground(Muted)

	ActiveItem = lipgloss.NewStyle().
			Foreground(White).
			Bold(true)

	Spinner = lipgloss.NewStyle().
		Foreground(Purple)

	HelpKey = lipgloss.NewStyle().
		Foreground(Muted)

	HelpValue = lipgloss.NewStyle().
			Foreground(White)
)
