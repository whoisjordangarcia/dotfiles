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
        todo!()
    }

    pub fn save(&self, dotfiles_dir: &Path) -> Result<()> {
        todo!()
    }

    pub fn to_env(&self) -> Vec<(String, String)> {
        todo!()
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
