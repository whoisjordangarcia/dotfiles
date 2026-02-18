package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoadConfig(t *testing.T) {
	dir := t.TempDir()
	content := `# Dotfiles configuration
DOT_NAME="Jordan Garcia"
DOT_EMAIL="arickho@gmail.com"
DOT_ENVIRONMENT="personal"
DOT_SYSTEM="linux_arch"
DOT_YUBIKEY=""
`
	err := os.WriteFile(filepath.Join(dir, ".dotconfig"), []byte(content), 0644)
	if err != nil {
		t.Fatal(err)
	}

	cfg, err := Load(dir)
	if err != nil {
		t.Fatalf("Load failed: %v", err)
	}

	if cfg.Name != "Jordan Garcia" {
		t.Errorf("Name = %q, want %q", cfg.Name, "Jordan Garcia")
	}
	if cfg.Email != "arickho@gmail.com" {
		t.Errorf("Email = %q, want %q", cfg.Email, "arickho@gmail.com")
	}
	if cfg.Environment != "personal" {
		t.Errorf("Environment = %q, want %q", cfg.Environment, "personal")
	}
	if cfg.System != "linux_arch" {
		t.Errorf("System = %q, want %q", cfg.System, "linux_arch")
	}
	if cfg.YubiKey != "" {
		t.Errorf("YubiKey = %q, want empty", cfg.YubiKey)
	}
}

func TestLoadConfigNotFound(t *testing.T) {
	dir := t.TempDir()
	_, err := Load(dir)
	if err == nil {
		t.Fatal("expected error for missing config, got nil")
	}
}

func TestSaveConfig(t *testing.T) {
	dir := t.TempDir()
	cfg := &DotConfig{
		Name:        "Test User",
		Email:       "test@example.com",
		Environment: "work",
		System:      "mac",
		YubiKey:     "ABC123",
	}

	err := Save(dir, cfg)
	if err != nil {
		t.Fatalf("Save failed: %v", err)
	}

	loaded, err := Load(dir)
	if err != nil {
		t.Fatalf("Load after Save failed: %v", err)
	}

	if loaded.Name != cfg.Name {
		t.Errorf("Name = %q, want %q", loaded.Name, cfg.Name)
	}
	if loaded.Email != cfg.Email {
		t.Errorf("Email = %q, want %q", loaded.Email, cfg.Email)
	}
	if loaded.Environment != cfg.Environment {
		t.Errorf("Environment = %q, want %q", loaded.Environment, cfg.Environment)
	}
	if loaded.System != cfg.System {
		t.Errorf("System = %q, want %q", loaded.System, cfg.System)
	}
	if loaded.YubiKey != cfg.YubiKey {
		t.Errorf("YubiKey = %q, want %q", loaded.YubiKey, cfg.YubiKey)
	}
}

func TestConfigExists(t *testing.T) {
	dir := t.TempDir()

	if Exists(dir) {
		t.Error("Exists should be false for missing config")
	}

	os.WriteFile(filepath.Join(dir, ".dotconfig"), []byte("DOT_NAME=\"x\"\n"), 0644)

	if !Exists(dir) {
		t.Error("Exists should be true after creating config")
	}
}

func TestConfigToEnv(t *testing.T) {
	cfg := &DotConfig{
		Name:        "Jordan Garcia",
		Email:       "test@example.com",
		Environment: "personal",
		System:      "linux_arch",
		YubiKey:     "",
	}

	env := cfg.ToEnv()

	expected := map[string]string{
		"DOT_NAME":        "Jordan Garcia",
		"DOT_EMAIL":       "test@example.com",
		"DOT_ENVIRONMENT": "personal",
		"DOT_SYSTEM":      "linux_arch",
		"DOT_YUBIKEY":     "",
	}

	envMap := make(map[string]string)
	for _, e := range env {
		for k, v := range expected {
			if e == k+"="+v {
				envMap[k] = v
			}
		}
	}

	for k, v := range expected {
		if envMap[k] != v {
			t.Errorf("missing or wrong env var %s=%s", k, v)
		}
	}
}
