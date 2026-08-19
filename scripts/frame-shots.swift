// Frames the raw screenshots into the images that go on the App Store.
//
// Run through `scripts/shots.sh`, which compiles this together with `Sources/Contract`:
//
//     swiftc -O -parse-as-library scripts/frame-shots.swift \
//       Sources/Contract/CaptureLocale.swift Sources/Contract/CaptureLaunch.swift \
//       -o build/frame-shots
//     build/frame-shots --raw build/shots/raw --out build/shots/framed --app <path to .app>
//
// Compiled with the contract on purpose. `CaptureLocale.all` and `CaptureLaunch.Screen.allCases`
// are the same lists the capture run photographed and the upload reads, so the framing cannot be
// asked for a language the app does not ship or a screen nobody took.
//
// The captions come out of the built app's own `.lproj/Localizable.strings`, not from a table in
// here. A second copy of twelve languages of marketing copy is a second copy to forget to update,
// and the app's copy is the one the tests cover.
//
// CoreText rather than a template with pre-rendered text: three of the twelve languages need a
// font this Mac only picks correctly when asked per language (PingFang for Chinese, Hiragino for
// Japanese, Apple SD Gothic for Korean), Arabic needs the line laid out right to left, and Hindi
// needs Devanagari shaping. Drawing a string with the wrong font produces a row of empty boxes in
// a screenshot on a store page, which is worse than no screenshot at all.

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Palette

/// The app's own tokens, so the frame the screenshot sits in is the same dark the screen is.
/// Copied rather than shared because `Theme` is SwiftUI and this is a command-line tool; the four
/// values are checked against `Theme` by `scripts/asc-preflight.py`.
enum Palette {
    static let canvasTop = rgb(0x1A1526)
    static let canvas = rgb(0x0B0D14)
    static let dawnStart = rgb(0xFFA24B)
    static let dawnEnd = rgb(0xFF5E62)
    static let textPrimary = rgb(0xF6F4F1)
    static let textSecondary = rgb(0x9BA0B5)
    static let hairline = rgb(0x2C3145)

