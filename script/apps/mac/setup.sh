#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../../common/log.sh"

# Parse command line arguments
FORCE_ENVIRONMENT=""
while [[ $# -gt 0 ]]; do
	case $1 in
	--work)
		FORCE_ENVIRONMENT="work"
		shift
		;;
	--personal)
		FORCE_ENVIRONMENT="personal"
		shift
		;;
	-h | --help)
		echo "Usage: $0 [--work|--personal]"
		echo "  --work      Force work environment setup"
		echo "  --personal  Force personal environment setup"
		echo "  If no flag is provided, environment is auto-detected"
		exit 0
		;;
	*)
		echo "Unknown option $1"
		exit 1
		;;
	esac
done

# Install xCode cli tools
if xcode-select -p &>/dev/null; then
	debug "Xcode command line tools already installed. Skipping."
else
	info "Installing Xcode command line tools..."
	xcode-select --install
fi

# Check if Homebrew is installed
if ! command -v brew &>/dev/null; then
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

	echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>$HOME/.zprofile
	eval "$(/opt/homebrew/bin/brew shellenv)"
fi

brew analytics off

# Determine environment type
if [[ -n "$FORCE_ENVIRONMENT" ]]; then
	ENVIRONMENT="$FORCE_ENVIRONMENT"
elif [[ -n "${WORK_ENV:-}" ]] || [[ "$(git config user.email)" == *"@nestgenomics.com" ]]; then
	ENVIRONMENT="work"
else
	ENVIRONMENT="personal" # Default to personal
fi

debug "Detected environment: $ENVIRONMENT"

# Install base packages first
debug "Installing base packages..."
if [[ -f "$SCRIPT_DIR/Brewfile.base" ]]; then
	brew bundle --file="$SCRIPT_DIR/Brewfile.base"
else
	debug "Brewfile.base not found, skipping base packages"
fi

# Install environment-specific packages
if [[ -f "$SCRIPT_DIR/Brewfile.$ENVIRONMENT" ]]; then
	debug "Installing $ENVIRONMENT-specific packages..."
	brew bundle --file="$SCRIPT_DIR/Brewfile.$ENVIRONMENT"
else
	debug "No environment-specific Brewfile found, skipping package installation"
fi

# =============================================================================
# macOS Defaults
# =============================================================================

# --- Keyboard & Input ---

# Disable press-and-hold for keys in favor of key repeat (essential for Neovim)
defaults write -g ApplePressAndHoldEnabled -bool false

# Blazing fast key repeat
defaults write NSGlobalDomain KeyRepeat -int 1
defaults write NSGlobalDomain InitialKeyRepeat -int 10

# Disable smart quotes and dashes (they break code in terminals/editors)
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Disable auto-capitalization, auto-correct, and period substitution
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

# Trackpad: disable "natural" scrolling (use traditional scroll direction)
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false

# --- General UI ---

# Expand save panel by default (no more clicking "More Options")
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Expand print panel by default
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

# Save to disk by default (not iCloud)
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

# Instant window resize animations
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001

# Disable "Are you sure you want to open this application?" dialog
defaults write com.apple.LaunchServices LSQuarantine -bool false

# Use 12-hour time format in menu bar clock
defaults write com.apple.menuextra.clock AppleICUForce12HourTime -bool true

# --- Finder ---

# Show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Show hidden files
defaults write com.apple.finder AppleShowAllFiles -bool true

# Show status bar and path bar
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder ShowPathbar -bool true

# Display full POSIX path in title bar
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Search current folder by default (not "This Mac")
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Disable warning when changing file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Avoid .DS_Store on network and USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Show ~/Library folder
chflags nohidden ~/Library 2>/dev/null

# --- Screenshots ---

# Create Screenshots folder if it doesn't exist
mkdir -p "$HOME/Desktop/Screenshots"

# Set screenshot save location
defaults write com.apple.screencapture location "$HOME/Desktop/Screenshots"

# Disable screenshot shadow
defaults write com.apple.screencapture disable-shadow -bool true

# --- Security ---

# Require password immediately after sleep/screensaver
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

# Enable Secure Keyboard Entry in Terminal.app
defaults write com.apple.terminal SecureKeyboardEntry -bool true

# --- Misc Apps ---

# Activity Monitor: show CPU usage in Dock icon, sort by CPU
defaults write com.apple.ActivityMonitor IconType -int 5
defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage"
defaults write com.apple.ActivityMonitor SortDirection -int 0

# TextEdit: use plain text by default
defaults write com.apple.TextEdit RichText -int 0

# Prevent Photos from opening when plugging in devices
defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true

# Time Machine: don't prompt for new disks
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

# Speed up Mission Control animations
defaults write com.apple.dock expose-animation-duration -float 0.1

# Don't rearrange Spaces based on recent use
defaults write com.apple.dock mru-spaces -bool false

# Don't show recent apps in Dock
defaults write com.apple.dock show-recents -bool false

# --- Suppress login message ---
touch "$HOME/.hushlogin"

# --- Restart affected apps ---
for app in "Activity Monitor" "Finder" "Photos" "SystemUIServer"; do
	killall "${app}" &>/dev/null || true
done
