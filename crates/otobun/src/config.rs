use anyhow::{Context, Result};
use std::fmt;
use std::fs;
use std::path::Path;

const CONFIG_FILE: &str = ".dotconfig";

#[derive(Debug, Clone, Default)]
pub struct DotConfig {
    pub name: String,
    pub email: String,
    pub environment: String,
    pub system: String,
    pub yubikey: String,
}

impl DotConfig {
    pub fn exists(dotfiles_dir: &Path) -> bool {
        dotfiles_dir.join(CONFIG_FILE).exists()
    }

    pub fn load(dotfiles_dir: &Path) -> Result<Self> {
        let path = dotfiles_dir.join(CONFIG_FILE);
        let content = fs::read_to_string(&path)
            .with_context(|| format!("open config: {}", path.display()))?;

        let mut cfg = Self::default();
        for line in content.lines() {
            let line = line.trim();
            if line.is_empty() || line.starts_with('#') {
                continue;
            }
            if let Some((key, value)) = parse_config_line(line) {
                match key {
                    "DOT_NAME" => cfg.name = value.to_string(),
                    "DOT_EMAIL" => cfg.email = value.to_string(),
                    "DOT_ENVIRONMENT" => cfg.environment = value.to_string(),
                    "DOT_SYSTEM" => cfg.system = value.to_string(),
                    "DOT_YUBIKEY" => cfg.yubikey = value.to_string(),
                    _ => {}
                }
            }
        }
        Ok(cfg)
    }

    pub fn save(&self, dotfiles_dir: &Path) -> Result<()> {
        let path = dotfiles_dir.join(CONFIG_FILE);
        let content = format!(
            "# Dotfiles configuration\n\
             DOT_NAME=\"{}\"\n\
             DOT_EMAIL=\"{}\"\n\
             DOT_ENVIRONMENT=\"{}\"\n\
             DOT_SYSTEM=\"{}\"\n\
             DOT_YUBIKEY=\"{}\"\n",
            self.name, self.email, self.environment, self.system, self.yubikey
        );
        fs::write(&path, content).with_context(|| format!("write config: {}", path.display()))
    }

    pub fn to_env(&self) -> Vec<(String, String)> {
        vec![
            ("DOT_NAME".into(), self.name.clone()),
            ("DOT_EMAIL".into(), self.email.clone()),
            ("DOT_ENVIRONMENT".into(), self.environment.clone()),
            ("DOT_SYSTEM".into(), self.system.clone()),
            ("DOT_YUBIKEY".into(), self.yubikey.clone()),
        ]
    }
}

impl fmt::Display for DotConfig {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        writeln!(f, "Name:        {}", self.name)?;
        writeln!(f, "Email:       {}", self.email)?;
        writeln!(f, "Environment: {}", self.environment)?;
        writeln!(f, "System:      {}", self.system)?;
        write!(f, "YubiKey:     {}", if self.yubikey.is_empty() { "(none)" } else { &self.yubikey })
    }
}

fn parse_config_line(line: &str) -> Option<(&str, &str)> {
    let (key, value) = line.split_once('=')?;
    let key = key.trim();
    let value = value.trim().trim_matches(|c| c == '"' || c == '\'');
    Some((key, value))
}
