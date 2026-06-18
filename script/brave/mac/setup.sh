#!/bin/bash
set -euo pipefail

BRAVE_SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$BRAVE_SCRIPT_DIR/../../common/log.sh"

# Managed Brave policies (force-installed extensions, disabled built-in
# password manager, forced search engine, blocked sign-in) are OPT-IN.
# They are intended for fresh/work machines and will clobber a personal
# Brave profile: saved logins get hidden, you get signed out, and your
# extensions become enterprise-managed. To apply them, set
# DOT_BRAVE_MANAGED=1; otherwise this component is a no-op.
if [[ "${DOT_BRAVE_MANAGED:-0}" != "1" ]]; then
	info "Brave managed policies are opt-in (set DOT_BRAVE_MANAGED=1 to apply). Skipping."
	exit 0
fi

# macOS uses plist files in /Library/Managed Preferences/, NOT JSON in Application Support
MANAGED_PREFS_DIR="/Library/Managed Preferences"
PLIST_FILE="$MANAGED_PREFS_DIR/com.brave.Browser.plist"

# Check if Brave is installed, install if missing
if [ ! -d "/Applications/Brave Browser.app" ]; then
	info "Brave Browser not found. Installing via Homebrew..."
	brew install --cask brave-browser
fi

# Create Managed Preferences directory if needed (requires sudo)
if [ ! -d "$MANAGED_PREFS_DIR" ]; then
	info "Creating Managed Preferences directory (requires sudo)..."
	sudo mkdir -p "$MANAGED_PREFS_DIR"
	sudo chown root:wheel "$MANAGED_PREFS_DIR"
	sudo chmod 755 "$MANAGED_PREFS_DIR"
fi

info "Configuring Brave managed policies..."

# Skip if plist already exists
if [ -f "$PLIST_FILE" ]; then
	info "Brave policies already configured at $PLIST_FILE"
	info "To reconfigure, remove the file first: sudo rm \"$PLIST_FILE\""
	exit 0
fi

# Create new plist
sudo /usr/libexec/PlistBuddy -c "Clear dict" "$PLIST_FILE" 2>/dev/null || sudo /usr/libexec/PlistBuddy -c "Save" "$PLIST_FILE"

# ExtensionInstallForcelist — force-installed extensions (managed: can't be
# removed by the user). Keep this in sync with the curated daily-driver set;
# the inline names document the otherwise-opaque 32-char IDs. Mirror any change
# into configs/brave/policies/managed/policies.json for Linux.
# Update URL is the Chrome Web Store CRX endpoint (Brave honours it too).
CRX_UPDATE_URL="https://clients2.google.com/service/update2/crx"
FORCED_EXTENSIONS=(
	"aeblfdkhhhdcdjpifhhbdiojplfjncoa" # 1Password – Password Manager
	"fcoeoabgfenejglbffodgkkbkcdhcgfn" # Claude
	"jdkknkkbebbapilgoeccciglkfbmbnfm" # Apollo Client Devtools
	"cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
	"ndlbedplllcgconngcnfmkadhokfaaln" # GraphQL Network Inspector
)

sudo /usr/libexec/PlistBuddy -c "Add :ExtensionInstallForcelist array" "$PLIST_FILE"
_idx=0
for _ext in "${FORCED_EXTENSIONS[@]}"; do
	sudo /usr/libexec/PlistBuddy -c "Add :ExtensionInstallForcelist:$_idx string '${_ext};${CRX_UPDATE_URL}'" "$PLIST_FILE"
	_idx=$((_idx + 1))
done
unset _idx _ext

# Default search provider
sudo /usr/libexec/PlistBuddy -c "Add :DefaultSearchProviderEnabled bool true" "$PLIST_FILE"
sudo /usr/libexec/PlistBuddy -c "Add :DefaultSearchProviderName string 'DuckDuckGo'" "$PLIST_FILE"
sudo /usr/libexec/PlistBuddy -c "Add :DefaultSearchProviderSearchURL string 'https://duckduckgo.com/?q={searchTerms}'" "$PLIST_FILE"
sudo /usr/libexec/PlistBuddy -c "Add :DefaultSearchProviderSuggestURL string 'https://duckduckgo.com/ac/?q={searchTerms}&type=list'" "$PLIST_FILE"

# Default search provider for private/incognito windows
sudo /usr/libexec/PlistBuddy -c "Add :DefaultSearchProviderInPrivateEnabled bool true" "$PLIST_FILE"
sudo /usr/libexec/PlistBuddy -c "Add :DefaultSearchProviderInPrivateName string 'DuckDuckGo'" "$PLIST_FILE"
sudo /usr/libexec/PlistBuddy -c "Add :DefaultSearchProviderInPrivateSearchURL string 'https://duckduckgo.com/?q={searchTerms}'" "$PLIST_FILE"
sudo /usr/libexec/PlistBuddy -c "Add :DefaultSearchProviderInPrivateSuggestURL string 'https://duckduckgo.com/ac/?q={searchTerms}&type=list'" "$PLIST_FILE"

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
# Claude - pin to toolbar
sudo /usr/libexec/PlistBuddy -c "Add :ExtensionSettings:fcoeoabgfenejglbffodgkkbkcdhcgfn dict" "$PLIST_FILE"
sudo /usr/libexec/PlistBuddy -c "Add :ExtensionSettings:fcoeoabgfenejglbffodgkkbkcdhcgfn:toolbar_pin string 'force_pinned'" "$PLIST_FILE"

# Set correct ownership and permissions
sudo chown root:wheel "$PLIST_FILE"
sudo chmod 644 "$PLIST_FILE"

success "Brave policies configured!"
info "Restart Brave Browser for policies to take effect."
info "Verify at brave://policy"
