package tui

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/whoisjordangarcia/dotfiles/internal/config"
	"github.com/whoisjordangarcia/dotfiles/internal/detector"
	"github.com/whoisjordangarcia/dotfiles/internal/installer"
	"github.com/whoisjordangarcia/dotfiles/internal/tui/runner"
	"github.com/whoisjordangarcia/dotfiles/internal/tui/selector"
	"github.com/whoisjordangarcia/dotfiles/internal/tui/theme"
	"github.com/whoisjordangarcia/dotfiles/internal/tui/wizard"

	"github.com/charmbracelet/lipgloss"
)

// Run starts the full otobun TUI flow.
func Run(dotfilesDir string, forceSetup bool) error {
	detected := detector.Detect()
	var cfg *config.DotConfig

	// Step 0: Pre-flight sudo — cache credentials while terminal is pristine
	// Must happen BEFORE any Bubble Tea program touches the terminal
	if err := preflight(); err != nil {
		return fmt.Errorf("sudo preflight: %w", err)
	}

	// Step 1: Setup wizard (if needed)
	if forceSetup || !config.Exists(dotfilesDir) {
		var err error
		cfg, err = wizard.Run(detected)
		if err != nil {
			return fmt.Errorf("setup wizard: %w", err)
		}
		if err := config.Save(dotfilesDir, cfg); err != nil {
			return fmt.Errorf("save config: %w", err)
		}
	} else {
		var err error
		cfg, err = config.Load(dotfilesDir)
		if err != nil {
			return fmt.Errorf("load config: %w", err)
		}
	}

	// Step 2: Parse available components
	components, err := installer.ParseComponents(dotfilesDir, cfg.System)
	if err != nil {
		return fmt.Errorf("parse components: %w", err)
	}

	// Step 3: Module selector
	selectorModel := selector.New(cfg.System, components)
	p := tea.NewProgram(selectorModel, tea.WithAltScreen())
	finalModel, err := p.Run()
	if err != nil {
		return fmt.Errorf("module selector: %w", err)
	}

	result := finalModel.(selector.Model).GetResult()
	if !result.Confirmed {
		fmt.Println("Cancelled.")
		return nil
	}

	// Filter to selected components
	var selected []installer.Component
	for i, comp := range result.Components {
		if result.Selected[i] {
			selected = append(selected, comp)
		}
	}

	if len(selected) == 0 {
		fmt.Println("No modules selected.")
		return nil
	}

	// Step 4: Installation runner
	r := installer.NewRunner(dotfilesDir, cfg)
	runnerModel := runner.New(selected, r)
	p2 := tea.NewProgram(runnerModel, tea.WithAltScreen())
	_, err = p2.Run()
	if err != nil {
		return fmt.Errorf("installation runner: %w", err)
	}

	return nil
}

// preflight prompts for sudo credentials before the TUI takes over stdin.
// This caches the credentials so scripts can use sudo non-interactively.
func preflight() error {
	// Check if sudo is even available
	if _, err := exec.LookPath("sudo"); err != nil {
		return nil // no sudo on system, skip
	}

	// Check if we already have cached credentials
	check := exec.Command("sudo", "-n", "true")
	if check.Run() == nil {
		return nil // already authenticated
	}

	// Need to prompt — do it before TUI takes over
	fmt.Println()
	style := lipgloss.NewStyle().Foreground(theme.Yellow).Bold(true)
	fmt.Println(style.Render("  🔐 Some components require sudo access."))
	fmt.Println(lipgloss.NewStyle().Foreground(theme.Muted).Render("  Enter your password to cache credentials for installation."))
	fmt.Println()

	cmd := exec.Command("sudo", "-v")
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// FindDotfilesDir locates the dotfiles directory.
func FindDotfilesDir() (string, error) {
	// Try executable directory first (go up from bin/)
	exe, err := os.Executable()
	if err == nil {
		dir := filepath.Dir(filepath.Dir(exe))
		if _, err := os.Stat(filepath.Join(dir, "script")); err == nil {
			return dir, nil
		}
	}

	// Try current directory
	cwd, err := os.Getwd()
	if err == nil {
		if _, err := os.Stat(filepath.Join(cwd, "script")); err == nil {
			return cwd, nil
		}
	}

	return "", fmt.Errorf("could not locate dotfiles directory (no 'script/' found)")
}
