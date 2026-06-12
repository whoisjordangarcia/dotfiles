// bioprompt — rich approval dialog + biometric confirmation for AI-initiated
// sensitive commands (used by the Claude Code touchid-gate hook).
//
// Stage 1: an NSAlert showing what is being approved, with the full command
//          in a monospaced scrollable box (LAContext alone can only render a
//          single small line of reason text).
// Stage 2: Touch ID via .deviceOwnerAuthentication (biometry, Apple Watch,
//          or password fallback — still works in clamshell/docked mode).
//
// Usage:   bioprompt "<label>" "<full command>"
// Exit:    0 approved · 1 denied/cancelled · 2 auth unavailable
//
// Compiled by script/claude/setup.sh:  swiftc -O bioprompt.swift -o ~/.local/bin/bioprompt

import AppKit
import LocalAuthentication

let args = Array(CommandLine.arguments.dropFirst())
let label = args.first ?? "sensitive command"
let detail = args.count > 1 ? args[1...].joined(separator: " ") : ""

// --- Stage 1: rich description dialog ---

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let alert = NSAlert()
alert.messageText = "Claude wants to run: \(label)"
alert.informativeText = "Review the command below. Approving requires Touch ID."
alert.alertStyle = .warning

if !detail.isEmpty {
    let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 480, height: 96))
    let text = NSTextView(frame: scroll.bounds)
    text.string = String(detail.prefix(4000))
    text.isEditable = false
    text.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    text.textContainerInset = NSSize(width: 6, height: 6)
    text.autoresizingMask = [.width]
    scroll.documentView = text
    scroll.hasVerticalScroller = true
    scroll.borderType = .bezelBorder
    alert.accessoryView = scroll
}

alert.addButton(withTitle: "Approve with Touch ID")
alert.addButton(withTitle: "Deny")

NSApp.activate(ignoringOtherApps: true)
guard alert.runModal() == .alertFirstButtonReturn else {
    exit(1)
}

// --- Stage 2: biometric confirmation ---

let ctx = LAContext()
var unavailable: NSError?
guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &unavailable) else {
    FileHandle.standardError.write(Data("bioprompt: authentication unavailable: \(unavailable?.localizedDescription ?? "unknown")\n".utf8))
    exit(2)
}

let semaphore = DispatchSemaphore(value: 0)
var approved = false
ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: String("approve \(label)".prefix(180))) { success, error in
    approved = success
    if let error = error, !success {
        FileHandle.standardError.write(Data("bioprompt: \(error.localizedDescription)\n".utf8))
    }
    semaphore.signal()
}
semaphore.wait()
exit(approved ? 0 : 1)
