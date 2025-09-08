# Add user configurations here
# For HyDE to not touch your beloved configurations,
# we added 2 files to the project structure:
# 1. ~/.user.zsh - for customizing the shell related hyde configurations
# 2. ~/.zshenv - for updating the zsh environment variables handled by HyDE // this will be modified across updates

#  Plugins 
# oh-my-zsh plugins are loaded  in ~/.hyde.zshrc file, see the file for more information

#  Aliases 
# Add aliases here

#  This is your file 
# Add your configurations here
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
            source "$config_file"
            return 0 # Exit function on the first successful source
        fi
    done
    return 1 # Indicate no files were sourced
}

if ! source_files "${special_config_files[@]}"; then
    echo 'Could not find special config files. Defaulting to load .zshrc.personal'
    source ~/.zshrc-modules/.zshrc.personal
fi

# defaults
source ~/.zshrc-modules/.zshrc.starship
#source ~/.zshrc-modules/.zshrc.ohmyzsh
#source ~/.zshrc-modules/.zshrc.fzf
source ~/.zshrc-modules/.zshrc.envvars
source ~/.zshrc-modules/.zshrc.aliases
source ~/.zshrc-modules/.zshrc.functions
source ~/.zshrc-modules/.zshrc.init
source ~/.zshrc-modules/.zshrc.paths
source ~/.zshrc-modules/.zshrc.appearance

export PATH="$HOME/.pyenv/shims:$PATH"

source ~/.zshrc-modules/.zshrc.sec
source ~/.zshrc-sec
