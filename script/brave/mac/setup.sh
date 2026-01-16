#!/bin/bash
set -euo pipefail

BRAVE_SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$BRAVE_SCRIPT_DIR/../../common/log.sh"

# macOS uses plist files in /Library/Managed Preferences/, NOT JSON in Application Support
MANAGED_PREFS_DIR="/Library/Managed Preferences"
PLIST_FILE="$MANAGED_PREFS_DIR/com.brave.Browser.plist"

# Check if Brave is installed
if [ ! -d "/Applications/Brave Browser.app" ]; then
    info "Brave Browser not found. Install via: brew install --cask brave-browser"
    info "Skipping Brave policy setup..."
    exit 0
fi

# Create Managed Preferences directory if needed (requires sudo)
if [ ! -d "$MANAGED_PREFS_DIR" ]; then
    info "Creating Managed Preferences directory (requires sudo)..."
    sudo mkdir -p "$MANAGED_PREFS_DIR"
    sudo chown root:wheel "$MANAGED_PREFS_DIR"
    sudo chmod 755 "$MANAGED_PREFS_DIR"
fi

step "Configuring Brave managed policies..."

# Skip if plist already exists
if [ -f "$PLIST_FILE" ]; then
    info "Brave policies already configured at $PLIST_FILE"
    info "To reconfigure, remove the file first: sudo rm \"$PLIST_FILE\""
    exit 0
fi

# Create new plist
sudo /usr/libexec/PlistBuddy -c "Clear dict" "$PLIST_FILE" 2>/dev/null || sudo /usr/libexec/PlistBuddy -c "Save" "$PLIST_FILE"

# ExtensionInstallForcelist - array of extension IDs with update URLs
sudo /usr/libexec/PlistBuddy -c "Add :ExtensionInstallForcelist array" "$PLIST_FILE"
sudo /usr/libexec/PlistBuddy -c "Add :ExtensionInstallForcelist:0 string 'ddkjiahejlhfcafbddmgiahcphecmpfh;https://clients2.google.com/service/update2/crx'" "$PLIST_FILE"
sudo /usr/libexec/PlistBuddy -c "Add :ExtensionInstallForcelist:1 string 'aeblfdkhhhdcdjpifhhbdiojplfjncoa;https://clients2.google.com/service/update2/crx'" "$PLIST_FILE"
sudo /usr/libexec/PlistBuddy -c "Add :ExtensionInstallForcelist:2 string 'dbepggeogbaibhgnhhndojpepiihcmeb;https://clients2.google.com/service/update2/crx'" "$PLIST_FILE"
sudo /usr/libexec/PlistBuddy -c "Add :ExtensionInstallForcelist:3 string 'iphcomljdfghbkdcfndaijbokpgddeno;https://clients2.google.com/service/update2/crx'" "$PLIST_FILE"
sudo /usr/libexec/PlistBuddy -c "Add :ExtensionInstallForcelist:4 string 'eimadpbcbfnmbkopoojfekhnkhdbieeh;https://clients2.google.com/service/update2/crx'" "$PLIST_FILE"
sudo /usr/libexec/PlistBuddy -c "Add :ExtensionInstallForcelist:5 string 'dkgjnpbipbdaoaadbdhpiokaemhlphep;https://clients2.google.com/service/update2/crx'" "$PLIST_FILE"
sudo /usr/libexec/PlistBuddy -c "Add :ExtensionInstallForcelist:6 string 'hlepfoohegkhhmjieoechaddaejaokhf;https://clients2.google.com/service/update2/crx'" "$PLIST_FILE"
sudo /usr/libexec/PlistBuddy -c "Add :ExtensionInstallForcelist:7 string 'neebplgakaahbhdphmkckjjcegoiijjo;https://clients2.google.com/service/update2/crx'" "$PLIST_FILE"

