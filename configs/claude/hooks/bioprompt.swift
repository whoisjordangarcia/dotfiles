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
import Security
import OpenDirectory
import LocalAuthentication
import LocalAuthenticationEmbeddedUI

let args = Array(CommandLine.arguments.dropFirst())
let label = args.first ?? "sensitive command"
let detail = args.count > 1 ? args[1...].joined(separator: " ") : ""
let reason = String("approve \(label)".prefix(180))

// --- YubiKey (FIDO2) approval ---
// A user-presence assertion via libfido2: tap the key to approve. Enrolled once
// with `bioprompt --enroll` (stores credential id + PUBLIC key only under
// ~/.config/bioprompt; each approval signs a fresh random challenge, verified
// against that key — nothing replayable sits on disk). Races the other auth
// paths; first success wins.

let fidoDir = NSHomeDirectory() + "/.config/bioprompt"
let fidoRP = "bioprompt"
var fidoProc: Process?  // the blocking -G call, terminated when the dialog closes

func fidoBin(_ name: String) -> String? {
    ["/opt/homebrew/bin/", "/usr/local/bin/"]
        .map { $0 + name }
        .first { FileManager.default.isExecutableFile(atPath: $0) }
}

var lastProcErr = ""  // stderr of the most recent runProc call (for diagnostics)

func runProc(_ bin: String, _ args: [String], stdin: String? = nil, track: Bool = false) -> (status: Int32, out: String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: bin)
    p.arguments = args
    let outPipe = Pipe(), errPipe = Pipe()
    p.standardOutput = outPipe
    p.standardError = errPipe
    let inPipe = Pipe()
    p.standardInput = inPipe
    do { try p.run() } catch { lastProcErr = error.localizedDescription; return (-1, "") }
    if track { fidoProc = p }
    if let stdin = stdin { inPipe.fileHandleForWriting.write(Data(stdin.utf8)) }
    inPipe.fileHandleForWriting.closeFile()
    var errData = Data()
    errPipe.fileHandleForReading.readabilityHandler = { h in errData.append(h.availableData) }
    let data = outPipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    errPipe.fileHandleForReading.readabilityHandler = nil
    lastProcErr = String(data: errData, encoding: .utf8) ?? ""
    return (p.terminationStatus, String(data: data, encoding: .utf8) ?? "")
}

func randomB64() -> String {
    var bytes = [UInt8](repeating: 0, count: 32)
    _ = SecRandomCopyBytes(kSecRandomDefault, 32, &bytes)
    return Data(bytes).base64EncodedString()
}

// Local account password check via OpenDirectory — lets the fallback flow use
// our own glass password card instead of the unstylable system auth sheet.
func verifyLocalPassword(_ pw: String) -> Bool {
    guard let session = ODSession.default(),
          let node = try? ODNode(session: session, type: ODNodeType(kODNodeTypeAuthentication)),
          let record = try? node.record(withRecordType: kODRecordTypeUsers, name: NSUserName(), attributes: nil)
    else { return false }
    return (try? record.verifyPassword(pw)) != nil
}

func fidoDevice() -> String? {
    guard let tok = fidoBin("fido2-token") else { return nil }
    let r = runProc(tok, ["-L"])
    guard r.status == 0,
          let first = r.out.split(separator: "\n").first?.split(separator: " ").first else { return nil }
    return String(first.hasSuffix(":") ? first.dropLast() : first)
}

func yubiArmed() -> Bool {
    FileManager.default.fileExists(atPath: fidoDir + "/cred.id") && fidoBin("fido2-assert") != nil
}

// Background watcher: keeps the key's touch window armed (fresh challenge per
// ~30s round) until a tap approves or a hard error occurs. Dies with the process.
func yubiWatch(onApproved: @escaping () -> Void) {
    DispatchQueue.global().async {
        while true {
            if yubiApprove() {
                onApproved()
                return
            }
            if !lastProcErr.contains("ACTION_TIMEOUT") {
                FileHandle.standardError.write(Data("bioprompt: yubikey: \(lastProcErr.trimmingCharacters(in: .whitespacesAndNewlines))\n".utf8))
                return
            }
        }
    }
}

