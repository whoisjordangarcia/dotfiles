// bioprompt — BioPrompt.app: rich approval dialog + biometric confirmation for
// AI-initiated sensitive commands (used by the Claude Code touchid-gate hook).
//
// Preferred: a single SwiftUI dialog with Touch ID embedded inline
//            (LAAuthenticationView, macOS 12+) — command preview and sensor
//            prompt in one frosted window.
// Fallback:  when biometrics are unavailable (e.g. clamshell mode), a two-stage
//            flow: NSAlert with the command, then .deviceOwnerAuthentication
//            (password / Apple Watch fallback still works).
//
// The command preview is syntax-highlighted using the Ghostty theme (dark
// variant) parsed from ~/.config/ghostty/config; system colors otherwise.
//
// Usage:   bioprompt "<label>" "<full command>"
// Exit:    0 approved · 1 denied/cancelled · 2 auth unavailable
//
// Built by script/claude/setup.sh into ~/Applications/BioPrompt.app (Info.plist
// from bioprompt-Info.plist); ~/.local/bin/bioprompt is a shim that execs the
// bundled binary so it keeps app identity when launched from the hook.

import AppKit
import SwiftUI
import LocalAuthentication
import LocalAuthenticationEmbeddedUI

let args = Array(CommandLine.arguments.dropFirst())
let label = args.first ?? "sensitive command"
let detail = args.count > 1 ? args[1...].joined(separator: " ") : ""
let reason = String("approve \(label)".prefix(180))

// --- Ghostty theme (dynamic) ---
// Parses `theme =` from ~/.config/ghostty/config (preferring the dark: variant)
// and loads the named theme file's palette/background/foreground, so the command
// box matches the terminal. Falls back to system colors when anything is missing.

func hexColor(_ s: some StringProtocol) -> NSColor? {
    let h = s.hasPrefix("#") ? String(s.dropFirst()) : String(s)
    guard h.count == 6, let v = UInt32(h, radix: 16) else { return nil }
    return NSColor(srgbRed: CGFloat((v >> 16) & 0xff) / 255,
                   green: CGFloat((v >> 8) & 0xff) / 255,
                   blue: CGFloat(v & 0xff) / 255, alpha: 1)
}

struct Theme {
    var bg: NSColor
    var fg: NSColor
    var ansi: [NSColor?]
}

func ghosttyTheme() -> Theme? {
    let home = NSHomeDirectory()
    guard let cfg = try? String(contentsOfFile: home + "/.config/ghostty/config", encoding: .utf8) else { return nil }
    var name: String?
    for line in cfg.split(separator: "\n") {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard t.hasPrefix("theme"), let eq = t.firstIndex(of: "=") else { continue }
        let val = t[t.index(after: eq)...].trimmingCharacters(in: .whitespaces)
        var chosen: String?
        for part in val.split(separator: ",") {
            let p = part.trimmingCharacters(in: .whitespaces)
            if p.lowercased().hasPrefix("dark:") { chosen = String(p.dropFirst(5)); break }
            if !p.contains(":") { chosen = p }
        }
        if let c = chosen { name = c.trimmingCharacters(in: .whitespaces) }
    }
    guard let themeName = name else { return nil }
    let candidates = [
        home + "/.config/ghostty/themes/" + themeName,
        "/Applications/Ghostty.app/Contents/Resources/ghostty/themes/" + themeName,
    ]
    guard let path = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }),
          let body = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
    var bg: NSColor?, fg: NSColor?
    var ansi = [NSColor?](repeating: nil, count: 16)
    for line in body.split(separator: "\n") {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard let eq = t.firstIndex(of: "=") else { continue }
        let key = t[..<eq].trimmingCharacters(in: .whitespaces)
        let val = t[t.index(after: eq)...].trimmingCharacters(in: .whitespaces)
        switch key {
        case "background": bg = hexColor(val)
        case "foreground": fg = hexColor(val)
        case "palette":
            let kv = val.split(separator: "=", maxSplits: 1)
            if kv.count == 2, let i = Int(kv[0]), (0..<16).contains(i) { ansi[i] = hexColor(kv[1]) }
        default: break
        }
    }
    guard let b = bg, let f = fg else { return nil }
    return Theme(bg: b, fg: f, ansi: ansi)
}

let theme = ghosttyTheme()

