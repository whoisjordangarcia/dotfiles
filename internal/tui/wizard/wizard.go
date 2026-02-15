package wizard

import (
	"github.com/charmbracelet/huh"
	"github.com/whoisjordangarcia/dotfiles/internal/config"
	"github.com/whoisjordangarcia/dotfiles/internal/detector"
)

// Run displays the setup wizard and returns the completed config.
func Run(detected detector.DetectedSystem) (*config.DotConfig, error) {
	cfg := &config.DotConfig{
		System: detected.System,
	}

	var name string
	var email string
	var environment string
	var yubikey string

	form := huh.NewForm(
		huh.NewGroup(
			huh.NewNote().
				Title("otobun").
				Description("Dotfiles setup wizard\nDetected system: "+detected.System),

			huh.NewInput().
				Title("Full Name").
				Value(&name).
				Placeholder("Jordan Garcia"),

			huh.NewSelect[string]().
				Title("Environment").
				Options(
					huh.NewOption("Personal", "personal"),
					huh.NewOption("Work", "work"),
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
	)

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
