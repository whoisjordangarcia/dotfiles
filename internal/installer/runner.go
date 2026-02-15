package installer

import (
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/whoisjordangarcia/dotfiles/internal/config"
)

// RunResult captures the outcome of running a single component.
type RunResult struct {
	Component string
	Success   bool
	Output    string
	Error     error
}

// Runner executes component setup scripts within the dotfiles directory.
type Runner struct {
	DotfilesDir string
	Config      *config.DotConfig
}

// NewRunner creates a Runner for the given dotfiles directory and optional config.
func NewRunner(dotfilesDir string, cfg *config.DotConfig) *Runner {
	return &Runner{
		DotfilesDir: dotfilesDir,
		Config:      cfg,
	}
}

// RunComponent executes the setup.sh script for the named component.
// Output (stdout and stderr) is written to the provided writer.
func (r *Runner) RunComponent(component string, output io.Writer) error {
	scriptPath := filepath.Join("script", component, "setup.sh")
	absScript := filepath.Join(r.DotfilesDir, scriptPath)

	if _, err := os.Stat(absScript); err != nil {
		return fmt.Errorf("script not found: %s", scriptPath)
	}

	script := fmt.Sprintf(
		"set -euo pipefail\n"+
			"export SCRIPT_DIR='%s/script'\n"+
			"source ./script/common/log.sh\n"+
			"source ./script/common/symlink.sh\n"+
			"source ./%s",
		r.DotfilesDir, scriptPath,
	)

	cmd := exec.Command("bash", "-c", script)
	cmd.Dir = r.DotfilesDir
	cmd.Env = r.buildEnv()
	cmd.Stdout = output
	cmd.Stderr = output

	return cmd.Run()
}

// buildEnv constructs the environment variables for script execution.
func (r *Runner) buildEnv() []string {
	env := os.Environ()

	if r.Config != nil {
		env = append(env, r.Config.ToEnv()...)
		if r.Config.Environment == "work" {
			env = append(env, "WORK_ENV=1")
		}
	}

	env = append(env, "DOT_SYMLINK_MODE=override")

	return env
}
