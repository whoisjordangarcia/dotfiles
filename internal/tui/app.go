package tui

import (
	"fmt"
	"os"
	"path/filepath"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/whoisjordangarcia/dotfiles/internal/config"
	"github.com/whoisjordangarcia/dotfiles/internal/detector"
	"github.com/whoisjordangarcia/dotfiles/internal/installer"
	"github.com/whoisjordangarcia/dotfiles/internal/tui/runner"
	"github.com/whoisjordangarcia/dotfiles/internal/tui/selector"
	"github.com/whoisjordangarcia/dotfiles/internal/tui/wizard"
)

// Run starts the full otobun TUI flow.
func Run(dotfilesDir string, forceSetup bool) error {
	detected := detector.Detect()
	var cfg *config.DotConfig

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
