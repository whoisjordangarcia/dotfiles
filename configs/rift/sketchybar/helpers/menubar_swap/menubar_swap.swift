// Hands the top of the screen to the macOS menu bar on demand: with the menu bar
// on auto-hide, touching the top edge reveals it, so this hides SketchyBar at
// the same moment (they overlap), and shows it again once the pointer drops
// below the menu bar, which macOS hides on its own. SketchyBar can't react to
// the pointer itself, so this polls it (no TCC permission needed, unlike taps).
//
// Hiding slides the bar up off-screen (an animated y_offset) rather than
// toggling `hidden`, which SketchyBar can't animate.
//
// Usage: menubar_swap <menu-bar-height-px> <shown-y_offset> <hidden-y_offset>
//        menubar_swap --height   prints the main display's menu bar height and exits
//        menubar_swap --notch    prints 1 if any active display has a notch, else 0

import AppKit

// The menu bar's real height, from its Window Server window. With auto-hide on,
// NSScreen.visibleFrame reserves nothing and NSStatusBar.thickness is a legacy
// constant (22), so neither reports it.
if CommandLine.arguments.dropFirst().first == "--height" {
	let windows = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
	let height = windows.lazy
		.filter { $0[kCGWindowName as String] as? String == "Menubar" }
		.compactMap { $0[kCGWindowBounds as String] as? [String: Any] }
		.first { ($0["X"] as? Int) == 0 }?["Height"] as? Int
	print(height ?? 24)
	exit(0)
}
if CommandLine.arguments.dropFirst().first == "--notch" {
	print(NSScreen.screens.contains { $0.safeAreaInsets.top > 0 } ? 1 : 0)
	exit(0)
}

let args = CommandLine.arguments.dropFirst().compactMap { Double($0) }
let zone = CGFloat(args.count > 0 ? args[0] : 40)
let shownY = args.count > 1 ? Int(args[1]) : 8
let hiddenY = args.count > 2 ? Int(args[2]) : -60
var hidden: Bool?

func setHidden(_ h: Bool) {
	guard h != hidden else { return }
	hidden = h
	let p = Process()
	p.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/sketchybar")
	// 15 frames ≈ 250ms at 60fps
	p.arguments = ["--animate", "tanh", "15", "--bar", "y_offset=\(h ? hiddenY : shownY)"]
	try? p.run()
}

setHidden(false)
// ponytail: 100ms poll (~0% CPU); swap for a CGEventTap if it ever shows up in Activity Monitor
Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
	let m = NSEvent.mouseLocation
	guard let s = NSScreen.screens.first(where: { NSMouseInRect(m, $0.frame, false) }) else { return }
	let fromTop = s.frame.maxY - m.y
	if fromTop <= 1 { setHidden(true) } else if fromTop > zone { setHidden(false) }
}
RunLoop.main.run()
