// MediaNotch — a Dynamic-Island-style notch overlay for mpd/mpc now-playing.
//
// A borderless NSWindow pinned to the top-center of the main screen draws a
// black blob (square top corners flush to the bezel, rounded bottom) that
// appears only while a track is loaded (playing OR paused) and hides when mpd
// is stopped. Collapsed hugs cover + title; hover expands to full metadata, a
// progress bar, and prev / play-pause / next controls. Data comes from `mpc`.
//
// Built as a single-file `swiftc -O` app bundle, same as bioprompt.swift.

import AppKit
import SwiftUI

// MARK: - Theme

let accent = Color(red: 0.98, green: 0.68, blue: 0.45) // warm progress/accent

// MARK: - mpc plumbing

// A bundled .app has a bare PATH, so Process needs an absolute binary path.
let mpcPath: String = {
    for p in ["/opt/homebrew/bin/mpc", "/usr/local/bin/mpc", "/usr/bin/mpc"]
    where FileManager.default.isExecutableFile(atPath: p) { return p }
    return "/opt/homebrew/bin/mpc"
}()

func runMPC(_ args: [String]) -> Data {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: mpcPath)
    proc.arguments = args
    let out = Pipe()
    proc.standardOutput = out
    proc.standardError = FileHandle.nullDevice
    guard (try? proc.run()) != nil else { return Data() }
    let data = out.fileHandleForReading.readDataToEndOfFile()
    proc.waitUntilExit()
    return data
}

func mpcString(_ args: [String]) -> String {
    String(data: runMPC(args), encoding: .utf8) ?? ""
}

