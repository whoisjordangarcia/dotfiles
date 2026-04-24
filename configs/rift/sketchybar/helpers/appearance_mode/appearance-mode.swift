// Prints "dark" or "light" based on the *effective* macOS appearance.
//
// Unlike `defaults read -g AppleInterfaceStyle`, this works correctly in
// Auto appearance mode, where the AppleInterfaceStyle key is unset even
// when the system is currently displaying dark. NSApplication.effectiveAppearance
// goes through AppKit's appearance resolution, which consults SkyLight's
// current computed theme including Auto mode's schedule.
//
// This approach deliberately avoids `osascript ... System Events`, which
// hangs indefinitely when called from launchd-spawned processes (like
// sketchybar under brew services) due to TCC attribution issues.

import AppKit

let app = NSApplication.shared
let match = app.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
print(match == .darkAqua ? "dark" : "light")
