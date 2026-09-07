#!/usr/bin/env swift
import AppKit
import Foundation

let outputURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Resources/AppIcon.icns")
let root = outputURL.deletingLastPathComponent()
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
let iconsetURL = root.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

func image(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    let bounds = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    bounds.fill()

    let radius = size * 0.22
    let backgroundPath = NSBezierPath(roundedRect: bounds.insetBy(dx: size * 0.06, dy: size * 0.06), xRadius: radius, yRadius: radius)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.10, green: 0.34, blue: 0.80, alpha: 1),
        NSColor(calibratedRed: 0.13, green: 0.62, blue: 0.42, alpha: 1),
    ])?.draw(in: backgroundPath, angle: 315)

    let lineWidth = max(3, size * 0.045)
    let branch = NSBezierPath()
    branch.lineWidth = lineWidth
    branch.lineCapStyle = .round
    branch.lineJoinStyle = .round
    branch.move(to: NSPoint(x: size * 0.30, y: size * 0.33))
    branch.line(to: NSPoint(x: size * 0.48, y: size * 0.50))
    branch.line(to: NSPoint(x: size * 0.70, y: size * 0.68))
    branch.move(to: NSPoint(x: size * 0.48, y: size * 0.50))
    branch.line(to: NSPoint(x: size * 0.70, y: size * 0.36))
    NSColor.white.withAlphaComponent(0.92).setStroke()
    branch.stroke()

    for point in [NSPoint(x: size * 0.30, y: size * 0.33), NSPoint(x: size * 0.48, y: size * 0.50), NSPoint(x: size * 0.70, y: size * 0.68), NSPoint(x: size * 0.70, y: size * 0.36)] {
        let nodeRect = NSRect(x: point.x - size * 0.045, y: point.y - size * 0.045, width: size * 0.09, height: size * 0.09)
        NSColor.white.setFill()
        NSBezierPath(ovalIn: nodeRect).fill()
    }

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let font = NSFont.systemFont(ofSize: size * 0.22, weight: .bold)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraph,
    ]
    let textRect = NSRect(x: 0, y: size * 0.12, width: size, height: size * 0.24)
    NSString(string: "WT").draw(in: textRect, withAttributes: attrs)

    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGeneration", code: 1)
    }
    try data.write(to: url)
}

let specs: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, size) in specs {
    try writePNG(image(size: size), to: iconsetURL.appendingPathComponent(name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()
if process.terminationStatus != 0 {
    throw NSError(domain: "IconGeneration", code: Int(process.terminationStatus))
}

try? FileManager.default.removeItem(at: iconsetURL)
