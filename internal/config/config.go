package config

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

const configFileName = ".dotconfig"

type DotConfig struct {
	Name        string
	Email       string
	Environment string
	System      string
	YubiKey     string
}

func Exists(dotfilesDir string) bool {
	_, err := os.Stat(filepath.Join(dotfilesDir, configFileName))
	return err == nil
}

func Load(dotfilesDir string) (*DotConfig, error) {
	path := filepath.Join(dotfilesDir, configFileName)
	f, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("open config: %w", err)
	}
	defer f.Close()

	cfg := &DotConfig{}
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		key, value, ok := parseConfigLine(line)
		if !ok {
			continue
		}

		switch key {
		case "DOT_NAME":
			cfg.Name = value
		case "DOT_EMAIL":
			cfg.Email = value
		case "DOT_ENVIRONMENT":
			cfg.Environment = value
		case "DOT_SYSTEM":
			cfg.System = value
		case "DOT_YUBIKEY":
			cfg.YubiKey = value
		}
	}

	return cfg, scanner.Err()
}

func Save(dotfilesDir string, cfg *DotConfig) error {
	path := filepath.Join(dotfilesDir, configFileName)
	content := fmt.Sprintf(`# Dotfiles configuration
DOT_NAME="%s"
DOT_EMAIL="%s"
DOT_ENVIRONMENT="%s"
DOT_SYSTEM="%s"
DOT_YUBIKEY="%s"
`, cfg.Name, cfg.Email, cfg.Environment, cfg.System, cfg.YubiKey)

	return os.WriteFile(path, []byte(content), 0644)
}

func (c *DotConfig) ToEnv() []string {
	return []string{
		"DOT_NAME=" + c.Name,
		"DOT_EMAIL=" + c.Email,
		"DOT_ENVIRONMENT=" + c.Environment,
		"DOT_SYSTEM=" + c.System,
		"DOT_YUBIKEY=" + c.YubiKey,
	}
}

func parseConfigLine(line string) (key, value string, ok bool) {
	parts := strings.SplitN(line, "=", 2)
	if len(parts) != 2 {
		return "", "", false
	}
	key = strings.TrimSpace(parts[0])
	value = strings.TrimSpace(parts[1])
	value = strings.Trim(value, `"'`)
	return key, value, true
}
