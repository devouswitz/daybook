// Generates the 1024px master app icon PNG.
// Usage: swift tools/make_icon.swift <output.png>
import AppKit

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
let pixels = 1024

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixels,
    pixelsHigh: pixels,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("Could not create bitmap rep")
}
rep.size = NSSize(width: pixels, height: pixels)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let size = CGFloat(pixels)
let inset: CGFloat = size * 0.08
let iconRect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let radius = iconRect.width * 0.225
let squircle = NSBezierPath(roundedRect: iconRect, xRadius: radius, yRadius: radius)

let top = NSColor(calibratedRed: 0.42, green: 0.36, blue: 0.91, alpha: 1)
let bottom = NSColor(calibratedRed: 0.24, green: 0.18, blue: 0.55, alpha: 1)
NSGradient(starting: top, ending: bottom)?.draw(in: squircle, angle: -70)

// White book symbol, centered
let config = NSImage.SymbolConfiguration(pointSize: size * 0.42, weight: .medium)
if let symbol = NSImage(systemSymbolName: "book.closed.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(config) {
    let tinted = NSImage(size: symbol.size, flipped: false) { r in
        symbol.draw(in: r)
        NSColor.white.set()
        r.fill(using: .sourceAtop)
        return true
    }
    let s = tinted.size
    let origin = NSPoint(x: (size - s.width) / 2, y: (size - s.height) / 2)
    tinted.draw(in: NSRect(origin: origin, size: s))
}

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode PNG")
}
try png.write(to: URL(fileURLWithPath: outPath))
print("Wrote \(outPath)")