// Parse "M:SS/M:SS" out of the mpc status line into a 0...1 fraction.
func parseProgress(_ status: String) -> Double {
    guard let r = status.range(of: #"\d+:\d\d/\d+:\d\d"#, options: .regularExpression) else { return 0 }
    let sides = status[r].split(separator: "/")
    func secs(_ s: Substring) -> Double {
        let c = s.split(separator: ":")
        guard c.count == 2, let m = Double(c[0]), let sec = Double(c[1]) else { return 0 }
        return m * 60 + sec
    }
    let elapsed = secs(sides[0]), total = secs(sides[1])
    return total > 0 ? min(1, elapsed / total) : 0
}

// MARK: - Model

final class MusicModel: ObservableObject {
    @Published var active = false        // a track is loaded (playing or paused)
    @Published var playing = false
    @Published var title = ""
    @Published var artist = ""
    @Published var album = ""
    @Published var progress: Double = 0
    @Published var cover: NSImage?
    var onActive: ((Bool) -> Void)? // fired on main when active flips (drives window click-through)

    private let poll = DispatchQueue(label: "sh.dotfiles.medianotch.mpc")
    private var timer: Timer?
    private var coverFile = ""            // poll-thread-confined cache key

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func toggle() { poll.async { _ = runMPC(["toggle"]); self.refreshSync() } }
    func next()   { poll.async { _ = runMPC(["next"]);   self.refreshSync() } }
    func prev()   { poll.async { _ = runMPC(["prev"]);   self.refreshSync() } }

    private func refresh() { poll.async { self.refreshSync() } }

    // Runs on the poll queue; publishes on main.
    private func refreshSync() {
        let status = mpcString(["status"])
        let isPlaying = status.contains("[playing]")
        let isPaused = status.contains("[paused]")

        let fields = mpcString(["-f", "%artist%\t%title%\t%album%\t%file%", "current"])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\t")
        let file = fields.count > 3 ? fields[3] : ""
        // Show only while actively playing — hidden when paused or stopped.
        let isActive = !file.isEmpty && isPlaying
        _ = isPaused
        let frac = parseProgress(status)

        var fetched: NSImage?
        var coverChanged = false
        if isActive, file != coverFile {
            coverFile = file
            fetched = NSImage(data: runMPC(["readpicture", file])) // nil if no embedded art
            coverChanged = true
        } else if !isActive, !coverFile.isEmpty {
            coverFile = ""
            coverChanged = true // clear
        }

        DispatchQueue.main.async {
            let title = fields.count > 1 ? fields[1] : ""
            let artist = fields.first ?? ""
            let album = fields.count > 2 ? fields[2] : ""
            // Only publish what actually changed — no per-tick redraw churn.
            if self.playing != isPlaying { self.playing = isPlaying }
            if self.title != title { self.title = title }
            if self.artist != artist { self.artist = artist }
            if self.album != album { self.album = album }
            if self.progress != frac { self.progress = frac }
            if coverChanged { self.cover = fetched }
            if self.active != isActive { self.active = isActive; self.onActive?(isActive) }
        }
    }
}

// MARK: - View

struct MediaNotchView: View {
    @ObservedObject var model: MusicModel
    let topInset: CGFloat            // physical notch height (0 on external displays)
    let hit: HitProxy               // reports the blob's live rect for click-through hit testing
    @State private var expanded = false
    @State private var breathePhase = false
    @State private var hoverWork: DispatchWorkItem? // hover-intent debounce

    // Gentle "breathing" pulse (driven by updateBreathing while playing+collapsed).
    private var breatheScale: CGFloat { breathePhase ? 1.016 : 1.0 }
    private var metaWidth: CGFloat { expanded ? 208 : 168 }

    // Square top (flush to bezel), rounded bottom — the blob SketchyBar can't draw.
    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 18,
                               bottomTrailingRadius: 18, topTrailingRadius: 0)
    }

    private var coverRadius: CGFloat { expanded ? 12 : 5 }

    private var coverView: some View {
        Group {
            if let img = model.cover {
                // No aspectRatio: album art is square, so resizable fills the square
                // frame exactly — avoids fill/clip recompute jitter while it scales.
                Image(nsImage: img).resizable().interpolation(.high)
            } else {
                Rectangle().fill(Color(white: 0.18))
                    .overlay(Image(systemName: "music.note").foregroundStyle(.white.opacity(0.5)))
            }
        }
        .frame(width: expanded ? 62 : 22, height: expanded ? 62 : 22)
        .clipShape(RoundedRectangle(cornerRadius: coverRadius))
        .overlay(RoundedRectangle(cornerRadius: coverRadius).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    var body: some View {
        VStack(spacing: 0) {
            blob
                .scaleEffect(breatheScale, anchor: .top)
                .background(GeometryReader { g in
                    // Report the blob's live rect so the AppKit hit test only
                    // intercepts clicks here — everything else falls through.
                    Color.clear.onChange(of: g.frame(in: .named("win")), initial: true) { _, f in hit.rect = f }
                })
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, topInset) // clear the physical camera notch; 0 → flush-centered on external displays
        .coordinateSpace(.named("win"))
        .opacity(model.active ? 1 : 0)
        // Gooey emerge: stretch down from the bezel (y leads x), anchored at the top so it
        // never detaches (no gap), with a wobbly bounce — oozes out and retracts.
        .scaleEffect(x: model.active ? 1 : 0.86, y: model.active ? 1 : 0.5, anchor: .top)
        .animation(.bouncy(duration: 0.6, extraBounce: 0.42), value: model.active)
        .ignoresSafeArea(.all)
        .onAppear { updateBreathing() }
        .onChange(of: model.playing) { _, _ in updateBreathing() }
        .onChange(of: expanded) { _, _ in updateBreathing() }
        .onChange(of: model.active, initial: true) { _, a in hit.active = a }
    }

    private func updateBreathing() {
        if model.playing && !expanded {
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) { breathePhase = true }
        } else {
            withAnimation(.easeInOut(duration: 0.4)) { breathePhase = false }
        }
    }

    private var blob: some View {
        VStack(spacing: 11) {
            HStack(spacing: expanded ? 12 : 10) {
                coverView
                VStack(alignment: .leading, spacing: 2) {
                    // Constant font sizes: text width never changes mid-expand → no measurement jitter.
                    Marquee(text: model.title.isEmpty ? "—" : model.title,
                            font: .system(size: 13, weight: .semibold),
                            color: .white, maxWidth: metaWidth)
                    Marquee(text: model.artist,
                            font: .system(size: 11.5),
                            color: Color(white: 0.70), maxWidth: metaWidth)
                    if expanded, !model.album.isEmpty {
                        Marquee(text: model.album,
                                font: .system(size: 11),
                                color: Color(white: 0.5), maxWidth: metaWidth)
                            .transition(.opacity)
                    }
                }
                if expanded { Spacer(minLength: 0) }
            }

            if expanded {
                VStack(spacing: 13) {
                    progressBar
                    HStack(spacing: 30) {
                        control("backward.fill", size: 15) { model.prev() }
                        control(model.playing ? "pause.fill" : "play.fill", size: 19) { model.toggle() }
                        control("forward.fill", size: 15) { model.next() }
                    }
                    .frame(maxWidth: .infinity)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, expanded ? 12 : 7)
        .padding(.bottom, expanded ? 15 : 7)
        .frame(width: expanded ? 320 : 236, alignment: .top) // fixed widths per state → spring interpolates two numbers, no measurement jitter
        .background(shape.fill(Color.black))
        .overlay(shape.stroke(Color(white: 0.20), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 14, y: 5)
        .onHover { hovering in
            // Hover intent: only expand after a short dwell so moving the mouse
            // *past* the pill (to click something near it) never balloons the hit area.
            hoverWork?.cancel()
            guard hovering else { expanded = false; return }
            let work = DispatchWorkItem { expanded = true }
            hoverWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: work)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.78), value: expanded)
        .animation(.spring(response: 0.4, dampingFraction: 0.78), value: model.active)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.16))
                Capsule().fill(accent).frame(width: max(0, geo.size.width * model.progress))
            }
        }
        .frame(height: 3)
        .animation(.linear(duration: 0.9), value: model.progress)
    }

    private func control(_ symbol: String, size: CGFloat, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: size + 16, height: size + 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Marquee

// Scrolls its text slowly, and only when it overflows maxWidth; otherwise it
// hugs the text and stays still.
struct Marquee: View {
    let text: String
    let font: Font
    let color: Color
    let maxWidth: CGFloat

    @State private var textWidth: CGFloat = 0
    @State private var shift = false

    private var overflow: CGFloat { max(0, textWidth - maxWidth) }

    var body: some View {
        Text(text)
            .font(font).foregroundStyle(color).lineLimit(1).fixedSize()
            .background(GeometryReader { g in
                Color.clear.onChange(of: g.size.width, initial: true) { _, w in textWidth = w }
            })
            .offset(x: shift ? -overflow : 0)
            .frame(width: maxWidth, alignment: .leading) // fixed column — text scrolls within, never drives layout
            .clipped()
            .onChange(of: text) { _, _ in restart() }
            .onChange(of: textWidth) { _, _ in restart() }
            .onChange(of: maxWidth) { _, _ in restart() }
    }

    // Reset to start (covers the expand transition), then slowly scroll if overflowing.
    private func restart() {
        shift = false
        guard overflow > 0 else { return }
        let duration = Double(overflow) / 18.0 + 1.0 // ~18 pt/s: slow, proportional to overflow
        withAnimation(.easeInOut(duration: duration).delay(1.2).repeatForever(autoreverses: true)) {
            shift = true
        }
    }
}

// MARK: - Click-through hosting

// Shared blob rect (window/top-left coords) so the AppKit hit test can pass
// clicks through the transparent overlay everywhere except the visible blob.
final class HitProxy { var rect: CGRect = .zero; var active = false }

final class PassthroughHostingView: NSHostingView<MediaNotchView> {
    var hit = HitProxy()

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard hit.active else { return nil } // hidden (animating out / gone) → click-through
        let local = convert(point, from: nil) // window base coords -> this (flipped) view
        return hit.rect.contains(local) ? super.hitTest(point) : nil
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private let model = MusicModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let screen = NSScreen.main else { NSApp.terminate(nil); return }
        let topInset = screen.safeAreaInsets.top // notch height on built-in display; 0 on external
        let width: CGFloat = 380, height: CGFloat = topInset + 210
        let vf = screen.frame
        let rect = NSRect(x: vf.midX - width / 2, y: vf.maxY - height, width: width, height: height)

        let win = NSWindow(contentRect: rect, styleMask: [.borderless], backing: .buffered, defer: false)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false // SwiftUI draws the shaped shadow
        win.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel())) // above menu bar/notch
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        win.ignoresMouseEvents = true // starts hidden (no track) → whole window is click-through
        let hit = HitProxy()
        let hosting = PassthroughHostingView(rootView: MediaNotchView(model: model, topInset: topInset, hit: hit))
        hosting.hit = hit
        hosting.safeAreaRegions = []   // we position manually via topInset
        win.contentView = hosting
        window = win

        NSApp.setActivationPolicy(.accessory) // no Dock icon

        // Window stays ordered front; SwiftUI animates the notch in/out via
        // opacity + offset, and the hit test passes clicks through while hidden.
        win.orderFrontRegardless()

        // Whole-window click-through while hidden; interactive only while a track
        // is playing (then per-blob hit testing handles the transparent margins).
        model.onActive = { [weak win] active in win?.ignoresMouseEvents = !active }

        model.start()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
