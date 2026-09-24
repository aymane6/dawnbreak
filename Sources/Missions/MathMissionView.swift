import DawnbreakKit
import SwiftUI

/// Solve one arithmetic problem.
///
/// The keypad is drawn rather than using the system keyboard: the system numeric keyboard on
/// a locked-then-unlocked phone can arrive late and half the screen tall, and a 6am mission
/// that starts with a keyboard animation is a mission that starts with a mistake.
struct MathMissionView: View {
    let config: MissionConfig
    let callbacks: MissionCallbacks

    @Environment(\.locale) private var locale

    @State private var challenge: MathChallenge
    @State private var typed = ""
    @State private var wrong = false

    init(config: MissionConfig, callbacks: MissionCallbacks) {
        self.config = config
        self.callbacks = callbacks
        _challenge = State(initialValue: MathChallenge.make(config.math))
    }

    var body: some View {
        MissionScaffold(instructionKey: MissionKind.math.instructionKey) {
            VStack(spacing: 18) {
                // Left to right even in Arabic, like the keypad under it and every calculator on
                // the platform. The layout direction alone does not do it: `displayPrompt` says why
                // the string itself has to carry the direction.
                Text(verbatim: challenge.displayPrompt(in: locale))
                    .font(Theme.clock(46))
                    .foregroundStyle(Theme.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.horizontal, 20)
                    .environment(\.layoutDirection, .leftToRight)
                    .accessibilityLabel(Text(verbatim: challenge.prompt(in: locale)))

                answer
                    .frame(minWidth: 140, minHeight: 72)
                    .background(Theme.surface, in: .rect(cornerRadius: Theme.Metric.controlRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Metric.controlRadius)
                            .stroke(wrong ? Theme.danger : Theme.hairline, lineWidth: 1.5)
                    )
                    .animation(.easeOut(duration: 0.15), value: wrong)
                    .accessibilityLabel(Text("mission.math.answer", bundle: .main))
                    .accessibilityValue(Text(verbatim: typed.localizedDigits(in: locale)))
            }
        } control: {
            Keypad(
                allowsNegative: config.math.allowNegative,
                onDigit: append,
                onDelete: deleteLast,
                onSubmit: submit
            )
        }
    }

    /// A caret until the first key, then the digits, isolated left to right so an Arabic minus
    /// stays in front of the number the way the keypad typed it. Not a dash for "nothing yet": on
    /// the difficulties that allow a negative answer, a dash in the answer box reads as a minus
    /// that was never typed.
    @ViewBuilder private var answer: some View {
        if typed.isEmpty {
            Capsule()
                .fill(wrong ? Theme.danger : Theme.textTertiary)
                .frame(width: 3, height: 44)
        } else {
            Text(verbatim: "\u{2066}" + typed.localizedDigits(in: locale) + "\u{2069}")
                .font(Theme.clock(56))
                .foregroundStyle(wrong ? Theme.danger : Theme.accent)
        }
    }

    private func append(_ character: String) {
        guard typed.count < 8 else { return }
        wrong = false
        if character == "-" {
            // A leading minus only, and toggling it rather than appending, because "5-" is
            // not something a sleepy thumb should be able to produce.
            if typed.hasPrefix("-") {
                typed.removeFirst()
            } else {
                typed = "-" + typed
            }
            return
        }
        typed += character
    }

    private func deleteLast() {
        wrong = false
        guard !typed.isEmpty else { return }
        typed.removeLast()
    }

    private func submit() {
        guard !typed.isEmpty else { return }
        if challenge.accepts(typed) {
            callbacks.cleared()
        } else {
            wrong = true
            typed = ""
            // A wrong answer gets a new problem: retrying the same one invites brute force.
            challenge = MathChallenge.make(config.math)
            callbacks.mistake()
        }
    }
}

/// The number pad. Its own view because the typing mission's Enter key and this one's are
/// the same 44pt-minimum control, and because a keypad drawn twice drifts.
struct Keypad: View {
    var allowsNegative: Bool = false
    let onDigit: (String) -> Void
    let onDelete: () -> Void
    let onSubmit: () -> Void

    @Environment(\.locale) private var locale

    private let rows: [[String]] = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"]]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { digit in
                        key(digit) { onDigit(digit) }
                    }
                }
            }
            HStack(spacing: 8) {
                if allowsNegative {
                    key("−", accessibilityKey: "keypad.negative") { onDigit("-") }
                } else {
                    deleteKey
                }
                key("0") { onDigit("0") }
                if allowsNegative {
                    deleteKey
                } else {
                    Button(action: onSubmit) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 22, weight: .bold))
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .foregroundStyle(Theme.onAccent)
                            .background(Theme.dawnGradient)
                            .clipShape(.rect(cornerRadius: 14))
                    }
                    .accessibilityLabel(Text("keypad.submit", bundle: .main))
                }
            }
            if allowsNegative {
                Button(action: onSubmit) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(Theme.onAccent)
                        .background(Theme.dawnGradient)
                        .clipShape(.rect(cornerRadius: 14))
                }
                .accessibilityLabel(Text("keypad.submit", bundle: .main))
            }
        }
        // Not mirrored in Arabic. A number pad is a physical layout, one to nine from the top
        // left, on the passcode screen and in the Phone app alike; mirrored, it also put the
        // delete key where a right-handed thumb confirms.
        .environment(\.layoutDirection, .leftToRight)
    }

    private var deleteKey: some View {
        Button {
            Haptics.tap()
            onDelete()
        } label: {
            Image(systemName: "delete.backward")
                .font(.system(size: 22, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 58)
                .foregroundStyle(Theme.textSecondary)
                .background(Theme.surfaceRaised, in: .rect(cornerRadius: 14))
        }
        .accessibilityLabel(Text("keypad.delete", bundle: .main))
    }

    private func key(
        _ label: String,
        accessibilityKey: String? = nil,
        tint: Color = Theme.textPrimary,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            // Every accepted keypress ticks. A keypad that answers only on screen is one a
            // half-asleep thumb double-presses, and "77" is a wrong answer twice over.
            Haptics.tap()
            action()
        } label: {
            Text(displayText(for: label))
                .font(.system(size: 25, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 58)
                .foregroundStyle(tint)
                .background(Theme.surfaceRaised, in: .rect(cornerRadius: 14))
        }
        .accessibilityLabel(accessibilityKey.map { Text(key: $0) } ?? Text(verbatim: label))
    }

    /// Digits are shown in the locale's numbering system so an Arabic interface has a keypad
    /// that matches the problem above it, which is written with the same locale.
    ///
    /// The label handed back to `onDigit` stays ASCII: it is what gets compared to the answer.
    private func displayText(for label: String) -> String {
        guard let value = Int(label) else { return label }
        return value.formatted(IntegerFormatStyle<Int>(locale: locale).grouping(.never))
    }
}