// Shell syntax highlighting colored from the Ghostty ANSI palette (system
// semantic colors as fallback). Regex passes run in precedence order — later
// rules overwrite earlier ones (comments win over all).
func highlightShell(_ src: String, size: CGFloat) -> NSAttributedString {
    func ansi(_ i: Int, _ fallback: NSColor) -> NSColor { theme?.ansi[i] ?? fallback }
    let mono = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    let out = NSMutableAttributedString(string: src, attributes: [
        .font: mono, .foregroundColor: theme?.fg ?? NSColor.labelColor,
    ])
    let full = NSRange(src.startIndex..., in: src)
    func apply(_ pattern: String, _ color: NSColor, group: Int = 0, bold: Bool = false) {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return }
        re.enumerateMatches(in: src, range: full) { m, _, _ in
            guard let r = m?.range(at: group), r.location != NSNotFound else { return }
            out.addAttribute(.foregroundColor, value: color, range: r)
            if bold {
                out.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: size, weight: .semibold), range: r)
            }
        }
    }
    apply(#"(?<=\s)--?[A-Za-z][\w-]*"#, ansi(3, .systemOrange))                    // flags
    apply(#"\|\||&&|\d?>&?\d?|[|;<]"#, ansi(5, .systemPurple))                     // operators
    apply(#"(?:^|\||;|&)\s*(?:sudo\s+)?([A-Za-z_][\w./-]*)"#, ansi(4, .systemBlue), group: 1, bold: true) // commands
    apply(#"\b(if|then|elif|else|fi|for|in|do|done|while|case|esac|function|return|exit)\b"#, ansi(5, .systemPurple))
    apply(#"^\s*(?:export\s+)?([A-Za-z_]\w*)(?==)"#, ansi(1, .systemRed), group: 1) // assignments
    apply(#""[^"\\]*(?:\\.[^"\\]*)*"|'[^']*'"#, ansi(2, .systemGreen))             // strings
    apply(#"\$\{[^}\n]*\}|\$[A-Za-z_]\w*|\$[0-9@#?*!]"#, ansi(6, .systemTeal))     // variables (incl. in "")
    apply(#"(?:^|\s)#[^\n]*"#, ansi(8, .secondaryLabelColor))                      // comments
    return out
}

// Scrollable, themed, read-only view of the command (frame-sized; the SwiftUI
// wrapper re-pins the size with .frame, the NSAlert fallback uses it as-is).
func makeCommandBox() -> (view: NSScrollView, height: CGFloat)? {
    guard !detail.isEmpty else { return nil }
    let shown = String(detail.prefix(4000))
    let lines = shown.reduce(1) { $1 == "\n" ? $0 + 1 : $0 }
    let height = min(max(CGFloat(lines) * 16 + 20, 64), 260)
    let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 560, height: height))
    let text = NSTextView(frame: scroll.bounds)
    text.textStorage?.setAttributedString(highlightShell(shown, size: 12))
    text.isEditable = false
    text.drawsBackground = true
    text.backgroundColor = theme?.bg ?? .textBackgroundColor
    text.textContainerInset = NSSize(width: 10, height: 8)
    text.autoresizingMask = [.width]
    scroll.documentView = text
    scroll.hasVerticalScroller = true
    scroll.borderType = .noBorder
    scroll.wantsLayer = true
    scroll.layer?.cornerRadius = 10
    return (scroll, height)
}

// --- SwiftUI dialog (preferred flow) ---

struct CodeBox: NSViewRepresentable {
    let view: NSScrollView
    func makeNSView(context: Context) -> NSScrollView { view }
    func updateNSView(_ nsView: NSScrollView, context: Context) {}
}

struct AuthView: NSViewRepresentable {
    let ctx: LAContext
    func makeNSView(context: Context) -> LAAuthenticationView { LAAuthenticationView(context: ctx) }
    func updateNSView(_ nsView: LAAuthenticationView, context: Context) {}
}

struct PromptView: View {
    let ctx: LAContext
    let box: (view: NSScrollView, height: CGFloat)?

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 5) {
                Text("Claude wants to run")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(2)
            }
            if let box = box {
                CodeBox(view: box.view)
                    .frame(width: 560, height: box.height)
            }
            AuthView(ctx: ctx)
            Button("Deny") {
                NSApp.stopModal(withCode: .cancel)
            }
            .buttonStyle(.glass)
            .keyboardShortcut(.cancelAction)
        }
        .padding(24)
        .frame(width: 608)
        // Native Liquid Glass card — the window behind is fully transparent.
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }
}

// Borderless windows refuse key status by default; the dialog needs it for the
// Deny button and Esc.
final class KeyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

func runInline(_ ctx: LAContext) -> Never {
    let hosting = NSHostingView(rootView: PromptView(ctx: ctx, box: makeCommandBox()))
    hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)

    // Transparent borderless window so the glass refracts what's behind it.
    let win = KeyWindow(contentRect: hosting.frame,
                        styleMask: [.borderless],
                        backing: .buffered, defer: false)
    win.backgroundColor = .clear
    win.isOpaque = false
    win.hasShadow = true
    win.isMovableByWindowBackground = true
    // Dark controls to match the terminal-themed command box.
    win.appearance = NSAppearance(named: .darkAqua)
    win.contentView = hosting
    win.center()
    win.level = .modalPanel
    NSApp.activate(ignoringOtherApps: true)
    win.makeKeyAndOrderFront(nil)

    ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { ok, error in
        if let error = error, !ok {
            FileHandle.standardError.write(Data("bioprompt: \(error.localizedDescription)\n".utf8))
        }
        DispatchQueue.main.async { NSApp.stopModal(withCode: ok ? .OK : .cancel) }
    }
    let code = NSApp.runModal(for: win)
    win.orderOut(nil)
    ctx.invalidate()
    exit(code == .OK ? 0 : 1)
}

// --- Fallback flow: NSAlert, then a separate system auth prompt ---

func runTwoStage() -> Never {
    let alert = NSAlert()
    alert.messageText = "Claude wants to run: \(label)"
    alert.informativeText = "Review the command below. Approving requires authentication."
    alert.alertStyle = .warning
    if let box = makeCommandBox() { alert.accessoryView = box.view }
    alert.addButton(withTitle: "Approve")
    alert.addButton(withTitle: "Deny")

    NSApp.activate(ignoringOtherApps: true)
    guard alert.runModal() == .alertFirstButtonReturn else {
        exit(1)
    }

    let ctx = LAContext()
    var unavailable: NSError?
    guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &unavailable) else {
        FileHandle.standardError.write(Data("bioprompt: authentication unavailable: \(unavailable?.localizedDescription ?? "unknown")\n".utf8))
        exit(2)
    }

    let semaphore = DispatchSemaphore(value: 0)
    var approved = false
    ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
        approved = success
        if let error = error, !success {
            FileHandle.standardError.write(Data("bioprompt: \(error.localizedDescription)\n".utf8))
        }
        semaphore.signal()
    }
    semaphore.wait()
    exit(approved ? 0 : 1)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let inlineCtx = LAContext()
if inlineCtx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
    runInline(inlineCtx)
} else {
    runTwoStage()
}
