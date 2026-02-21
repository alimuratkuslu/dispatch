#!/usr/bin/env swift
import AppKit
import CoreGraphics

// MARK: - Icon drawing

func makeIcon(size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size), pixelsHigh: Int(size),
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }
    guard let ctx = NSGraphicsContext.current?.cgContext else { return rep }

    // ── Background: deep navy → indigo gradient ──────────────────────────
    let r = size * 0.225
    let roundedPath = CGPath(
        roundedRect: CGRect(x: 0, y: 0, width: size, height: size),
        cornerWidth: r, cornerHeight: r, transform: nil
    )
    ctx.addPath(roundedPath)
    ctx.clip()

    let cs = CGColorSpaceCreateDeviceRGB()
    let colors: [CGColor] = [
        CGColor(red: 0.04, green: 0.12, blue: 0.30, alpha: 1),   // deep navy (top-left)
        CGColor(red: 0.22, green: 0.10, blue: 0.58, alpha: 1),   // rich indigo (bottom-right)
    ]
    let grad = CGGradient(colorsSpace: cs, colors: colors as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(
        grad,
        start: CGPoint(x: 0, y: size),
        end: CGPoint(x: size, y: 0),
        options: []
    )

    // ── Subtle inner glow ring ────────────────────────────────────────────
    ctx.addPath(roundedPath)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.08))
    ctx.setLineWidth(size * 0.012)
    ctx.strokePath()

    // ── Paper plane (drawn with Bezier) ───────────────────────────────────
    // The plane points upper-right; tail at lower-left
    let p = size / 100.0   // unit = 1% of icon size

    // Main body triangle: nose at upper-right, base at left
    let nosePt   = CGPoint(x: 68*p, y: 66*p)
    let tailL    = CGPoint(x: 22*p, y: 54*p)
    let tailR    = CGPoint(x: 38*p, y: 30*p)
    let wingTip  = CGPoint(x: 32*p, y: 62*p)   // left wing leading edge
    let foldPt   = CGPoint(x: 45*p, y: 47*p)   // inner fold

    // Drop shadow
    ctx.setShadow(
        offset: CGSize(width: 0, height: -size * 0.025),
        blur: size * 0.06,
        color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.5)
    )

    // Body
    let body = CGMutablePath()
    body.move(to: nosePt)
    body.addLine(to: tailL)
    body.addLine(to: foldPt)
    body.addLine(to: wingTip)
    body.addLine(to: tailR)
    body.closeSubpath()
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.addPath(body)
    ctx.fillPath()

    ctx.setShadow(offset: .zero, blur: 0, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0))

    // Under-wing fold (slightly transparent to create depth)
    let fold = CGMutablePath()
    fold.move(to: wingTip)
    fold.addLine(to: foldPt)
    fold.addLine(to: CGPoint(x: 38*p, y: 48*p))
    fold.closeSubpath()
    ctx.setFillColor(CGColor(red: 0.55, green: 0.62, blue: 0.95, alpha: 0.85))
    ctx.addPath(fold)
    ctx.fillPath()

    // Trailing streak lines (speed lines)
    ctx.setLineCap(.round)
    let streakColor = CGColor(red: 1, green: 1, blue: 1, alpha: 0.28)
    ctx.setStrokeColor(streakColor)

    let streaks: [(CGPoint, CGPoint, CGFloat)] = [
        (CGPoint(x: 18*p, y: 46*p), CGPoint(x:  8*p, y: 44*p), 2.4*p),
        (CGPoint(x: 15*p, y: 38*p), CGPoint(x:  4*p, y: 35*p), 1.8*p),
        (CGPoint(x: 14*p, y: 30*p), CGPoint(x:  6*p, y: 26*p), 1.2*p),
    ]
    for (start, end, width) in streaks {
        ctx.setLineWidth(width)
        ctx.move(to: start)
        ctx.addLine(to: end)
        ctx.strokePath()
    }

    return rep
}

// MARK: - Generate all sizes

let iconDir = "Dispatch/Resources/Assets.xcassets/AppIcon.appiconset"

// (filename, pixel size)
let sizes: [(String, CGFloat)] = [
    ("icon_16x16.png",        16),
    ("icon_16x16@2x.png",     32),
    ("icon_32x32.png",        32),
    ("icon_32x32@2x.png",     64),
    ("icon_128x128.png",     128),
    ("icon_128x128@2x.png",  256),
    ("icon_256x256.png",     256),
    ("icon_256x256@2x.png",  512),
    ("icon_512x512.png",     512),
    ("icon_512x512@2x.png", 1024),
]

for (filename, pixels) in sizes {
    let rep = makeIcon(size: pixels)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        print("❌ Failed to encode \(filename)")
        continue
    }
    let path = "\(iconDir)/\(filename)"
    do {
        try png.write(to: URL(fileURLWithPath: path))
        print("✅ \(filename) (\(Int(pixels))px)")
    } catch {
        print("❌ \(filename): \(error)")
    }
}

print("\nDone — icon files written to \(iconDir)")
