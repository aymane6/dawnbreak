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
// The mark is the moment the app is named after: the sun breaking over the curve of the horizon,
// in a sky that is still night at the top and already morning at the bottom. It replaced a flat
// half-disc under a halo arc, which read clearly and said nothing. What survives at 40pt on a
// home screen is a bright curve with a warm light on it, over a dark ground, and that is still
// nothing like Apple's Clock icon, which a wake-up app has to be careful about.
//
// Light is drawn as light: every glow is a blurred copy of a shape screened onto the picture,
// which is why this needs CoreImage and float layers. An 8-bit bitmap bands visibly in a sky
// this dark, so the picture is drawn in float and dithered once, at the very end.

import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

let side = 1024
let size = CGFloat(side)

// MARK: - Palettes

/// One appearance of the icon. In the `any` palette the band just above the horizon is
/// `Theme.accent` and the sun's edge is `Theme.dawnStart`, so the icon's oranges are the app's.
struct Palette {
    var filename: String
    /// Top edge to horizon.
    var sky: [(CGFloat, UInt32)]
    var starOpacity: CGFloat
    /// The sky lit up around the sun: a hot inner colour fading into a wider, redder one.
    var skyGlow: (inner: UInt32, innerOpacity: CGFloat, outer: UInt32, outerOpacity: CGFloat)
    var bloom: UInt32
    /// Centre to edge.
    var sun: [UInt32]
    /// Horizon to bottom edge.
    var ground: [UInt32]
    var groundWarmth: UInt32
    var groundWarmthOpacity: CGFloat
    /// Where the sun touches the horizon, out to the far ends of the curve.
    var rim: [UInt32]
    var flare: UInt32

    static let any = Palette(
        filename: "AppIcon.png",
        sky: [(0, 0x0C0F2E), (0.30, 0x221A50), (0.55, 0x562869), (0.73, 0xAE4169), (0.87, 0xFF7F52), (1, 0xFFBC7A)],
        starOpacity: 1,
        skyGlow: (0xFFB070, 0.80, 0xFF8A5C, 0.30),
        bloom: 0xFFCC88,
        sun: [0xFFFAEC, 0xFFE6AE, 0xFFBE6A, 0xFFA24B],
        ground: [0x241533, 0x150F29, 0x090816],
        groundWarmth: 0x7A3350, groundWarmthOpacity: 0.75,
        rim: [0xFFF4DC, 0xFFC47E, 0xFF8A66, 0xC0608A],
        flare: 0xFFEAD0
    )

    /// An hour earlier: the night reaches further down and the warm band is narrower. The system
    /// draws this one against a dark home screen, where the `any` sky would be the brightest
    /// thing on it, and a lit square in a dark room reads as a hole rather than a sunrise.
    static let dark = Palette(
        filename: "AppIcon-Dark.png",
        sky: [(0, 0x04051A), (0.34, 0x0E0E2E), (0.60, 0x261642), (0.78, 0x5E2352), (0.91, 0xC2484C), (1, 0xFF8A52)],
        starOpacity: 1.4,
        skyGlow: (0xFF9A5A, 0.70, 0xE0584E, 0.26),
        bloom: 0xFFB070,
        sun: [0xFFF6E0, 0xFFD890, 0xFFA850, 0xFF8C40],
        ground: [0x140C1E, 0x0A0714, 0x04030A],
        groundWarmth: 0x5A2238, groundWarmthOpacity: 0.7,
        rim: [0xFFEBC8, 0xFFB064, 0xFF7050, 0xA04070],
        flare: 0xFFDDB8
    )

