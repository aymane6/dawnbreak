import DawnbreakKit
import SwiftUI

/// Retype a sentence.
///
/// The sentence comes out of the string catalog, so a Japanese user retypes Japanese. The
/// comparison is `TypingChallenge`'s, which forgives case, accents and the curly apostrophe
/// the keyboard substitutes, and forgives nothing else.
struct TypingMissionView: View {
    let config: MissionConfig
    let callbacks: MissionCallbacks

    @State private var challenge: TypingChallenge
    @State private var typed = ""
    @State private var isFocused = false
    @FocusState private var fieldFocus: Bool

    init(config: MissionConfig, callbacks: MissionCallbacks) {
        self.config = config
        self.callbacks = callbacks
        var made = TypingChallenge.make(wordCount: config.typingWordCount)
        // The model holds a key; resolving it here keeps the comparison logic in the kit and
        // the catalog lookup in the app, which is the only place that has a bundle.
        made.sentence = localized(made.sentenceKey)
        _challenge = State(initialValue: made)
    }

    var body: some View {
        MissionScaffold(instructionKey: MissionKind.typing.instructionKey) {
            VStack(spacing: 16) {
                Text(challenge.sentence)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 22)
                    // Selection is disabled so the sentence cannot be copied and pasted,
                    // which would defeat the entire mission.
                    .textSelection(.disabled)

                ProgressView(value: challenge.progress(of: typed))
                    .tint(Theme.accent)
                    .padding(.horizontal, 40)

                TextField(text: $typed, axis: .vertical) {
                    Text("mission.typing.placeholder", bundle: .main)
                }
                .font(.system(size: 18, design: .rounded))
                .foregroundStyle(hasError ? Theme.danger : Theme.textPrimary)
                .textInputAutocapitalization(.never)
                // Autocorrect is off: a corrected word that no longer matches the target is
                // an unclearable mission, and the user cannot see why.
                .autocorrectionDisabled()
                .focused($fieldFocus)
                .padding(14)
                .background(Theme.surface, in: .rect(cornerRadius: Theme.Metric.controlRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Metric.controlRadius)
                        .stroke(hasError ? Theme.danger : Theme.hairline, lineWidth: 1.5)
                )
                .padding(.horizontal, Theme.Metric.gutter)
                .onChange(of: typed) { _, new in
                    guard challenge.accepts(new) else { return }
                    fieldFocus = false
                    callbacks.cleared()
                }
            }
        } control: {
            Button {
                guard !typed.isEmpty else { return }
                if challenge.accepts(typed) {
                    callbacks.cleared()
                } else {
                    typed = ""
                    callbacks.mistake()
                }
            } label: {
                Text("mission.typing.check", bundle: .main)
            }
            .buttonStyle(DawnButtonStyle())
        }
        .task {
            // A short delay: focusing immediately races the full-screen cover's own
            // transition and the keyboard arrives half-drawn.
            try? await Task.sleep(for: .milliseconds(350))
            fieldFocus = true
        }
    }

    /// Only an actual divergence counts, not "shorter than the target".
    private var hasError: Bool {
        guard !typed.isEmpty, let index = challenge.firstMismatch(in: typed) else { return false }
        return index < typed.count
    }
}