// Blocks until the key is tapped (or its ~30s touch window lapses); returns
// whether a valid signature over a fresh challenge was produced. Callers loop
// on ACTION_TIMEOUT via yubiWatch to keep the window armed.
func yubiApprove() -> Bool {
    guard let assertBin = fidoBin("fido2-assert"),
          let credId = (try? String(contentsOfFile: fidoDir + "/cred.id", encoding: .utf8))?
              .trimmingCharacters(in: .whitespacesAndNewlines),
          let dev = fidoDevice() else { return false }
    let got = runProc(assertBin, ["-G", "-t", "up=true", dev],
                      stdin: "\(randomB64())\n\(fidoRP)\n\(credId)\n", track: true)
    guard got.status == 0 else { return false }
    let tmp = NSTemporaryDirectory() + "bioprompt-assert-\(getpid())"
    defer { try? FileManager.default.removeItem(atPath: tmp) }
    guard (try? got.out.write(toFile: tmp, atomically: true, encoding: .utf8)) != nil else { return false }
    return runProc(assertBin, ["-V", "-i", tmp, fidoDir + "/cred.pub", "es256"]).status == 0
}

var enrollError = ""

// Shows a glass popup and re-arms the key's ~30s touch window until the user
// taps (each retry uses a fresh challenge) or cancels. Real errors abort.
func enroll() -> Never {
    func die(_ msg: String) -> Never {
        FileHandle.standardError.write(Data("bioprompt --enroll: \(msg)\n".utf8))
        exit(1)
    }
    guard let credBin = fidoBin("fido2-cred") else { die("libfido2 not installed (brew install libfido2)") }
    guard fidoDevice() != nil else { die("no FIDO2 device found — is the YubiKey plugged in?") }

    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let win = showGlass(EnrollView())

    DispatchQueue.global().async {
        while true {
            guard let dev = fidoDevice() else {
                enrollError = "FIDO2 device disappeared"
                DispatchQueue.main.async { NSApp.stopModal(withCode: .abort) }
                return
            }
            let made = runProc(credBin, ["-M", dev, "es256"],
                               stdin: "\(randomB64())\n\(fidoRP)\nbioprompt\n\(randomB64())\n", track: true)
            if made.status == 0 {
                let verified = runProc(credBin, ["-V"], stdin: made.out)
                let parts = verified.out.split(separator: "\n", maxSplits: 1)
                guard verified.status == 0, parts.count == 2 else {
                    enrollError = "credential verification failed: \(lastProcErr)"
                    DispatchQueue.main.async { NSApp.stopModal(withCode: .abort) }
                    return
                }
                do {
                    try FileManager.default.createDirectory(atPath: fidoDir, withIntermediateDirectories: true)
                    try (String(parts[0]) + "\n").write(toFile: fidoDir + "/cred.id", atomically: true, encoding: .utf8)
                    try String(parts[1]).write(toFile: fidoDir + "/cred.pub", atomically: true, encoding: .utf8)
                } catch {
                    enrollError = "could not write \(fidoDir): \(error.localizedDescription)"
                    DispatchQueue.main.async { NSApp.stopModal(withCode: .abort) }
                    return
                }
                DispatchQueue.main.async { NSApp.stopModal(withCode: .OK) }
                return
            }
            if !lastProcErr.contains("ACTION_TIMEOUT") {
                enrollError = "make-credential failed: \(lastProcErr.trimmingCharacters(in: .whitespacesAndNewlines))"
                DispatchQueue.main.async { NSApp.stopModal(withCode: .abort) }
                return
            }
            // touch window lapsed — arm a fresh one and keep blinking
        }
    }

    let code = NSApp.runModal(for: win)
    win.orderOut(nil)
    fidoProc?.terminate()
    switch code {
    case .OK:
        print("Enrolled. A YubiKey tap can now approve bioprompt dialogs.")
        exit(0)
    case .abort:
        die(enrollError)
    default:
        exit(1)  // cancelled
    }
}

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

