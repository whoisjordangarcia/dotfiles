use crate::config::DotConfig;
use anyhow::{Context, Result};
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::Command;

pub struct Runner<'a> {
    dotfiles_dir: &'a Path,
    config: &'a DotConfig,
}

impl<'a> Runner<'a> {
    pub fn new(dotfiles_dir: &'a Path, config: &'a DotConfig) -> Self {
        Self {
            dotfiles_dir,
            config,
        }
    }

    pub fn dotfiles_dir(&self) -> &Path {
        self.dotfiles_dir
    }

    pub fn config(&self) -> &DotConfig {
        self.config
    }

    pub fn run_component(&self, component: &str, output: &mut dyn Write) -> Result<()> {
        let script_rel = format!("script/{component}/setup.sh");
        let script_abs = self.dotfiles_dir.join(&script_rel);

        if !script_abs.exists() {
            anyhow::bail!("script not found: {script_rel}");
        }

        let bash_script = format!(
            "set -euo pipefail\n\
             source ./script/common/log.sh\n\
             source ./script/common/symlink.sh\n\
             source ./{script_rel}"
        );

        let cmd_output = Command::new("bash")
            .arg("-c")
            .arg(&bash_script)
            .current_dir(self.dotfiles_dir)
            .envs(self.build_env())
            .output()
            .with_context(|| format!("execute {script_rel}"))?;

        output.write_all(&cmd_output.stdout)?;
        output.write_all(&cmd_output.stderr)?;

        if !cmd_output.status.success() {
            anyhow::bail!(
                "script {} exited with {}",
                script_rel,
                cmd_output.status.code().unwrap_or(-1)
            );
        }

        Ok(())
    }

    fn build_env(&self) -> Vec<(String, String)> {
        let mut env: Vec<(String, String)> = std::env::vars().collect();
        env.extend(self.config.to_env());

        if self.config.environment == "work" {
            env.push(("WORK_ENV".into(), "1".into()));
        }

        env.push(("DOT_SYMLINK_MODE".into(), "override".into()));
        env
    }
}

/// Owned variant of Runner for use in background threads where borrowing is impractical.
pub struct OwnedRunner {
    dotfiles_dir: PathBuf,
    config: DotConfig,
}

impl OwnedRunner {
    pub fn new(dotfiles_dir: PathBuf, config: DotConfig) -> Self {
        Self {
            dotfiles_dir,
            config,
        }
    }

    pub fn run_component(&self, component: &str, output: &mut dyn Write) -> Result<()> {
        let runner = Runner::new(&self.dotfiles_dir, &self.config);
        runner.run_component(component, output)
    }
}
