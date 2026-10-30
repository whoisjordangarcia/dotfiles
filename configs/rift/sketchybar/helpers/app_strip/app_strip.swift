// Draws one workspace's windows as a strip of overlapping rounded tiles, each
// with its app's real icon centred, into a single PNG. Every SketchyBar item
// costs a window per display, so drawing each tile as its own item made a
// reload take 25s+; one image per workspace keeps the item count flat.
//
// Usage: app_strip <out.png> <tile> <icon> <overlap> <corner> <dim-alpha>
//                  <tile-argb> <border-argb> <border-px> <px-per-unit>
//                  <bundle-id>:<1 if focused else 0> ...
// Sizes are in bar units; the canvas is <px-per-unit> pixels per unit.
// Apps that can't be found draw the generic application icon.

import AppKit
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count >= 12,
	let tile = Double(args[2]), let iconSize = Double(args[3]), let overlap = Double(args[4]),
	let corner = Double(args[5]), let dimAlpha = Double(args[6]),
	let tileARGB = UInt32(args[7], radix: 16), let borderARGB = UInt32(args[8], radix: 16),
	let borderPx = Double(args[9]), let unit = Double(args[10])
else { exit(1) }

func color(_ argb: UInt32) -> NSColor {
	NSColor(
		srgbRed: CGFloat((argb >> 16) & 0xff) / 255, green: CGFloat((argb >> 8) & 0xff) / 255,
		blue: CGFloat(argb & 0xff) / 255, alpha: CGFloat((argb >> 24) & 0xff) / 255)
}

let windows = args[11...].map { entry -> (NSImage, Bool) in
	let parts = entry.split(separator: ":", maxSplits: 1).map(String.init)
	let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: parts[0])
	let icon = url.map { NSWorkspace.shared.icon(forFile: $0.path) }
		?? NSWorkspace.shared.icon(for: .applicationBundle)
	return (icon, parts.count > 1 && parts[1] == "1")
}

let step = tile - overlap
let width = Int(((tile + step * Double(windows.count - 1)) * unit).rounded())
let height = Int((tile * unit).rounded())
guard let rep = NSBitmapImageRep(
	bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
	samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
	bytesPerRow: 0, bitsPerPixel: 0)
else { exit(1) }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
for (i, (icon, active)) in windows.enumerated() {
	let x = Double(i) * step * unit
	let rect = NSRect(x: x, y: 0, width: tile * unit, height: tile * unit)
		.insetBy(dx: borderPx / 2, dy: borderPx / 2)
	let path = NSBezierPath(roundedRect: rect, xRadius: corner * unit, yRadius: corner * unit)
	color(tileARGB).setFill()
	path.fill()
	color(borderARGB).setStroke()
	path.lineWidth = borderPx
	path.stroke()
	let inset = (tile - iconSize) / 2 * unit
	icon.draw(
		in: NSRect(x: x + inset, y: inset, width: iconSize * unit, height: iconSize * unit),
		from: .zero, operation: .sourceOver, fraction: active ? 1 : dimAlpha)
}
NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]),
	(try? png.write(to: URL(fileURLWithPath: args[1]))) != nil
else { exit(1) }
