mod config;
mod detector;
mod installer;
mod tui;

use clap::Parser;
use std::path::PathBuf;

#[derive(Parser)]
#[command(name = "otobun", about = "Dotfiles installer TUI")]
struct Cli {
    /// Force setup wizard even if .dotconfig exists
    #[arg(long)]
    setup: bool,

    /// Show current configuration
    #[arg(long)]
    config: bool,

    /// Show detected system
    #[arg(long)]
    system: bool,

    /// Preview without executing
    #[arg(long)]
    dry_run: bool,
}

fn find_dotfiles_dir() -> anyhow::Result<PathBuf> {
    // Try executable's grandparent (bin/otobun -> dotfiles root)
    if let Ok(exe) = std::env::current_exe() {
        if let Some(root) = exe.parent().and_then(|p| p.parent()) {
            if root.join("script").is_dir() {
                return Ok(root.to_path_buf());
            }
        }
    }
    // Fall back to current directory
    let cwd = std::env::current_dir()?;
    if cwd.join("script").is_dir() {
        return Ok(cwd);
    }
    anyhow::bail!("Could not find dotfiles directory (no script/ folder found)")
}

fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();
    let dotfiles_dir = find_dotfiles_dir()?;

    if cli.config {
        let cfg = config::DotConfig::load(&dotfiles_dir)?;
        println!("{cfg}");
        return Ok(());
    }

    if cli.system {
        let sys = detector::detect();
        println!("{sys}");
        return Ok(());
    }

    tui::run(&dotfiles_dir, cli.setup, cli.dry_run)
}
