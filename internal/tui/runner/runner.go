package runner

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/whoisjordangarcia/dotfiles/internal/installer"
	"github.com/whoisjordangarcia/dotfiles/internal/tui/theme"
)

// channelWriter is an io.Writer that sends each Write call as an outputChunkMsg
// through a channel, bridging concurrent subprocess output into Bubble Tea's
// single-threaded update loop.
type channelWriter struct {
	ch chan tea.Msg
}

func (w *channelWriter) Write(p []byte) (int, error) {
	w.ch <- outputChunkMsg(string(p))
	return len(p), nil
}

// outputChunkMsg carries a chunk of streamed script output.
type outputChunkMsg string

type componentDoneMsg struct {
	index int
	err   error
}

// Model is the Bubble Tea model for the installation runner.
type Model struct {
	components []installer.Component
	runner     *installer.Runner
	current    int
	results    []result
	spinner    spinner.Model
	viewport   viewport.Model
	outputBuf  *strings.Builder
	msgCh      chan tea.Msg
	done       bool
	width      int
	height     int
}

type result struct {
	done    bool
	success bool
	err     error
}

// New creates a new installation runner model.
func New(components []installer.Component, r *installer.Runner) Model {
	s := spinner.New()
	s.Spinner = spinner.MiniDot
	s.Style = theme.Spinner

	vp := viewport.New(80, 10)

	results := make([]result, len(components))
	ch := make(chan tea.Msg, 64)

	return Model{
		components: components,
		runner:     r,
		results:    results,
		spinner:    s,
		viewport:   vp,
		outputBuf:  &strings.Builder{},
		msgCh:      ch,
	}
}

func (m Model) Init() tea.Cmd {
	return tea.Batch(
		m.spinner.Tick,
		runComponentCmd(m.components[0], m.runner, 0, m.msgCh),
		waitForMsg(m.msgCh),
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

		// Layout constants matching View():
		// title(1) + blank(1) + panels + blank(0) + progress(1) + help(1) = 4 chrome rows
		const leftPanelWidth = 28
		const chromeRows = 4
		// Panel borders consume 2 rows (top+bottom), padding 0
		const panelBorderRows = 2
		// Panel borders consume 2 cols (left+right) + padding 1 each side = 4
		const panelBorderCols = 4

		bodyHeight := m.height - chromeRows
		if bodyHeight < 5 {
			bodyHeight = 5
		}

		vpHeight := bodyHeight - panelBorderRows
		if vpHeight < 3 {
			vpHeight = 3
		}
		vpWidth := m.width - leftPanelWidth - panelBorderCols - panelBorderCols
		if vpWidth < 20 {
			vpWidth = 20
		}
		m.viewport.Width = vpWidth
		m.viewport.Height = vpHeight

	case spinner.TickMsg:
		var cmd tea.Cmd
		m.spinner, cmd = m.spinner.Update(msg)
		cmds = append(cmds, cmd)

	case outputChunkMsg:
		m.outputBuf.WriteString(string(msg))
		m.viewport.SetContent(m.outputBuf.String())
		m.viewport.GotoBottom()
		cmds = append(cmds, waitForMsg(m.msgCh))

	case componentDoneMsg:
		m.results[msg.index] = result{
			done:    true,
			success: msg.err == nil,
			err:     msg.err,
		}

		m.current++

		if m.current >= len(m.components) {
			m.done = true
			return m, nil
		}
		cmds = append(cmds, runComponentCmd(m.components[m.current], m.runner, m.current, m.msgCh))
	}

	var cmd tea.Cmd
	m.viewport, cmd = m.viewport.Update(msg)
	cmds = append(cmds, cmd)

	return m, tea.Batch(cmds...)
}

