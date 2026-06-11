#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../common/log.sh"

# =============================================================================
# macOS System Defaults
# All `defaults write` system tweaks live here so the installation array
# documents them as a single component.
# =============================================================================

# Some tweaks below need root (mdutil, pam.d)
sudo -v

# --- Touch ID for sudo ---

# /etc/pam.d/sudo_local survives macOS updates (editing /etc/pam.d/sudo does not)
if [ -f /etc/pam.d/sudo_local ] && grep -q "pam_tid.so" /etc/pam.d/sudo_local; then
  debug "Touch ID for sudo already enabled. Skipping."
else
  step "Enabling Touch ID for sudo..."
  echo "auth       sufficient     pam_tid.so" | sudo tee /etc/pam.d/sudo_local >/dev/null
  success "Touch ID enabled for sudo."
fi

# --- Keyboard & Input ---

# Disable press-and-hold for keys in favor of key repeat (essential for Neovim)
defaults write -g ApplePressAndHoldEnabled -bool false

# Fast key repeat (moderate — comfortable for general use, still snappy for Neovim)
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 25

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

# Use 12-hour time format in menu bar clock
defaults write com.apple.menuextra.clock AppleICUForce12HourTime -bool true

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

# Disable window opening animations
defaults write -g NSAutomaticWindowAnimationsEnabled -bool false

# Move windows by dragging any part of the window with Ctrl+Cmd
defaults write -g NSWindowShouldDragOnGesture -bool true

# Autohide the menu bar (sketchybar replaces it)
defaults write NSGlobalDomain _HIHideMenuBar -bool true

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

# Hide desktop icons
defaults write com.apple.finder CreateDesktop -bool false

# Avoid .DS_Store on network and USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Show ~/Library folder
chflags nohidden ~/Library 2>/dev/null

# --- Dock & Mission Control ---

# Autohide dock
defaults write com.apple.dock autohide -bool true

# Speed up Mission Control animations
defaults write com.apple.dock expose-animation-duration -float 0.1

# Don't rearrange Spaces based on recent use
defaults write com.apple.dock mru-spaces -bool false

# Don't show recent apps in Dock
defaults write com.apple.dock show-recents -bool false

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

# Disable Spotlight (replaced by Raycast)
defaults write com.apple.Spotlight "NSStatusItem Visible Item-0" -bool false
sudo mdutil -a -i off 2>/dev/null || true

# --- Suppress login message ---
touch "$HOME/.hushlogin"

# --- Restart affected apps ---
for app in "Activity Monitor" "Dock" "Finder" "Photos" "SystemUIServer"; do
  killall "${app}" &>/dev/null || true
done

success "macOS defaults applied."