# Default search provider
sudo /usr/libexec/PlistBuddy -c "Add :DefaultSearchProviderEnabled bool true" "$PLIST_FILE"
sudo /usr/libexec/PlistBuddy -c "Add :DefaultSearchProviderName string 'DuckDuckGo'" "$PLIST_FILE"
sudo /usr/libexec/PlistBuddy -c "Add :DefaultSearchProviderSearchURL string 'https://duckduckgo.com/?q={searchTerms}'" "$PLIST_FILE"
sudo /usr/libexec/PlistBuddy -c "Add :DefaultSearchProviderSuggestURL string 'https://duckduckgo.com/ac/?q={searchTerms}&type=list'" "$PLIST_FILE"

# Disable built-in password manager and autofill (use external like 1Password)
sudo /usr/libexec/PlistBuddy -c "Add :PasswordManagerEnabled bool false" "$PLIST_FILE"
sudo /usr/libexec/PlistBuddy -c "Add :AutofillAddressEnabled bool false" "$PLIST_FILE"
sudo /usr/libexec/PlistBuddy -c "Add :AutofillCreditCardEnabled bool false" "$PLIST_FILE"

# Disable browser sign-in
sudo /usr/libexec/PlistBuddy -c "Add :BrowserSignin integer 0" "$PLIST_FILE"

# Managed Bookmarks - appears in a separate "Managed" folder in bookmarks bar
sudo /usr/libexec/PlistBuddy -c "Add :ManagedBookmarks array" "$PLIST_FILE"
# First entry sets the folder name
sudo /usr/libexec/PlistBuddy -c "Add :ManagedBookmarks:0 dict" "$PLIST_FILE"
sudo /usr/libexec/PlistBuddy -c "Add :ManagedBookmarks:0:toplevel_name string 'Managed'" "$PLIST_FILE"
# Bookmarks
sudo /usr/libexec/PlistBuddy -c "Add :ManagedBookmarks:1 dict" "$PLIST_FILE"
sudo /usr/libexec/PlistBuddy -c "Add :ManagedBookmarks:1:name string 'GitHub'" "$PLIST_FILE"
sudo /usr/libexec/PlistBuddy -c "Add :ManagedBookmarks:1:url string 'https://github.com'" "$PLIST_FILE"
sudo /usr/libexec/PlistBuddy -c "Add :ManagedBookmarks:2 dict" "$PLIST_FILE"
sudo /usr/libexec/PlistBuddy -c "Add :ManagedBookmarks:2:name string 'Gmail'" "$PLIST_FILE"
sudo /usr/libexec/PlistBuddy -c "Add :ManagedBookmarks:2:url string 'https://mail.google.com'" "$PLIST_FILE"

# ExtensionSettings - for pinning extensions to toolbar
# Format: dict of extension_id -> settings dict
sudo /usr/libexec/PlistBuddy -c "Add :ExtensionSettings dict" "$PLIST_FILE"
# 1Password - pin to toolbar
sudo /usr/libexec/PlistBuddy -c "Add :ExtensionSettings:aeblfdkhhhdcdjpifhhbdiojplfjncoa dict" "$PLIST_FILE"
sudo /usr/libexec/PlistBuddy -c "Add :ExtensionSettings:aeblfdkhhhdcdjpifhhbdiojplfjncoa:toolbar_pin string 'force_pinned'" "$PLIST_FILE"
# Dark Reader - pin to toolbar
sudo /usr/libexec/PlistBuddy -c "Add :ExtensionSettings:eimadpbcbfnmbkopoojfekhnkhdbieeh dict" "$PLIST_FILE"
sudo /usr/libexec/PlistBuddy -c "Add :ExtensionSettings:eimadpbcbfnmbkopoojfekhnkhdbieeh:toolbar_pin string 'force_pinned'" "$PLIST_FILE"

# Set correct ownership and permissions
sudo chown root:wheel "$PLIST_FILE"
sudo chmod 644 "$PLIST_FILE"

success "Brave policies configured!"
info "Restart Brave Browser for policies to take effect."
info "Verify at brave://policy"