// Glass tinted toward the terminal background so the card and the command box
// read as one surface (card kept slightly lighter so the box sits inset).
let cardGlass: Glass = theme.map { .regular.tint(Color(nsColor: $0.bg).opacity(0.55)) } ?? .regular
let accent = Color(nsColor: theme?.ansi[4] ?? .controlAccentColor)

struct YubiHint: View {
    let solo: Bool       // no inline biometry → the tap is the primary path
    let connected: Bool  // enrolled key currently plugged in
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(connected ? Color.green : Color.secondary.opacity(0.5))
                .frame(width: 6, height: 6)
            Image(systemName: "key.radiowaves.forward.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(connected ? accent : .secondary)
                .opacity(connected ? (pulse ? 1 : 0.4) : 0.4)
                .animation(connected ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true) : .default, value: pulse)
            Text(connected
                 ? (solo ? "YubiKey connected — press its gold contact to approve" : "YubiKey connected — or press its gold contact")
                 : "YubiKey enrolled, but not connected")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.06), in: Capsule())
        .onAppear { pulse = true }
    }
}

struct PasswordView: View {
    let yubiConnected: Bool
    @State private var password = ""
    @State private var failed = false
    @State private var checking = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("Bioprompt")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Text("Enter your password to approve")
                    .font(.system(size: 16, weight: .semibold))
            }
            .padding(.bottom, 16)

            SecureField("Account password", text: $password)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
                .focused($focused)
                .onSubmit { submit() }
                .padding(.bottom, 6)
            // opacity (not if) keeps the card height fixed — the window can't resize
            Text("Incorrect password — try again")
                .font(.system(size: 11))
                .foregroundStyle(Color(nsColor: theme?.ansi[1] ?? .systemRed))
                .opacity(failed ? 1 : 0)
                .padding(.bottom, 12)

            if yubiConnected {
                YubiHint(solo: false, connected: true)
                    .padding(.bottom, 16)
            }

            HStack(spacing: 12) {
                Button {
                    NSApp.stopModal(withCode: .cancel)
                } label: {
                    Text("Cancel").frame(minWidth: 100)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)

                Button {
                    submit()
                } label: {
                    Text(checking ? "Checking…" : "Approve").frame(minWidth: 100)
                }
                .buttonStyle(.glassProminent)
                .tint(accent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(checking || password.isEmpty)
            }
        }
        .padding(28)
        .glassEffect(cardGlass, in: .rect(cornerRadius: 26))
        .onAppear { focused = true }
    }

    private func submit() {
        guard !password.isEmpty, !checking else { return }
        checking = true
        let pw = password
        DispatchQueue.global().async {
            let ok = verifyLocalPassword(pw)
            DispatchQueue.main.async {
                checking = false
                if ok {
                    approvedVia = "password"
                    NSApp.stopModal(withCode: .OK)
                } else {
                    failed = true
                    password = ""
                    focused = true
                }
            }
        }
    }
}

