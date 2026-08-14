#!/usr/bin/env swift
// Generates the app icon set: rounded gradient square + display glyph + "HD" badge.
import AppKit

let args = CommandLine.arguments
guard args.count > 1 else {
    print("usage: make-icon.swift <output.iconset dir>")
    exit(1)
}
let outDir = URL(fileURLWithPath: args[1], isDirectory: true)

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let inset = size * 0.05
    let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let radius = size * 0.22
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.33, green: 0.42, blue: 1.00, alpha: 1),
        NSColor(calibratedRed: 0.62, green: 0.32, blue: 0.95, alpha: 1),
    ])
    gradient?.draw(in: path, angle: -60)

    // Display glyph (screen + stand)
    let white = NSColor.white
    let screenW = rect.width * 0.62
    let screenH = rect.height * 0.40
    let screenRect = NSRect(
        x: rect.midX - screenW / 2,
        y: rect.midY - screenH / 2 + rect.height * 0.08,
        width: screenW, height: screenH)
    let screenPath = NSBezierPath(roundedRect: screenRect, xRadius: size * 0.035, yRadius: size * 0.035)
    screenPath.lineWidth = size * 0.035
    white.setStroke()
    screenPath.stroke()

    let standW = rect.width * 0.20
    let standRect = NSRect(
        x: rect.midX - standW / 2,
        y: screenRect.minY - rect.height * 0.14,
        width: standW, height: size * 0.030)
    white.setFill()
    NSBezierPath(roundedRect: standRect, xRadius: standRect.height / 2, yRadius: standRect.height / 2).fill()
    let poleRect = NSRect(
        x: rect.midX - size * 0.016,
        y: standRect.maxY,
        width: size * 0.032,
        height: screenRect.minY - standRect.maxY)
    NSBezierPath(rect: poleRect).fill()

    // "HD" text inside screen
    let fontSize = screenH * 0.52
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .heavy),
        .foregroundColor: white,
    ]
    let text = "HD" as NSString
    let textSize = text.size(withAttributes: attrs)
    text.draw(at: NSPoint(x: screenRect.midX - textSize.width / 2,
                          y: screenRect.midY - textSize.height / 2),
              withAttributes: attrs)

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, pixels: Int, to url: URL) {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return }
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    if let data = rep.representation(using: .png, properties: [:]) {
        try? data.write(to: url)
    }
}

let sizes: [(name: String, px: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

let master = drawIcon(size: 1024)
for s in sizes {
    savePNG(master, pixels: s.px, to: outDir.appendingPathComponent("\(s.name).png"))
}
print("icon set written to \(outDir.path)")
