use anyhow::{Context, Result};
use regex::Regex;
use std::fs;
use std::path::Path;

#[derive(Debug, Clone)]
pub struct Component {
    pub name: String,
}

pub fn parse_components(dotfiles_dir: &Path, system: &str) -> Result<Vec<Component>> {
    let script_path = dotfiles_dir
        .join("script")
        .join(format!("{system}_installation.sh"));

    let content = fs::read_to_string(&script_path)
        .with_context(|| format!("read installation script: {}", script_path.display()))?;

    let re = Regex::new(r"(?s)component_installation=\((.*?)\)").unwrap();
    let captures = re
        .captures(&content)
        .ok_or_else(|| anyhow::anyhow!("no component_installation array found in {}", script_path.display()))?;

    let array_body = &captures[1];
    let mut components = Vec::new();

    for line in array_body.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        // Strip inline comments
        let line = match line.find('#') {
            Some(idx) if idx > 0 => line[..idx].trim(),
            _ => line,
        };
        if !line.is_empty() {
            components.push(Component {
                name: line.to_string(),
            });
        }
    }

    Ok(components)
}