func (m Model) View() string {
	const leftPanelWidth = 28

	var b strings.Builder

	// Title
	b.WriteString(theme.TitleAccent.Render("  ⚡ "))
	b.WriteString(theme.Title.Render("Installing dotfiles"))
	b.WriteString("\n")

	// Tally completed / failed
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

	// ── Left panel: module list ──────────────────────────────
	var moduleLines []string
	for i, comp := range m.components {
		var icon string
		switch {
		case m.results[i].done && m.results[i].success:
			icon = theme.Success.Render("✓")
		case m.results[i].done && !m.results[i].success:
			icon = theme.Error.Render("✗")
		case i == m.current && !m.done:
			icon = m.spinner.View()
		default:
			icon = theme.Unselected.Render("·")
		}

		name := theme.Unselected.Render(comp.Name)
		if m.results[i].done && m.results[i].success {
			name = theme.Success.Render(comp.Name)
		} else if m.results[i].done && !m.results[i].success {
			name = theme.Error.Render(comp.Name)
		} else if i == m.current && !m.done {
			name = theme.ActiveItem.Render(comp.Name)
		}

		moduleLines = append(moduleLines, fmt.Sprintf(" %s %s", icon, name))
	}

	// Body height for both panels (terminal minus title, progress, help rows)
	bodyHeight := m.height - 4
	if bodyHeight < 5 {
		bodyHeight = 5
	}
	panelInnerHeight := bodyHeight - 2 // subtract border top+bottom

	// Pad module list to fill panel height
	for len(moduleLines) < panelInnerHeight {
		moduleLines = append(moduleLines, "")
	}
	if len(moduleLines) > panelInnerHeight {
		moduleLines = moduleLines[:panelInnerHeight]
	}

	leftContent := strings.Join(moduleLines, "\n")

	leftPanel := theme.PanelBorder.
		Width(leftPanelWidth - 4). // subtract border+padding cols
		Height(panelInnerHeight).
		BorderTop(true).
		BorderBottom(true).
		BorderLeft(true).
		BorderRight(true).
		Render(leftContent)

	// Inject panel title into the top border
	leftPanel = injectBorderTitle(leftPanel, " modules ")

	// ── Right panel: output viewport ─────────────────────────
	rightInnerWidth := m.width - leftPanelWidth - 4 // border+padding for right panel
	if rightInnerWidth < 20 {
		rightInnerWidth = 20
	}

	rightPanel := theme.PanelBorder.
		Width(rightInnerWidth).
		Height(panelInnerHeight).
		BorderTop(true).
		BorderBottom(true).
		BorderLeft(true).
		BorderRight(true).
		Render(m.viewport.View())

	rightPanel = injectBorderTitle(rightPanel, " output ")

	// ── Compose panels side-by-side ──────────────────────────
	panels := lipgloss.JoinHorizontal(lipgloss.Top, leftPanel, rightPanel)
	b.WriteString(panels)
	b.WriteString("\n")

	// ── Bottom bar: progress or summary ──────────────────────
	if m.done {
		succeeded := completed - failed
		var summaryParts []string
		if succeeded > 0 {
			summaryParts = append(summaryParts, theme.Success.Render(fmt.Sprintf("✓ %d succeeded", succeeded)))
		}
		if failed > 0 {
			summaryParts = append(summaryParts, theme.Error.Render(fmt.Sprintf("✗ %d failed", failed)))
		}
		b.WriteString(theme.TitleAccent.Render("⚡ Done! ") + strings.Join(summaryParts, "  "))
		b.WriteString("    " + theme.HelpKey.Render("q") + theme.HelpValue.Render(" quit"))
	} else {
		barWidth := m.width - 16
		if barWidth < 20 {
			barWidth = 20
		}
		progressLabel := theme.Badge.Render(fmt.Sprintf(" %d/%d", completed, total))
		bar := theme.ProgressBar(barWidth, percent)
		b.WriteString(bar + progressLabel)
		b.WriteString("    " + theme.HelpKey.Render("q") + theme.HelpValue.Render(" quit"))
	}

	return b.String()
}

// injectBorderTitle inserts a styled label into the top border line of a rendered panel.
// It finds the horizontal border rune (─) and replaces a segment with the title.
func injectBorderTitle(rendered string, title string) string {
	lines := strings.SplitN(rendered, "\n", 2)
	if len(lines) < 2 {
		return rendered
	}

	label := theme.PanelTitle.Render(title)

	// The border line is wrapped in ANSI color codes. We search for the
	// multi-byte "─" (U+2500, 3 bytes in UTF-8) which is unique enough
	// to locate reliably even inside ANSI sequences.
	const borderRune = "─"
	idx := strings.Index(lines[0], borderRune)
	if idx < 0 {
		return rendered
	}

	// Replace len(title) border runes with the styled label
	replaceBytes := len([]rune(title)) * len(borderRune)
	end := idx + replaceBytes
	if end > len(lines[0]) {
		end = len(lines[0])
	}
	lines[0] = lines[0][:idx] + label + lines[0][end:]

	return strings.Join(lines, "\n")
}

// runComponentCmd launches a component's setup script in a goroutine, streaming
// its output through the channel via channelWriter, and sends a componentDoneMsg
// when finished.
func runComponentCmd(comp installer.Component, r *installer.Runner, index int, ch chan tea.Msg) tea.Cmd {
	return func() tea.Msg {
		w := &channelWriter{ch: ch}

		// Write a visual header to separate component output
		fmt.Fprintf(w, "\n━━━ %s ━━━\n\n", comp.Name)

		err := r.RunComponent(comp.Name, w)

		return componentDoneMsg{
			index: index,
			err:   err,
		}
	}
}

// waitForMsg is an idiomatic Bubble Tea cmd that blocks on a channel and returns
// the next message. The Update handler re-subscribes by returning another
// waitForMsg after processing each outputChunkMsg.
func waitForMsg(ch chan tea.Msg) tea.Cmd {
	return func() tea.Msg {
		return <-ch
	}
}
