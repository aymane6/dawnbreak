import UIKit

/// The three physical sensations the missions speak in.
///
/// Centralised because they are grammar, not decoration: a light tick on every accepted
/// input, success when a round clears, a hard buzz on a mistake. At 06:00 with eyes half
/// shut, the hand learns the pattern faster than the eyes do — and a mission that answers
/// touch with silence feels broken even when the screen responded.
@MainActor
enum Haptics {
    /// Mirrors `Preferences.hapticsEnabled`, seeded at launch and updated by the settings
    /// toggle. A static mirror rather than a lookup, because the callers are leaf views —
    /// a keypad key, a sequence pad — and threading the environment into every one of them
    /// would be plumbing in service of a boolean.
    static var isEnabled = true

    private static let impact = UIImpactFeedbackGenerator(style: .light)
    private static let notice = UINotificationFeedbackGenerator()

    static func tap() {
        guard isEnabled else { return }
        impact.impactOccurred()
    }

    static func success() {
        guard isEnabled else { return }
        notice.notificationOccurred(.success)
    }

    static func error() {
        guard isEnabled else { return }
        notice.notificationOccurred(.error)
    }
}
