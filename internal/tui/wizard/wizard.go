package wizard

import (
	"github.com/charmbracelet/huh"
	"github.com/charmbracelet/lipgloss"
	"github.com/whoisjordangarcia/dotfiles/internal/config"
	"github.com/whoisjordangarcia/dotfiles/internal/detector"
	"github.com/whoisjordangarcia/dotfiles/internal/tui/theme"
)

const logo = `
                            ▄▄
  ▄▄█▀▀██▄   ██            ▄██
▄██▀    ▀██▄ ██             ██
██▀      ▀███████  ▄██▀██▄  ██▄████▄ ▀███  ▀███ ▀████████▄
██        ██ ██   ██▀   ▀██ ██    ▀██  ██    ██   ██    ██
██▄      ▄██ ██   ██     ██ ██     ██  ██    ██   ██    ██
▀██▄    ▄██▀ ██   ██▄   ▄██ ██▄   ▄██  ██    ██   ██    ██
  ▀▀████▀▀   ▀████ ▀█████▀  █▀█████▀   ▀████▀███▄████  ████▄
`

// Run displays the setup wizard and returns the completed config.
func Run(detected detector.DetectedSystem) (*config.DotConfig, error) {
	cfg := &config.DotConfig{
		System: detected.System,
	}

	var name string
	var email string
	var environment string
	var yubikey string

	huhTheme := huh.ThemeBase()
	huhTheme.Focused.Title = huhTheme.Focused.Title.Foreground(theme.Cyan).Bold(true)
	huhTheme.Focused.Base = huhTheme.Focused.Base.BorderForeground(theme.Purple)
	huhTheme.Focused.SelectedOption = huhTheme.Focused.SelectedOption.Foreground(theme.Green)
	huhTheme.Focused.TextInput.Cursor = huhTheme.Focused.TextInput.Cursor.Foreground(theme.Purple)

	logoStyled := lipgloss.NewStyle().Foreground(theme.Purple).Bold(true).Render(logo)

	form := huh.NewForm(
		huh.NewGroup(
			huh.NewNote().
				Title("").
				Description(logoStyled+"\n"+
					lipgloss.NewStyle().Foreground(theme.Cyan).Bold(true).Render("  Setup Wizard")+"\n"+
					lipgloss.NewStyle().Foreground(theme.Muted).Italic(true).Render("  Detected system: "+detected.System)),

			huh.NewInput().
				Title("Full Name").
				Value(&name).
				Placeholder("Jordan Garcia"),

			huh.NewSelect[string]().
				Title("Environment").
				Options(
					huh.NewOption("🏠 Personal", "personal"),
					huh.NewOption("🏢 Work", "work"),
				).
				Value(&environment),
		),

		huh.NewGroup(
			huh.NewInput().
				Title("Email").
				Value(&email).
				Placeholder("you@example.com"),

			huh.NewInput().
				Title("YubiKey ID (optional)").
				Value(&yubikey).
				Placeholder("Leave empty to skip"),
		),
	).WithTheme(huhTheme)

	err := form.Run()
	if err != nil {
		return nil, err
	}

	// Apply defaults
	if name == "" {
		name = "Jordan Garcia"
	}
	if email == "" {
		if environment == "work" {
			email = "jordan.arickhogarcia@nestgenomics.com"
		} else {
			email = "arickho@gmail.com"
		}
	}

	cfg.Name = name
	cfg.Email = email
	cfg.Environment = environment
	cfg.YubiKey = yubikey

	return cfg, nil
}