    /// Greyscale, because the system tints this one itself and colour in it would fight the
    /// user's chosen tint. The system reads it as a light map, so the sun and the horizon carry
    /// the white and the ground stays black. Kept opaque like the other two so App Store
    /// validation, which rejects an alpha channel in the marketing icon, has nothing to
    /// complain about.
    static let tinted = Palette(
        filename: "AppIcon-Tinted.png",
        sky: [(0, 0x000000), (0.34, 0x0C0C0C), (0.60, 0x262626), (0.78, 0x4A4A4A), (0.91, 0x7A7A7A), (1, 0x9E9E9E)],
        starOpacity: 1.2,
        skyGlow: (0xB0B0B0, 0.55, 0x808080, 0.22),
        bloom: 0xDDDDDD,
        sun: [0xFFFFFF, 0xF4F4F4, 0xE2E2E2, 0xD2D2D2],
        ground: [0x141414, 0x0A0A0A, 0x000000],
        groundWarmth: 0x303030, groundWarmthOpacity: 0.6,
        rim: [0xFFFFFF, 0xE0E0E0, 0xA0A0A0, 0x606060],
        flare: 0xFFFFFF
    )
}

// MARK: - Drawing helpers

let colourSpace = CGColorSpace(name: CGColorSpace.sRGB)!

func colour(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func gradient(_ stops: [(CGFloat, CGColor)]) -> CGGradient {
    CGGradient(colorsSpace: colourSpace, colors: stops.map(\.1) as CFArray, locations: stops.map(\.0))!
}

func disc(_ centre: CGPoint, _ radius: CGFloat) -> CGRect {
    CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2)
}

/// A float layer with y pointing down, so the coordinates below read top to bottom like the
/// picture does.
func makeLayer() -> CGContext {
    let info = CGImageAlphaInfo.premultipliedLast.rawValue
        | CGBitmapInfo.floatComponents.rawValue
        | CGBitmapInfo.byteOrder32Little.rawValue
    guard let context = CGContext(
        data: nil,
        width: side,
        height: side,
        bitsPerComponent: 32,
        bytesPerRow: 0,
        space: colourSpace,
        bitmapInfo: info
    ) else {
        fatalError("could not allocate a \(side)×\(side) float layer")
    }
    context.translateBy(x: 0, y: size)
    context.scaleBy(x: 1, y: -1)
    context.interpolationQuality = .high
    return context
}

/// Draws `image` over the whole of `context`. The layer is flipped, so the image is flipped
/// back first or it would land upside down.
func composite(_ image: CGImage, onto context: CGContext, alpha: CGFloat) {
    context.saveGState()
    context.translateBy(x: 0, y: size)
    context.scaleBy(x: 1, y: -1)
    context.setBlendMode(.screen)
    context.setAlpha(alpha)
    context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
    context.restoreGState()
}

let renderer = CIContext(options: [.outputColorSpace: colourSpace, .workingFormat: CIFormat.RGBAf])

func blurred(_ image: CGImage, sigma: CGFloat) -> CGImage {
    let input = CIImage(cgImage: image)
    let output = input.clampedToExtent().applyingGaussianBlur(sigma: sigma).cropped(to: input.extent)
    guard let result = renderer.createCGImage(output, from: input.extent, format: .RGBAf, colorSpace: colourSpace) else {
        fatalError("could not blur a layer")
    }
    return result
}

/// Light: whatever `shape` draws, screened onto `context` once per pass at that pass's blur (a
/// sigma of 0 is the shape itself, sharp). Several passes at falling sigma give a hot core and a
/// long falloff together, which no single blur can.
func glow(onto context: CGContext, _ passes: [(sigma: CGFloat, alpha: CGFloat)], _ shape: (CGContext) -> Void) {
    let layer = makeLayer()
    shape(layer)
    guard let image = layer.makeImage() else { fatalError("could not snapshot a layer") }
    for pass in passes {
        composite(pass.sigma > 0 ? blurred(image, sigma: pass.sigma) : image, onto: context, alpha: pass.alpha)
    }
}

/// A small deterministic generator, so the dither and therefore the checked-in PNGs come out
/// identical on every run.
struct Dither {
    var state: UInt64 = 0xDA7B_12EA

