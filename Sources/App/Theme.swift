import SwiftUI

/// The design tokens, in one place.
///
/// Dark is the primary scheme because the app's whole job happens in a dark bedroom at
/// 06:00, and a white screen at that hour is hostile. The palette follows a 60/30/10 split:
/// `canvas` for the 60, `surface` and `surfaceRaised` for the 30, and the dawn gradient for
/// the 10 that draws the eye to the one button that matters.
enum Theme {

    // MARK: - Colour

    /// Near-black with a blue cast rather than pure black: on an OLED panel pure black next
    /// to a warm accent reads as a hole, and the cast keeps the elevation legible.
    static let canvas = Color(hex: 0x0B0D14)
    static let surface = Color(hex: 0x151824)
    static let surfaceRaised = Color(hex: 0x1F2333)
    static let hairline = Color(hex: 0x2C3145)

    /// The dawn gradient: amber into coral, the two colours of a sunrise. Used for the
    /// primary action and nothing else, so it always means "this is the thing to press".
    static let dawnStart = Color(hex: 0xFFA24B)
    static let dawnEnd = Color(hex: 0xFF5E62)
    static let accent = Color(hex: 0xFF7F52)

    /// Twilight violet, used only by the stats screen so charts never compete with the
    /// primary action for attention.
    static let dusk = Color(hex: 0x8B6CFF)

    static let textPrimary = Color(hex: 0xF6F4F1)
    static let textSecondary = Color(hex: 0x9BA0B5)
    static let textTertiary = Color(hex: 0x666C82)

    static let success = Color(hex: 0x4BD69C)
    static let warning = Color(hex: 0xFFC24B)
    static let danger = Color(hex: 0xFF5B6E)

    static var dawnGradient: LinearGradient {
        LinearGradient(colors: [dawnStart, dawnEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// The backdrop behind the alarm list: a faint dawn glow at the top of the screen, as
    /// if the sun were about to come up behind the content.
    static var canvasGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0x1A1526), canvas, canvas],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Metrics

    enum Metric {
        static let cornerRadius: CGFloat = 20
        static let cardRadius: CGFloat = 24
        static let controlRadius: CGFloat = 16
        static let cardPadding: CGFloat = 18
        static let gutter: CGFloat = 20
        /// 44pt is the documented minimum touch target and the floor for every control
        /// here. At 06:00 with one eye open, a 32pt tap target is a missed tap.
        static let minimumTarget: CGFloat = 44
    }

    // MARK: - Type

    /// The clock face. `.rounded` because a monospaced-digit rounded face is what reads
    /// fastest at a glance, and monospaced so the digits do not jitter as the minute ticks.
    static func clock(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded).monospacedDigit()
    }

    static let titleFont = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let headlineFont = Font.system(.headline, design: .rounded, weight: .semibold)
    static let bodyFont = Font.system(.body, design: .rounded)
    static let captionFont = Font.system(.caption, design: .rounded, weight: .medium)
}

extension Color {
    /// 0xRRGGBB. Written by hand rather than pulled from the asset catalog for the tokens
    /// that never change between light and dark, which is all of them here.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - Shared building blocks

/// A raised card. Every list row and settings group uses this so elevation is consistent.
struct Card<Content: View>: View {
    var padding: CGFloat = Theme.Metric.cardPadding
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(Theme.surface, in: .rect(cornerRadius: Theme.Metric.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Metric.cardRadius)
                    .stroke(Theme.hairline, lineWidth: 1)
            )
    }
}

/// The one prominent button in the app. Uses the dawn gradient, full width, and a large
/// touch target, because at 06:00 the primary action has to be unmissable.
struct DawnButtonStyle: ButtonStyle {
    var isEnabled = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.headlineFont)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background {
                if isEnabled {
                    Theme.dawnGradient
                } else {
                    Theme.surfaceRaised
                }
            }
            .clipShape(.rect(cornerRadius: Theme.Metric.controlRadius))
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// The secondary, quiet button: snooze, cancel, "not now".
struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.bodyFont.weight(.medium))
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: Theme.Metric.minimumTarget)
            .background(Theme.surfaceRaised, in: .rect(cornerRadius: Theme.Metric.controlRadius))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension View {
    /// Applies the app's canvas behind a screen, ignoring the safe area so the gradient
    /// runs under the status bar.
    func dawnCanvas() -> some View {
        background(Theme.canvasGradient.ignoresSafeArea())
    }
}