    static func rgb(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
        CGColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

// MARK: - Layout

/// Every measurement, as a fraction of the canvas, so one set of numbers works at both accepted
/// 6.9-inch sizes rather than being retuned when Apple changes the required pixel count.
enum Layout {
    static let captionTop: CGFloat = 0.052
    static let captionWidth: CGFloat = 0.86
    static let captionHeight: CGFloat = 0.075
    static let subcaptionGap: CGFloat = 0.014
    static let subcaptionHeight: CGFloat = 0.055
    static let screenWidth: CGFloat = 0.715
    static let screenTop: CGFloat = 0.235
    /// The bezel around the screenshot, and the radius of the screen's own corners. Both are
    /// proportional to the phone, which is what keeps the drawn frame from looking like a sticker.
    static let bezel: CGFloat = 0.0075
    static let screenRadius: CGFloat = 0.128
}

// MARK: - Reading the strings out of the built app

/// The app's compiled catalog for one language.
///
/// A built `.lproj/Localizable.strings` is a binary plist, which is why this is three lines: the
/// app compiled it, so it is already the exact set of strings that ship.
func strings(inApp app: URL, language: String) throws -> [String: String] {
    let url = app.appending(path: "\(language).lproj/Localizable.strings")
    guard let table = NSDictionary(contentsOf: url) as? [String: String] else {
        throw Failure("no compiled strings at \(url.path) — build the app first")
    }
    return table
}

// MARK: - Text

/// A line of caption, laid out at the largest size that fits the box it was given.
///
/// Shrink-to-fit rather than a fixed size, because the same headline is 16 characters in Japanese
/// and 27 in Russian. A fixed size means either a Russian caption that runs off the canvas or an
/// English one that looks timid, and both are on the store page for years.
///
/// Plain CoreText, not `NSAttributedString`: `.font` and `.foregroundColor` are declared by AppKit,
/// and pulling AppKit into a drawing tool that has no window is how a command-line script starts
/// needing a display to run.
struct Caption {
    let text: String
    let language: String
    let isRightToLeft: Bool
    let color: CGColor
    let weight: CGFloat
    let sizes: [CGFloat]
    let maximumLines: Int

    func draw(in context: CGContext, box: CGRect) throws {
        for size in sizes {
            let framesetter = CTFramesetterCreateWithAttributedString(attributed(size: size))
            let whole = CFRangeMake(0, 0)
            var fitting = CFRangeMake(0, 0)
            let suggested = CTFramesetterSuggestFrameSizeWithConstraints(
                framesetter, whole, nil, CGSize(width: box.width, height: .greatestFiniteMagnitude), &fitting
            )
            // Every character has to be laid out, and in at most the number of lines the design
            // has room for. `SuggestFrameSize` with an unbounded height always fits, so the line
            // count is the real constraint.
            guard fitting.length == text.utf16.count, suggested.height <= box.height else { continue }

            // Centred vertically in its box, so a one-line German caption and a two-line Russian
            // one hang from the same optical centre instead of the same baseline. The extra point
            // of height is CoreText's: a frame exactly as tall as its text sometimes drops the
            // last line.
            let height = suggested.height.rounded(.up) + 1
            let target = CGRect(x: box.minX, y: box.midY - height / 2, width: box.width, height: height)
            let frame = CTFramesetterCreateFrame(framesetter, whole, CGPath(rect: target, transform: nil), nil)
            guard CFArrayGetCount(CTFrameGetLines(frame)) <= maximumLines else { continue }

            CTFrameDraw(frame, context)
            return
        }
        throw Failure("caption does not fit at any size: \(text)")
    }

    private func attributed(size: CGFloat) -> CFAttributedString {
        var alignment = CTTextAlignment.center
        var direction: CTWritingDirection = isRightToLeft ? .rightToLeft : .leftToRight
        var spacing = size * 0.12
        let tracking = weight > 0.4 ? -size * 0.012 : 0

        // The pointers `CTParagraphStyleSetting` holds are read by `CTParagraphStyleCreate` and
        // not kept, so the style has to be created while they are still in scope. Hence the
        // nesting: building the array in the closure and using it outside would be reading
        // three dead stack slots, which produces a paragraph style that is wrong at random.
        let paragraph = withUnsafeBytes(of: &alignment) { alignmentBytes in
            withUnsafeBytes(of: &direction) { directionBytes in
                withUnsafeBytes(of: &spacing) { spacingBytes in
                    let settings = [
                        CTParagraphStyleSetting(spec: .alignment, valueSize: MemoryLayout<CTTextAlignment>.size, value: alignmentBytes.baseAddress!),
                        CTParagraphStyleSetting(spec: .baseWritingDirection, valueSize: MemoryLayout<CTWritingDirection>.size, value: directionBytes.baseAddress!),
                        CTParagraphStyleSetting(spec: .lineSpacingAdjustment, valueSize: MemoryLayout<CGFloat>.size, value: spacingBytes.baseAddress!),
                    ]
                    return CTParagraphStyleCreate(settings, settings.count)
                }
            }
        }

        var attributes: [CFString: Any] = [
            kCTFontAttributeName: Self.font(size: size, weight: weight, language: language),
            kCTForegroundColorAttributeName: color,
            kCTParagraphStyleAttributeName: paragraph,
            // Asked for by language, not by script: it is what makes CoreText choose Simplified
            // rather than Traditional forms for the Han characters the two share, and Hiragino
            // rather than PingFang for Japanese.
            kCTLanguageAttributeName: language,
        ]
        if tracking != 0 { attributes[kCTKernAttributeName] = tracking }

        return CFAttributedStringCreate(nil, text as CFString, attributes as CFDictionary)!
    }

    /// The system UI font for a language, which is the only way to get the right face for
    /// Chinese, Japanese and Korean without naming a font that may not be installed.
    private static func font(size: CGFloat, weight: CGFloat, language: String) -> CTFont {
        let base = CTFontCreateUIFontForLanguage(.system, size, language as CFString)
            ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
        guard weight > 0.4 else { return base }

        // Asked for as a weight trait rather than by name, because "the semibold of the font that
        // draws Korean" has no name worth hardcoding. If the family has no such face, CoreText
        // hands back the one it started with, which is the right failure: slightly light, not
        // missing.
        let descriptor = CTFontDescriptorCreateCopyWithAttributes(
            CTFontCopyFontDescriptor(base),
            [kCTFontTraitsAttribute: [kCTFontWeightTrait: weight]] as CFDictionary
        )
        return CTFontCreateCopyWithAttributes(base, size, nil, descriptor)
    }
}

// MARK: - Drawing one screenshot

struct Frame {
    let raw: CGImage
    let caption: String
    let subcaption: String
    let locale: CaptureLocale

    func render() throws -> CGImage {
        // The canvas is the size of the screenshot. Both sizes the simulator produces for a
        // 6.9-inch iPhone are sizes App Store Connect accepts, so nothing is resampled twice.
        let size = CGSize(width: raw.width, height: raw.height)
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            // No alpha: App Store Connect rejects a screenshot with an alpha channel, and a PNG
            // written from a premultiplied context keeps one even when nothing is transparent.
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            throw Failure("could not open a \(Int(size.width))×\(Int(size.height)) canvas")
        }

        drawBackground(in: context, size: size)
        try drawCaptions(in: context, size: size)
        drawPhone(in: context, size: size)

        guard let image = context.makeImage() else { throw Failure("nothing came out of the canvas") }
        return image
    }

    private func drawBackground(in context: CGContext, size: CGSize) {
        context.setFillColor(Palette.canvas)
        context.fill(CGRect(origin: .zero, size: size))

        // The same faint glow the app draws behind its own content, so the frame reads as part of
        // the app rather than as a marketing border around it.
        if let gradient = CGGradient(
            colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
            colors: [Palette.canvasTop, Palette.canvas] as CFArray,
            locations: [0, 1]
        ) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: size.height),
                end: CGPoint(x: 0, y: size.height * 0.45),
                options: []
            )
        }

        // A dawn arc behind the phone: two hundred pixels of amber bleeding out of the top of the
        // device, which is what makes twelve otherwise identical dark frames look composed.
        if let glow = CGGradient(
            colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
            colors: [
                Palette.rgb(0xFFA24B, alpha: 0.30),
                Palette.rgb(0xFF5E62, alpha: 0.12),
                Palette.rgb(0x0B0D14, alpha: 0),
            ] as CFArray,
            locations: [0, 0.45, 1]
        ) {
            let centre = CGPoint(x: size.width / 2, y: size.height * (1 - Layout.screenTop) + size.width * 0.08)
            context.drawRadialGradient(
                glow,
                startCenter: centre, startRadius: 0,
                endCenter: centre, endRadius: size.width * 0.72,
                options: []
            )
        }
    }

    private func drawCaptions(in context: CGContext, size: CGSize) throws {
        let width = size.width * Layout.captionWidth
        let x = (size.width - width) / 2

        // CoreText draws from the bottom left; the layout is written top-down because that is how
        // the page reads.
        let captionBox = CGRect(
            x: x,
            y: size.height * (1 - Layout.captionTop - Layout.captionHeight),
            width: width,
            height: size.height * Layout.captionHeight
        )
        let subBox = CGRect(
            x: x,
            y: captionBox.minY - size.height * (Layout.subcaptionGap + Layout.subcaptionHeight),
            width: width,
            height: size.height * Layout.subcaptionHeight
        )

        try Caption(
            text: caption,
            language: locale.language,
            isRightToLeft: locale.isRightToLeft,
            color: Palette.textPrimary,
            weight: 0.62,
            sizes: stride(from: size.width * 0.072, through: size.width * 0.040, by: -size.width * 0.002).map { $0 },
            maximumLines: 2
        ).draw(in: context, box: captionBox)

        try Caption(
            text: subcaption,
            language: locale.language,
            isRightToLeft: locale.isRightToLeft,
            color: Palette.textSecondary,
            weight: 0,
            sizes: stride(from: size.width * 0.034, through: size.width * 0.022, by: -size.width * 0.001).map { $0 },
            maximumLines: 2
        ).draw(in: context, box: subBox)
    }

    private func drawPhone(in context: CGContext, size: CGSize) {
        let screenWidth = (size.width * Layout.screenWidth).rounded()
        let screenHeight = (screenWidth * CGFloat(raw.height) / CGFloat(raw.width)).rounded()
        let originX = ((size.width - screenWidth) / 2).rounded()
        let originY = (size.height * (1 - Layout.screenTop) - screenHeight).rounded()
        let screen = CGRect(x: originX, y: originY, width: screenWidth, height: screenHeight)
        let radius = screenWidth * Layout.screenRadius
        let bezel = (size.width * Layout.bezel).rounded()

        // The body of the phone: a hairline-coloured shell just outside the screen. Drawn rather
        // than composited from a device image, because Apple's marketing frames may not be used
        // on a screenshot and third-party ones date the listing the moment a new phone ships.
        let body = screen.insetBy(dx: -bezel, dy: -bezel)
        context.setShadow(offset: CGSize(width: 0, height: -bezel * 2), blur: bezel * 6, color: Palette.rgb(0x000000, alpha: 0.55))
        context.setFillColor(Palette.hairline)
        context.addPath(CGPath(roundedRect: body, cornerWidth: radius + bezel, cornerHeight: radius + bezel, transform: nil))
        context.fillPath()
        context.setShadow(offset: .zero, blur: 0, color: nil)

        context.saveGState()
        context.addPath(CGPath(roundedRect: screen, cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.clip()
        context.draw(raw, in: screen)
        context.restoreGState()

        // A one-pixel highlight along the top edge of the shell. It is what separates the dark
        // phone from the dark background at thumbnail size.
        context.setStrokeColor(Palette.rgb(0xFFFFFF, alpha: 0.10))
        context.setLineWidth(max(1, bezel / 4))
        context.addPath(CGPath(roundedRect: body, cornerWidth: radius + bezel, cornerHeight: radius + bezel, transform: nil))
        context.strokePath()
    }
}

// MARK: - Files

struct Failure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

func read(_ url: URL) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw Failure("\(url.lastPathComponent) is not a readable image")
    }
    return image
}

