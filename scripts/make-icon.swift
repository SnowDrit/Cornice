//
//  make-icon.swift
//  Cornice
//
//  Draws the app icon and writes every size the asset catalogue wants.
//
//  Drawn in code rather than kept as a binary, so changing it is an edit here and a
//  re-run, not a round trip through an image editor by whoever happens to own one.
//
//  Usage: swift scripts/make-icon.swift Cornice/Assets.xcassets/AppIcon.appiconset
//

import AppKit

let outputDirectory = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Cornice/Assets.xcassets/AppIcon.appiconset"

/// What the icon says: a menu bar with its right side occupied and its left side cleared,
/// and the divider that decides where one ends and the other begins.
///
/// It has to survive being 16 points wide, so there are three shapes and no more. The
/// dots merge into a smudge at that size, which is fine, because the divider does not.
func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    let scale = size / 1024
    func s(_ value: CGFloat) -> CGFloat { value * scale }

    NSGraphicsContext.current?.imageInterpolation = .high

    // The rounded square, inset so the artwork sits on the macOS icon grid rather than
    // running to the very edge of the canvas.
    let plate = NSRect(x: s(100), y: s(100), width: s(824), height: s(824))
    let shape = NSBezierPath(roundedRect: plate, xRadius: s(185), yRadius: s(185))

    let background = NSGradient(
        colors: [
            NSColor(calibratedRed: 0.16, green: 0.18, blue: 0.25, alpha: 1),
            NSColor(calibratedRed: 0.09, green: 0.10, blue: 0.15, alpha: 1),
        ])
    background?.draw(in: shape, angle: -90)

    // A hairline along the top edge, which is what a cornice is.
    let lip = NSBezierPath(roundedRect: plate, xRadius: s(185), yRadius: s(185))
    lip.lineWidth = s(6)
    NSColor(calibratedWhite: 1, alpha: 0.14).setStroke()
    lip.stroke()

    // The menu bar itself: a band across the upper half.
    let band = NSRect(x: s(180), y: s(460), width: s(664), height: s(150))
    NSColor(calibratedWhite: 1, alpha: 0.10).setFill()
    NSBezierPath(roundedRect: band, xRadius: s(28), yRadius: s(28)).fill()

    // Icons still on show, on the right of the divider.
    NSColor(calibratedWhite: 1, alpha: 0.92).setFill()
    for index in 0..<3 {
        let x = s(600) + CGFloat(index) * s(90)
        NSBezierPath(ovalIn: NSRect(x: x, y: s(505), width: s(58), height: s(58))).fill()
    }

    // The divider. Deliberately the brightest, tallest thing in the icon: it is the one
    // shape that still reads at 16 points.
    let divider = NSRect(x: s(508), y: s(440), width: s(30), height: s(190))
    NSColor(calibratedRed: 0.45, green: 0.78, blue: 1.0, alpha: 1).setFill()
    NSBezierPath(roundedRect: divider, xRadius: s(15), yRadius: s(15)).fill()

    // Everything left of it has been swept away, so that side stays empty apart from a
    // chevron pointing at where the icons went.
    let chevron = NSBezierPath()
    chevron.move(to: NSPoint(x: s(360), y: s(600)))
    chevron.line(to: NSPoint(x: s(268), y: s(535)))
    chevron.line(to: NSPoint(x: s(360), y: s(470)))
    chevron.lineWidth = s(38)
    chevron.lineCapStyle = .round
    chevron.lineJoinStyle = .round
    NSColor(calibratedWhite: 1, alpha: 0.55).setStroke()
    chevron.stroke()

    return image
}

/// Writes exactly `pixels` by `pixels`.
///
/// The bitmap is built by hand rather than by locking focus on an `NSImage`, because an
/// `NSImage` is measured in points: on a Retina display its backing store comes out at
/// twice the size asked for, and every file lands at double its declared dimensions.
/// `actool` then complains that a 256pt at 2x image is 1024 wide when it should be 512.
func writePNG(_ image: NSImage, pixels: Int, to path: String) {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)
    else {
        print("could not allocate bitmap for \(path)")
        exit(1)
    }
    rep.size = NSSize(width: pixels, height: pixels)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()

    guard let png = rep.representation(using: .png, properties: [:]) else {
        print("could not encode \(path)")
        exit(1)
    }
    try? png.write(to: URL(fileURLWithPath: path))
}

// name, points, scale
let variants: [(String, Int, Int)] = [
    ("16x16", 16, 1), ("16x16@2x", 16, 2),
    ("32x32", 32, 1), ("32x32@2x", 32, 2),
    ("128x128", 128, 1), ("128x128@2x", 128, 2),
    ("256x256", 256, 1), ("256x256@2x", 256, 2),
    ("512x512", 512, 1), ("512x512@2x", 512, 2),
]

try? FileManager.default.createDirectory(
    atPath: outputDirectory, withIntermediateDirectories: true)

let master = drawIcon(size: 1024)
var entries: [String] = []

for (name, points, scale) in variants {
    let pixels = points * scale
    let file = "icon_\(name).png"
    writePNG(master, pixels: pixels, to: "\(outputDirectory)/\(file)")
    entries.append("""
        {
          "filename" : "\(file)",
          "idiom" : "mac",
          "scale" : "\(scale)x",
          "size" : "\(points)x\(points)"
        }
    """)
    print("wrote \(file) at \(pixels)px")
}

let contents = """
{
  "images" : [
\(entries.joined(separator: ",\n"))
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}

"""
try? contents.write(
    toFile: "\(outputDirectory)/Contents.json", atomically: true, encoding: .utf8)
print("wrote Contents.json")
