package theme

import "github.com/charmbracelet/lipgloss"

var (
	// Brand colors
	Blue      = lipgloss.Color("#5B9BD5")
	Cyan      = lipgloss.Color("#56CCF2")
	Green     = lipgloss.Color("#6BCB77")
	Red       = lipgloss.Color("#FF6B6B")
	Yellow    = lipgloss.Color("#FFD93D")
	Purple    = lipgloss.Color("#C084FC")
	Magenta   = lipgloss.Color("#F472B6")
	Muted     = lipgloss.Color("#555555")
	Dim       = lipgloss.Color("#3A3A3A")
	White     = lipgloss.Color("#FAFAFA")
	BgSubtle  = lipgloss.Color("#1A1A2E")
	BgPanel   = lipgloss.Color("#16213E")
	Highlight = lipgloss.Color("#0F3460")

	// Logo style
	Logo = lipgloss.NewStyle().
		Foreground(Purple).
		Bold(true)

	// Title styles
	Title = lipgloss.NewStyle().
		Bold(true).
		Foreground(Cyan)

	TitleAccent = lipgloss.NewStyle().
			Bold(true).
			Foreground(Purple)

	Subtitle = lipgloss.NewStyle().
			Foreground(Muted).
			Italic(true)

	// Status styles
	Success = lipgloss.NewStyle().
		Foreground(Green).
		Bold(true)

	Error = lipgloss.NewStyle().
		Foreground(Red).
		Bold(true)

	Warning = lipgloss.NewStyle().
		Foreground(Yellow)

	// Selection styles
	Selected = lipgloss.NewStyle().
			Foreground(Green).
			Bold(true)

	Unselected = lipgloss.NewStyle().
			Foreground(Muted)

	ActiveItem = lipgloss.NewStyle().
			Foreground(White).
			Bold(true)

	CursorStyle = lipgloss.NewStyle().
			Foreground(Cyan).
			Bold(true)

	// Spinner
	Spinner = lipgloss.NewStyle().
		Foreground(Purple)

	// Panel border
	Panel = lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(Highlight).
		Padding(1, 2)

	// Help bar
	HelpKey = lipgloss.NewStyle().
		Foreground(Purple).
		Bold(true)

	HelpSep = lipgloss.NewStyle().
		Foreground(Dim)

	HelpValue = lipgloss.NewStyle().
			Foreground(Muted)

	// Progress bar
	ProgressFilled = lipgloss.NewStyle().
			Foreground(Green)

	ProgressEmpty = lipgloss.NewStyle().
			Foreground(Dim)

	// Counter badge
	Badge = lipgloss.NewStyle().
		Foreground(Cyan).
		Bold(true)

	// Panel styles for runner side-by-side layout
	PanelBorder = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(Highlight).
			Padding(0, 1)

	PanelTitle = lipgloss.NewStyle().
			Foreground(Muted).
			Italic(true)
)

// ProgressBar renders a progress bar with the given width and percentage.
func ProgressBar(width int, percent float64) string {
	filled := int(float64(width) * percent)
	if filled > width {
		filled = width
	}
	empty := width - filled
	bar := ProgressFilled.Render(repeatStr("█", filled)) +
		ProgressEmpty.Render(repeatStr("░", empty))
	return bar
}

func repeatStr(s string, n int) string {
	if n <= 0 {
		return ""
	}
	result := ""
	for i := 0; i < n; i++ {
		result += s
	}
	return result
}