func write(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw Failure("cannot write \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw Failure("PNG did not finalise: \(url.path)") }
}

// MARK: - Entry point

func value(for flag: String, in arguments: [String]) -> String? {
    guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
    return arguments[index + 1]
}

func run() throws {
    let arguments = Array(CommandLine.arguments.dropFirst())

    // `locales` exists so `shots.sh` iterates the same twelve languages this tool frames, instead
    // of keeping a list of its own in shell.
    if arguments.first == "locales" {
        for locale in CaptureLocale.all {
            print([locale.store, locale.language, locale.appleLocale].joined(separator: "\t"))
        }
        return
    }

    guard let rawPath = value(for: "--raw", in: arguments),
          let outPath = value(for: "--out", in: arguments),
          let appPath = value(for: "--app", in: arguments) else {
        throw Failure("usage: frame-shots --raw <dir> --out <dir> --app <path to .app> [--only <store,…>]")
    }

    let raw = URL(filePath: rawPath, directoryHint: .isDirectory)
    let out = URL(filePath: outPath, directoryHint: .isDirectory)
    let app = URL(filePath: appPath, directoryHint: .isDirectory)
    let wanted = value(for: "--only", in: arguments).map { Set($0.split(separator: ",").map(String.init)) }

    var framed = 0
    for locale in CaptureLocale.all where wanted?.contains(locale.store) ?? true {
        let source = raw.appending(path: locale.store, directoryHint: .isDirectory)
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw Failure("no screenshots for \(locale.store) — run scripts/shots.sh")
        }
        let table = try strings(inApp: app, language: locale.language)
        let destination = out.appending(path: locale.store, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        for screen in CaptureLaunch.Screen.allCases {
            let file = "\(screen.fileStem).png"
            let input = source.appending(path: file)
            guard FileManager.default.fileExists(atPath: input.path) else { continue }
            guard let caption = table[screen.captionKey], let subcaption = table[screen.subcaptionKey] else {
                throw Failure("\(locale.language) has no \(screen.captionKey) — run scripts/make_strings.py")
            }

            let image = try Frame(
                raw: try read(input),
                caption: caption,
                subcaption: subcaption,
                locale: locale
            ).render()
            try write(image, to: destination.appending(path: file))
            framed += 1
        }
        print("\(locale.store): framed")
    }

    guard framed > 0 else { throw Failure("nothing was framed") }
    print("\(framed) screenshots in \(out.path)")
}

/// `@main` rather than top-level code, because this file is compiled together with the two
/// contract files and Swift only allows statements at the top level of a lone `main.swift`.
@main
struct FrameShots {
    static func main() {
        do {
            try run()
        } catch {
            FileHandle.standardError.write(Data("frame-shots: \(error)\n".utf8))
            exit(1)
        }
    }
}
