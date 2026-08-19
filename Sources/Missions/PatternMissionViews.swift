import DawnbreakKit
import SwiftUI

/// Watch a set of tiles light up, then tap exactly those tiles.
struct MemoryMissionView: View {
    let config: MissionConfig
    let callbacks: MissionCallbacks

    @State private var challenge: PatternChallenge
    @State private var selection: Set<Int> = []
    @State private var phase: Phase = .preview
    @State private var mistaken: Int?

    private enum Phase { case preview, recall }

    init(config: MissionConfig, callbacks: MissionCallbacks) {
        self.config = config
        self.callbacks = callbacks
        let parameters = config.memory
        _challenge = State(initialValue: PatternChallenge.make(
            side: parameters.side,
            litTiles: parameters.litTiles,
            previewSeconds: parameters.previewSeconds
        ))
    }

    var body: some View {
        MissionScaffold(
            instructionKey: MissionKind.memory.instructionKey,
            instruction: phase == .preview ? localized("mission.memory.watch") : nil
        ) {
            VStack(spacing: 14) {
                grid
                if phase == .recall {
                    Text(localized("mission.memory.remaining", max(0, challenge.lit.count - selection.count)))
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textTertiary)
                        .contentTransition(.numericText())
                }
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(challenge.previewSeconds))
            withAnimation(.easeOut(duration: 0.25)) { phase = .recall }
        }
    }

    private var grid: some View {
        VStack(spacing: 8) {
            ForEach(0..<challenge.side, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(0..<challenge.side, id: \.self) { column in
                        let index = row * challenge.side + column
                        tile(index)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private func tile(_ index: Int) -> some View {
        let isLit = phase == .preview && challenge.lit.contains(index)
        let isChosen = selection.contains(index)
        let isMistake = mistaken == index

        return Button {
            tap(index)
        } label: {
            RoundedRectangle(cornerRadius: 12)
                .fill(fill(isLit: isLit, isChosen: isChosen, isMistake: isMistake))
                .aspectRatio(1, contentMode: .fit)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(phase == .preview)
        .animation(.easeOut(duration: 0.18), value: isLit)
        .accessibilityLabel(Text(localized("mission.memory.tile", index + 1)))
        .accessibilityAddTraits(isChosen ? [.isSelected] : [])
    }

    private func fill(isLit: Bool, isChosen: Bool, isMistake: Bool) -> AnyShapeStyle {
        if isMistake { return AnyShapeStyle(Theme.danger) }
        if isLit { return AnyShapeStyle(Theme.dawnGradient) }
        if isChosen { return AnyShapeStyle(Theme.accent.opacity(0.75)) }
        return AnyShapeStyle(Theme.surfaceRaised)
    }

    private func tap(_ index: Int) {
        guard phase == .recall, !selection.contains(index) else { return }

        if challenge.isMistake(tile: index) {
            mistaken = index
            callbacks.mistake()
            return
        }
        selection.insert(index)
        if challenge.isComplete(selection: selection) {
            callbacks.cleared()
        }
    }
}

/// Repeat a growing sequence of coloured pads.
struct SequenceMissionView: View {
    let config: MissionConfig
    let callbacks: MissionCallbacks

    @State private var challenge: SequenceChallenge
    @State private var round = 1
    @State private var tapped: [Int] = []
    @State private var highlighted: Int?
    @State private var isPlayingBack = true

    /// Deliberately not red/green: a colour-blind user has to be able to tell four pads
    /// apart, so the palette varies in lightness as well as hue and each pad also carries a
    /// distinct shape.
    private static let padColors: [Color] = [
        Color(hex: 0x4BA3FF), Color(hex: 0xFFC24B), Color(hex: 0x8B6CFF), Color(hex: 0x4BD69C)
    ]
    private static let padSymbols = ["circle.fill", "square.fill", "triangle.fill", "diamond.fill"]

    init(config: MissionConfig, callbacks: MissionCallbacks) {
        self.config = config
        self.callbacks = callbacks
        _challenge = State(initialValue: SequenceChallenge.make(length: config.sequenceLength))
    }

    var body: some View {
        MissionScaffold(
            instructionKey: MissionKind.sequence.instructionKey,
            instruction: isPlayingBack ? localized("mission.sequence.watch") : nil
        ) {
            VStack(spacing: 16) {
                Text(localized("mission.sequence.step", round, challenge.steps.count))
                    .font(Theme.captionFont.monospacedDigit())
                    .foregroundStyle(Theme.textTertiary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                    ForEach(0..<SequenceChallenge.padCount, id: \.self) { pad in
                        padButton(pad)
                    }
                }
                .padding(.horizontal, 32)
            }
        }
        .task { await playback() }
    }

    private func padButton(_ pad: Int) -> some View {
        let isOn = highlighted == pad
        return Button { tap(pad) } label: {
            RoundedRectangle(cornerRadius: 18)
                .fill(Self.padColors[pad].opacity(isOn ? 1 : 0.32))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    Image(systemName: Self.padSymbols[pad])
                        .font(.system(size: 26))
                        .foregroundStyle(.white.opacity(isOn ? 1 : 0.45))
                }
                .scaleEffect(isOn ? 1.04 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isPlayingBack)
        .animation(.easeOut(duration: 0.12), value: isOn)
        .accessibilityLabel(Text(localized("mission.sequence.pad", pad + 1)))
    }

    private func playback() async {
        isPlayingBack = true
        tapped = []
        // A beat before the first pad, so the user is looking at the grid rather than
        // missing the first flash while the screen is still animating in.
        try? await Task.sleep(for: .milliseconds(500))
        for pad in challenge.prefix(round: round) {
            highlighted = pad
            try? await Task.sleep(for: .milliseconds(420))
            highlighted = nil
            try? await Task.sleep(for: .milliseconds(160))
        }
        isPlayingBack = false
    }

    private func tap(_ pad: Int) {
        tapped.append(pad)
        guard challenge.isValidSoFar(tapped, round: round) else {
            callbacks.mistake()
            return
        }
        guard challenge.isRoundComplete(tapped, round: round) else { return }

        if round >= challenge.steps.count {
            callbacks.cleared()
        } else {
            round += 1
            Task { await playback() }
        }
    }
}
