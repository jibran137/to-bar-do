// generate-appicon.swift — (re)generates the macOS app icon set.
//
// Draws the "checklist" SF Symbol (same glyph as the menu bar item) in white on
// a blue gradient tile, at every size the AppIcon set needs, writing the PNGs
// straight into AppIcon.appiconset. Pure AppKit, no dependencies.
//
// Usage (from the repo root):
//   swift scripts/generate-appicon.swift ToBarDo/ToBarDo/Assets.xcassets/AppIcon.appiconset
//
// Edit the colors / glyph / point size below to restyle, then re-run.

import AppKit

let outDir = CommandLine.arguments[1]

/// Renders one square icon at the given pixel size and returns PNG data.
func renderIcon(pixels: Int) -> Data {
    let size = CGFloat(pixels)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Rounded-rect tile, macOS-style (content inset from the canvas edge).
    let margin = size * 0.085
    let rect = CGRect(x: margin, y: margin, width: size - 2 * margin, height: size - 2 * margin)
    let radius = rect.width * 0.2237
    let tile = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    let top = NSColor(srgbRed: 0.33, green: 0.66, blue: 1.00, alpha: 1)
    let bottom = NSColor(srgbRed: 0.13, green: 0.40, blue: 0.93, alpha: 1)
    NSGradient(starting: top, ending: bottom)!.draw(in: tile, angle: -90)

    // White "checklist" glyph, centered — same symbol as the menu bar item.
    let cfg = NSImage.SymbolConfiguration(pointSize: size * 0.42, weight: .semibold)
    if let base = NSImage(systemSymbolName: "checklist", accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg) {
        let glyphSize = base.size
        let white = NSImage(size: glyphSize)
        white.lockFocus()
        base.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
        NSColor.white.set()
        NSRect(origin: .zero, size: glyphSize).fill(using: .sourceAtop)
        white.unlockFocus()
        let origin = CGPoint(x: (size - glyphSize.width) / 2, y: (size - glyphSize.height) / 2)
        white.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 1)
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// filename -> pixel size for the standard mac AppIcon slots.
let files: [(String, Int)] = [
    ("icon_16.png", 16), ("icon_16@2x.png", 32),
    ("icon_32.png", 32), ("icon_32@2x.png", 64),
    ("icon_128.png", 128), ("icon_128@2x.png", 256),
    ("icon_256.png", 256), ("icon_256@2x.png", 512),
    ("icon_512.png", 512), ("icon_512@2x.png", 1024),
]

for (name, px) in files {
    let data = renderIcon(pixels: px)
    try! data.write(to: URL(fileURLWithPath: outDir).appendingPathComponent(name))
    print("wrote \(name) (\(px)px)")
}
