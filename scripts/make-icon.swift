#!/usr/bin/env swift
//
// Draws the app icon into Resources/Assets.xcassets/AppIcon.appiconset/.
//
// Run from the repo root: `swift scripts/make-icon.swift`.
//
// Code rather than a design file for one reason that matters and one that helps. The one that
// matters: iOS 26 wants three appearances of the same mark (any, dark, tinted), and three hand-
// exported PNGs drift apart the first time the palette moves. Here they are one drawing with
// three palettes, and `Theme.swift` is where the palette comes from. The one that helps: the
// icon is checked in as a PNG, so a fresh clone builds without running this at all.
//
// The mark is a sun sitting exactly on the horizon, with a halo arc above it. Three shapes, no
// text, no small detail: at 40pt on a home screen the silhouette is all that survives, and a
// half-disc on a line is legible at that size. It is also nothing like Apple's Clock icon,
// which a wake-up app has to be careful about.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let side = 1024

// MARK: - Palettes

/// One appearance of the icon. The `any` values are `Theme.canvas`, `Theme.dawnStart` and
/// `Theme.dawnEnd`, so the icon and the app's primary button are the same two oranges.
struct Palette {
    var filename: String
    var skyTop: UInt32
    var skyBottom: UInt32
    var ground: UInt32
    var sunTop: UInt32
    var sunBottom: UInt32
    var halo: UInt32
    var glow: UInt32
    var glowOpacity: CGFloat
    var horizonLine: UInt32

    static let any = Palette(
        filename: "AppIcon.png",
        skyTop: 0x0B0D14, skyBottom: 0x241A2E, ground: 0x090A10,
        sunTop: 0xFFD08A, sunBottom: 0xFF5E62,
        halo: 0xFFA24B, glow: 0xFF7F52, glowOpacity: 0.42,
        horizonLine: 0xFFB877
    )

    /// Deeper sky and a hotter glow. The system draws this one against a dark home screen, and
    /// the `any` palette looks washed out there: the same orange needs more contrast under it.
    static let dark = Palette(
        filename: "AppIcon-Dark.png",
        skyTop: 0x04050A, skyBottom: 0x1A1226, ground: 0x020306,
        sunTop: 0xFFC272, sunBottom: 0xF0424F,
        halo: 0xFF8F33, glow: 0xFF6A3C, glowOpacity: 0.52,
        horizonLine: 0xFFA65C
    )

    /// Greyscale, because the system tints this one itself and colour in it would fight the
    /// user's chosen tint. Kept opaque like the other two so App Store validation, which
    /// rejects an alpha channel in the marketing icon, has nothing to complain about.
    static let tinted = Palette(
        filename: "AppIcon-Tinted.png",
        skyTop: 0x0A0A0A, skyBottom: 0x1E1E1E, ground: 0x060606,
        sunTop: 0xF2F2F2, sunBottom: 0x9C9C9C,
        halo: 0xC8C8C8, glow: 0xB4B4B4, glowOpacity: 0.34,
        horizonLine: 0xDCDCDC
    )
}

// MARK: - Drawing helpers

func colour(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func gradient(_ stops: [(CGFloat, CGColor)]) -> CGGradient {
    CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        colors: stops.map(\.1) as CFArray,
        locations: stops.map(\.0)
    )!
}

/// A bitmap with no alpha channel at all, rather than an opaque one: `noneSkipLast` makes
/// ImageIO write a three-channel PNG, which is what the App Store's icon check wants.
func makeContext() -> CGContext {
    guard let context = CGContext(
        data: nil,
        width: side,
        height: side,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        fatalError("could not allocate a \(side)×\(side) bitmap")
    }
    return context
}

