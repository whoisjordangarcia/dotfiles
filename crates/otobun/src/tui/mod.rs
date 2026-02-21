pub mod wizard;
pub mod selector;
pub mod runner;
pub mod theme;

use std::path::Path;

pub fn run(_dotfiles_dir: &Path, _force_setup: bool, _dry_run: bool) -> anyhow::Result<()> {
    todo!()
}