struct PromptView: View {
    let ctx: LAContext?  // nil → button-driven approval (no inline biometry)
    let box: (view: NSScrollView, height: CGFloat)?
    let yubi: Bool
    let yubiConnected: Bool

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("Claude wants to run")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Text(label)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(2)
            }
            .padding(.bottom, 18)

            if let box = box {
                CodeBox(view: box.view)
                    .frame(width: 560, height: box.height)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                    .padding(.bottom, 18)
            }

            if let ctx = ctx {
                AuthView(ctx: ctx)
                    .padding(.bottom, 8)
            }
            if yubi {
                YubiHint(solo: ctx == nil, connected: yubiConnected)
                    .padding(.bottom, 16)
            }

            HStack(spacing: 12) {
                Button {
                    NSApp.stopModal(withCode: .cancel)
                } label: {
                    Text("Deny").frame(minWidth: 110)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)

                if ctx == nil {
                    Button {
                        NSApp.stopModal(withCode: .continue)
                    } label: {
                        Text("Approve").frame(minWidth: 110)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(accent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(28)
        .frame(width: 616)
        // Native Liquid Glass card — the window behind is fully transparent.
        .glassEffect(cardGlass, in: .rect(cornerRadius: 26))
    }
}

var approvedVia = ""  // logged on exit so hook output shows which path approved

func logApproval() {
    if !approvedVia.isEmpty {
        FileHandle.standardError.write(Data("bioprompt: approved via \(approvedVia)\n".utf8))
    }
}

// Borderless windows refuse key status by default; the dialog needs it for the
// Deny button and Esc.
final class KeyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

// Transparent borderless modal window so the glass refracts what's behind it.
func showGlass<V: View>(_ root: V) -> NSWindow {
    let hosting = NSHostingView(rootView: root)
    hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)
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
    return win
}

struct EnrollView: View {
    var body: some View {
        VStack(spacing: 14) {
            Text("Bioprompt setup")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
            Text("Touch your YubiKey")
                .font(.system(size: 15, weight: .semibold))
            Text("Hold a finger on the gold contact until it stops blinking.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            ProgressView()
                .controlSize(.small)
            Button("Cancel") {
                NSApp.stopModal(withCode: .cancel)
            }
            .buttonStyle(.glass)
            .keyboardShortcut(.cancelAction)
        }
        .padding(24)
        .frame(width: 360)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }
}

func runInline(_ ctx: LAContext) -> Never {
    let yubi = yubiArmed()
    let connected = yubi && fidoDevice() != nil
    let win = showGlass(PromptView(ctx: ctx, box: makeCommandBox(), yubi: yubi, yubiConnected: connected))

    ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { ok, error in
        if ok { approvedVia = "touch id" }
        if let error = error, !ok {
            FileHandle.standardError.write(Data("bioprompt: \(error.localizedDescription)\n".utf8))
        }
        DispatchQueue.main.async { NSApp.stopModal(withCode: ok ? .OK : .cancel) }
    }
    if connected {
        yubiWatch {
            approvedVia = "yubikey tap"
            DispatchQueue.main.async { NSApp.stopModal(withCode: .OK) }
        }
    }
    let code = NSApp.runModal(for: win)
    win.orderOut(nil)
    ctx.invalidate()
    fidoProc?.terminate()
    logApproval()
    exit(code == .OK ? 0 : 1)
}

// --- Fallback flow (no usable biometrics, e.g. clamshell): same glass dialog
// with Approve/Deny buttons. A key tap approves outright at any point; Approve
// opens a glass password card (verified locally via OpenDirectory).

var yubiApproved = false

func runTwoStage() -> Never {
    let yubi = yubiArmed()
    let connected = yubi && fidoDevice() != nil
    let win = showGlass(PromptView(ctx: nil, box: makeCommandBox(), yubi: yubi, yubiConnected: connected))

    if connected {
        yubiWatch {
            yubiApproved = true
            approvedVia = "yubikey tap"
            DispatchQueue.main.async { NSApp.stopModal(withCode: .OK) }
        }
    }

    let code = NSApp.runModal(for: win)
    win.orderOut(nil)
    if code == .OK || yubiApproved {  // key tap won while the dialog was up
        fidoProc?.terminate()
        logApproval()
        exit(0)
    }
    guard code == .continue else {  // denied / Esc
        fidoProc?.terminate()
        exit(1)
    }

    // Approve clicked → glass password card, key still armed.
    let pwWin = showGlass(PasswordView(yubiConnected: connected))
    let pwCode = NSApp.runModal(for: pwWin)
    pwWin.orderOut(nil)
    fidoProc?.terminate()
    logApproval()
    exit((pwCode == .OK || yubiApproved) ? 0 : 1)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

if args.first == "--enroll" { enroll() }

let inlineCtx = LAContext()
if inlineCtx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
    runInline(inlineCtx)
} else {
    runTwoStage()
}