func draw(_ palette: Palette) -> CGImage {
    let context = makeContext()
    let full = CGSize(width: side, height: side)
    let horizon: CGFloat = 380
    let sun = CGPoint(x: 512, y: horizon)
    let sunRadius: CGFloat = 232
    let haloRadius: CGFloat = 352

    // Sky.
    context.saveGState()
    context.clip(to: CGRect(origin: .zero, size: full))
    context.drawLinearGradient(
        gradient([(0, colour(palette.skyBottom)), (0.55, colour(palette.skyTop)), (1, colour(palette.skyTop))]),
        start: CGPoint(x: 0, y: 240),
        end: CGPoint(x: 0, y: 1024),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )
    context.restoreGState()

    // Ground: flat and slightly darker than the sky, so the horizon reads as an edge even
    // when the sun is too small to see.
    context.setFillColor(colour(palette.ground))
    context.fill(CGRect(x: 0, y: 0, width: CGFloat(side), height: horizon))

    // Light spilling onto the ground, as a radial fade rather than a mirrored disc: a mirrored
    // disc has an edge, and an edge below the horizon reads as a second object instead of as
    // the sun's own light.
    // The fade has to reach zero exactly at the bottom edge, not be cut off by the clip: a
    // radial gradient truncated mid-slope leaves a visible horizontal band.
    context.saveGState()
    context.clip(to: CGRect(x: 0, y: 0, width: CGFloat(side), height: horizon))
    context.drawRadialGradient(
        gradient([
            (0, colour(palette.sunBottom, 0.20)),
            (0.45, colour(palette.sunBottom, 0.07)),
            (1, colour(palette.sunBottom, 0)),
        ]),
        startCenter: CGPoint(x: sun.x, y: horizon),
        startRadius: 0,
        endCenter: CGPoint(x: sun.x, y: horizon),
        endRadius: horizon,
        options: []
    )
    context.restoreGState()

    // Glow, above the horizon only. A glow that spills onto the ground looks like fog.
    context.saveGState()
    context.clip(to: CGRect(x: 0, y: horizon, width: CGFloat(side), height: CGFloat(side) - horizon))
    context.drawRadialGradient(
        gradient([
            (0, colour(palette.glow, palette.glowOpacity)),
            (0.45, colour(palette.glow, palette.glowOpacity * 0.45)),
            (1, colour(palette.glow, 0)),
        ]),
        startCenter: sun,
        startRadius: sunRadius * 0.6,
        endCenter: sun,
        endRadius: 520,
        options: []
    )
    context.restoreGState()

    // The sun, centred on the horizon so exactly half of it shows.
    context.saveGState()
    context.clip(to: CGRect(x: 0, y: horizon, width: CGFloat(side), height: CGFloat(side) - horizon))
    context.addEllipse(in: CGRect(x: sun.x - sunRadius, y: sun.y - sunRadius, width: sunRadius * 2, height: sunRadius * 2))
    context.clip()
    context.drawLinearGradient(
        gradient([(0, colour(palette.sunBottom)), (1, colour(palette.sunTop))]),
        start: CGPoint(x: 0, y: horizon),
        end: CGPoint(x: 0, y: horizon + sunRadius),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )
    context.restoreGState()

    // The halo: an arc, not a full ring, because the horizon would cut a full ring into two
    // stubs. Stroked into a clip so it can carry the same gradient as the sun.
    context.saveGState()
    context.addArc(
        center: sun,
        radius: haloRadius,
        startAngle: 14 * .pi / 180,
        endAngle: 166 * .pi / 180,
        clockwise: false
    )
    context.setLineWidth(30)
    context.setLineCap(.round)
    context.replacePathWithStrokedPath()
    context.clip()
    context.drawLinearGradient(
        gradient([(0, colour(palette.sunBottom)), (0.5, colour(palette.halo)), (1, colour(palette.sunTop))]),
        start: CGPoint(x: sun.x - haloRadius, y: 0),
        end: CGPoint(x: sun.x + haloRadius, y: 0),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )
    context.restoreGState()

    // The horizon itself: three stacked lines rather than one, which fakes a soft glow without
    // a blur filter. Each fades out towards the edges, because a bar with hard ends draws
    // attention to where it stops rather than to the light coming off it.
    for (thickness, alpha) in [(CGFloat(14), CGFloat(0.13)), (6, 0.30), (3, 0.90)] {
        context.saveGState()
        context.clip(to: CGRect(x: 56, y: horizon - thickness / 2, width: CGFloat(side) - 112, height: thickness))
        context.drawLinearGradient(
            gradient([
                (0, colour(palette.horizonLine, 0)),
                (0.22, colour(palette.horizonLine, alpha * 0.5)),
                (0.5, colour(palette.horizonLine, alpha)),
                (0.78, colour(palette.horizonLine, alpha * 0.5)),
                (1, colour(palette.horizonLine, 0)),
            ]),
            start: CGPoint(x: 56, y: 0),
            end: CGPoint(x: CGFloat(side) - 56, y: 0),
            options: []
        )
        context.restoreGState()
    }

    guard let image = context.makeImage() else { fatalError("could not snapshot the bitmap") }
    return image
}

// MARK: - Output

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let folder = root.appending(path: "Resources/Assets.xcassets/AppIcon.appiconset")
guard FileManager.default.fileExists(atPath: folder.appending(path: "Contents.json").path) else {
    print("make-icon: run me from the repo root, I cannot find \(folder.path)")
    exit(1)
}

for palette in [Palette.any, .dark, .tinted] {
    let url = folder.appending(path: palette.filename)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("could not open \(url.path) for writing")
    }
    CGImageDestinationAddImage(destination, draw(palette), nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("could not write \(url.path)") }
    let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
    let bytes = (attributes?[.size] as? Int) ?? 0
    print("wrote \(palette.filename)  \(side)×\(side)  \(bytes / 1024) KB")
}