    /// Triangular noise in -1...1: two uniform draws summed, which hides banding with less
    /// visible grain than one uniform draw of the same width.
    mutating func next() -> Float {
        unit() + unit() - 1
    }

    private mutating func unit() -> Float {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return Float((z ^ (z >> 31)) >> 40) / Float(1 << 24)
    }
}

/// The float picture as 8-bit RGB, dithered by a fraction of a level so the long dark gradients
/// of the sky do not step. No alpha channel at all, rather than an opaque one: `noneSkipLast`
/// makes ImageIO write a three-channel PNG, which is what the App Store's icon check wants.
func flatten(_ context: CGContext) -> CGImage {
    guard let data = context.data else { fatalError("the layer has no pixels") }
    let floatsPerRow = context.bytesPerRow / MemoryLayout<Float>.size
    let source = data.bindMemory(to: Float.self, capacity: floatsPerRow * side)
    var pixels = [UInt8](repeating: 255, count: side * side * 4)
    var dither = Dither()
    for y in 0..<side {
        for x in 0..<side {
            let from = y * floatsPerRow + x * 4
            let to = (y * side + x) * 4
            let alpha = max(source[from + 3], 1e-6)
            for channel in 0..<3 {
                let value = source[from + channel] / alpha * 255 + dither.next()
                pixels[to + channel] = UInt8(max(0, min(255, value.rounded())))
            }
        }
    }
    guard
        let provider = CGDataProvider(data: Data(pixels) as CFData),
        let image = CGImage(
            width: side,
            height: side,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: side * 4,
            space: colourSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    else {
        fatalError("could not build the 8-bit image")
    }
    return image
}

// MARK: - The picture

/// A few stars, placed by hand high in the sky where the night still is. They vanish below 120pt,
/// which is right: at home-screen size they would only be noise.
let stars: [(x: CGFloat, y: CGFloat, radius: CGFloat, opacity: CGFloat)] = [
    (168, 128, 2.4, 0.75), (818, 100, 2.0, 0.65), (330, 66, 1.5, 0.5), (912, 238, 1.4, 0.4), (606, 150, 1.1, 0.35),
]

func draw(_ palette: Palette) -> CGImage {
    let context = makeLayer()
    // The horizon is the top of a circle far wider than the icon, so it curves gently away on
    // both sides. The sun sits a little below that line, so a thin slice of it is still hidden.
    let horizon: CGFloat = 650
    let earthRadius: CGFloat = 1450
    let earth = CGPoint(x: 512, y: horizon + earthRadius)
    let sunRadius: CGFloat = 196
    let sun = CGPoint(x: 512, y: horizon + 38)

    // Sky, then the stars, then the sky lit up around the sun.
    context.drawLinearGradient(
        gradient(palette.sky.map { ($0.0, colour($0.1)) }),
        start: .zero,
        end: CGPoint(x: 0, y: horizon),
        options: [.drawsAfterEndLocation]
    )
    for star in stars {
        glow(onto: context, [(0, 1), (star.radius * 2.2, 0.5)]) { layer in
            layer.setFillColor(colour(0xFFFFFF, min(1, star.opacity * palette.starOpacity)))
            layer.fillEllipse(in: disc(CGPoint(x: star.x, y: star.y), star.radius))
        }
    }
    context.saveGState()
    context.setBlendMode(.screen)
    context.drawRadialGradient(
        gradient([
            (0, colour(palette.skyGlow.inner, palette.skyGlow.innerOpacity)),
            (0.38, colour(palette.skyGlow.outer, palette.skyGlow.outerOpacity)),
            (1, colour(palette.skyGlow.outer, 0)),
        ]),
        startCenter: sun,
        startRadius: 0,
        endCenter: sun,
        endRadius: 720,
        options: []
    )
    context.restoreGState()

    // The sun: its bloom first, then the disc over it, brightest just above the horizon where
    // the light is coming from rather than at its geometric centre.
    glow(onto: context, [(110, 0.65), (34, 0.6), (10, 0.4)]) { layer in
        layer.setFillColor(colour(palette.bloom))
        layer.fillEllipse(in: disc(sun, sunRadius))
    }
    context.saveGState()
    context.addEllipse(in: disc(sun, sunRadius))
    context.clip()
    context.drawRadialGradient(
        gradient([
            (0, colour(palette.sun[0])),
            (0.40, colour(palette.sun[1])),
            (0.78, colour(palette.sun[2])),
            (1, colour(palette.sun[3])),
        ]),
        startCenter: CGPoint(x: sun.x, y: sun.y - 50),
        startRadius: 0,
        endCenter: sun,
        endRadius: sunRadius,
        options: [.drawsAfterEndLocation]
    )
    context.restoreGState()

    // The ground: the night side of the curve, warmed only where the sun is about to reach it.
    // It is drawn over the sun, which is what hides the sun's lower slice.
    context.saveGState()
    context.addEllipse(in: disc(earth, earthRadius))
    context.clip()
    context.drawLinearGradient(
        gradient([(0, colour(palette.ground[0])), (0.22, colour(palette.ground[1])), (1, colour(palette.ground[2]))]),
        start: CGPoint(x: 0, y: horizon),
        end: CGPoint(x: 0, y: size),
        options: []
    )
    let foot = CGPoint(x: sun.x, y: horizon)
    context.drawRadialGradient(
        gradient([
            (0, colour(palette.groundWarmth, palette.groundWarmthOpacity)),
            (0.35, colour(palette.groundWarmth, palette.groundWarmthOpacity * 0.45)),
            (1, colour(palette.groundWarmth, 0)),
        ]),
        startCenter: foot,
        startRadius: 0,
        endCenter: foot,
        endRadius: 560,
        options: []
    )
    context.restoreGState()

    // The rim of light along the horizon, white where the sun is and fading as the curve falls
    // away. This line is the icon's silhouette at small sizes, so it gets the most passes.
    glow(onto: context, [(0, 1), (3, 0.9), (14, 0.6), (40, 0.35)]) { layer in
        layer.addEllipse(in: disc(earth, earthRadius + 2.5))
        layer.setLineWidth(5)
        layer.replacePathWithStrokedPath()
        layer.clip()
        layer.drawRadialGradient(
            gradient([
                (0, colour(palette.rim[0], 1)),
                (0.16, colour(palette.rim[1], 0.95)),
                (0.46, colour(palette.rim[2], 0.55)),
                (1, colour(palette.rim[3], 0.12)),
            ]),
            startCenter: sun,
            startRadius: 0,
            endCenter: sun,
            endRadius: 640,
            options: [.drawsAfterEndLocation]
        )
    }

    // A flare along the horizon: a thin diamond fading to nothing at its tips. It stops well
    // short of the edges, because the horizon curves away beneath it and a flare that outruns
    // the horizon reads as a line drawn across the sky.
    glow(onto: context, [(1.6, 1)]) { layer in
        let centre = CGPoint(x: sun.x, y: horizon - 1)
        let length: CGFloat = 340
        let width: CGFloat = 4.5
        layer.move(to: CGPoint(x: centre.x + length, y: centre.y))
        layer.addLine(to: CGPoint(x: centre.x, y: centre.y + width))
        layer.addLine(to: CGPoint(x: centre.x - length, y: centre.y))
        layer.addLine(to: CGPoint(x: centre.x, y: centre.y - width))
        layer.closePath()
        layer.clip()
        layer.drawRadialGradient(
            gradient([(0, colour(palette.flare, 0.95)), (0.18, colour(palette.flare, 0.43)), (1, colour(palette.flare, 0))]),
            startCenter: centre,
            startRadius: 0,
            endCenter: centre,
            endRadius: length,
            options: []
        )
    }

    return flatten(context)
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
