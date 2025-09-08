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

source ~/.zshrc-modules/.zshrc.starship
#source ~/.zshrc-modules/.zshrc.ohmyzsh
#source ~/.zshrc-modules/.zshrc.fzf
source ~/.zshrc-modules/.zshrc.envvars
source ~/.zshrc-modules/.zshrc.aliases
source ~/.zshrc-modules/.zshrc.functions
source ~/.zshrc-modules/.zshrc.init
source ~/.zshrc-modules/.zshrc.paths
#source ~/.zshrc-modules/.zshrc.startup
#source ~/.zshrc-modules/.zshrc.appearance
source ~/.zshrc-secrets

export PATH="$HOME/.pyenv/shims:$PATH"

source <(fzf --zsh)
