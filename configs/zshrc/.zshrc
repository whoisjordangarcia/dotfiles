export EDITOR=nvim
export TERM=xterm-256color

# ==============================================================================
#  .zshrc
# ==============================================================================

# Define a list of special configuration files to check
special_config_files=(
    "$HOME/.zshrc-work-mode"
    "$HOME/.zshrc-arch-mode"
)

# Function to check and source a list of files
source_files() {
    for config_file in "$@"; do
        if [[ -f "$config_file" ]]; then
            echo "Loading $config_file"
            source "$config_file"
            return 0
        fi
    done
    return 1 
}

# defaults
source ~/.zshrc-modules/.zshrc.starship
source ~/.zshrc-modules/.zshrc.ohmyzsh
source ~/.zshrc-modules/.zshrc.envvars
source ~/.zshrc-modules/.zshrc.aliases
source ~/.zshrc-modules/.zshrc.functions
source ~/.zshrc-modules/.zshrc.init
source ~/.zshrc-modules/.zshrc.paths
source ~/.zshrc-modules/.zshrc.appearance

export PATH="$HOME/.pyenv/shims:$PATH"

source ~/.zshrc-modules/.zshrc.sec
source ~/.zshrc-sec

if ! source_files "${special_config_files[@]}"; then
    echo 'Could not find special config files. Defaulting to load .zshrc.personal'
    source ~/.zshrc-modules/.zshrc.personal
fi

