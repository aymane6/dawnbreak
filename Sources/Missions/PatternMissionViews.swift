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
        VStack(spacing: 10) {
            ForEach(0..<challenge.side, id: \.self) { row in
                HStack(spacing: 10) {
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
            RoundedRectangle(cornerRadius: 14)
                .fill(fill(isLit: isLit, isChosen: isChosen, isMistake: isMistake))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    // A picked tile carries a mark as well as a colour: at 06:00 "which
                    // ones have I already tapped" must survive a glance, not a comparison
                    // of two orange tints.
                    if isChosen {
                        Image(systemName: "checkmark")
                            .font(.system(size: 17, weight: .heavy))
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isLit ? .white.opacity(0.85) : Theme.hairline, lineWidth: isLit ? 2.5 : 1)
                )
                .shadow(color: Theme.dawnStart.opacity(isLit ? 0.6 : 0), radius: isLit ? 16 : 0)
                .scaleEffect(isLit || isChosen ? 1.04 : 1)
        }
        .buttonStyle(.plain)
        .disabled(phase == .preview)
        .animation(.spring(duration: 0.22), value: isLit)
        .animation(.spring(duration: 0.22), value: isChosen)
        .accessibilityLabel(Text(localized("mission.memory.tile", index + 1)))
        .accessibilityAddTraits(isChosen ? [.isSelected] : [])
    }

    private func fill(isLit: Bool, isChosen: Bool, isMistake: Bool) -> AnyShapeStyle {
        if isMistake { return AnyShapeStyle(Theme.danger) }
        if isLit { return AnyShapeStyle(Theme.dawnGradient) }
        if isChosen { return AnyShapeStyle(Theme.accent) }
        // Brighter than the standard raised surface: sixteen dark tiles on a dark canvas
        // was a grid that had to be hunted for.
        return AnyShapeStyle(Color(hex: 0x272C42))
    }

    private func tap(_ index: Int) {
        guard phase == .recall, !selection.contains(index) else { return }

        if challenge.isMistake(tile: index) {
            mistaken = index
            callbacks.mistake()
            return
        }
        Haptics.tap()
        selection.insert(index)
        if challenge.isComplete(selection: selection) {
            callbacks.cleared()
        }
    }
}

/// Repeat a growing sequence of coloured pads.
///
/// Rebuilt after the first beta round, whose verdict was "c'était pas fou". The failures
/// were legibility ones: pads at a third of their colour read as four grey squares to
/// half-open eyes, a flash that only changed opacity was easy to miss, and a tap that
/// changed nothing on screen felt ignored. Every state now has a loud answer — resting pads
/// are richly coloured, the playback flash lifts, glows and ticks, the user's own taps
/// flash back the same way, and whose turn it is is written above the grid.
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
            VStack(spacing: 18) {
                HStack(spacing: 10) {
                    Text(localized("mission.sequence.step", round, challenge.steps.count))
                        .font(.system(size: 17, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Theme.accent)
                        .contentTransition(.numericText())
                    // Progress the eye can track without reading: one dot per step of the
                    // sequence already survived.
                    HStack(spacing: 5) {
                        ForEach(1...challenge.steps.count, id: \.self) { step in
                            Circle()
                                .fill(step < round ? Theme.accent : Theme.surfaceRaised)
                                .frame(width: 7, height: 7)
                        }
                    }
                }
                .animation(.easeOut(duration: 0.2), value: round)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 2), spacing: 14) {
                    ForEach(0..<SequenceChallenge.padCount, id: \.self) { pad in
                        padButton(pad)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .task { await playback() }
    }

    private func padButton(_ pad: Int) -> some View {
        let isOn = highlighted == pad
        let color = Self.padColors[pad]
        return Button { tap(pad) } label: {
            RoundedRectangle(cornerRadius: 22)
                .fill(color.opacity(isOn ? 1 : 0.62))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    Image(systemName: Self.padSymbols[pad])
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white.opacity(isOn ? 1 : 0.9))
                        .scaleEffect(isOn ? 1.15 : 1)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(.white.opacity(isOn ? 0.9 : 0.12), lineWidth: isOn ? 3 : 1)
                )
                .shadow(color: color.opacity(isOn ? 0.8 : 0), radius: isOn ? 22 : 0)
                .scaleEffect(isOn ? 1.06 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isPlayingBack)
        .animation(.spring(duration: 0.22), value: isOn)
        .accessibilityLabel(Text(localized("mission.sequence.pad", pad + 1)))
    }

    private func playback() async {
        isPlayingBack = true
        tapped = []
        // The cadence comes from the kit so that it is the same number a test can reason about. A
        // mission whose playback outlasts its own time limit can never be cleared, and that is
        // exactly what happened here: brutal is eleven pads, which is forty-six seconds of watching
        // against a thirty-second limit, so the round reset forever and the alarm could only be
        // escaped through the emergency exit.
        try? await Task.sleep(for: .seconds(MissionConfig.sequenceLeadIn))
        for pad in challenge.prefix(round: round) {
            highlighted = pad
            Haptics.tap()
            try? await Task.sleep(for: .seconds(MissionConfig.sequencePadSeconds * Self.litShare))
            highlighted = nil
            try? await Task.sleep(for: .seconds(MissionConfig.sequencePadSeconds * (1 - Self.litShare)))
        }
        isPlayingBack = false
    }

    /// How much of one pad's time it spends lit. The rest is the gap that makes two identical pads
    /// in a row readable as two.
    private static let litShare = 0.71

    private func tap(_ pad: Int) {
        tapped.append(pad)
        guard challenge.isValidSoFar(tapped, round: round) else {
            callbacks.mistake()
            return
        }
        // The user's own tap answers back exactly like the playback did: same flash, same
        // glow, same tick. A pad that stays inert under a correct press reads as a miss.
        Haptics.tap()
        flash(pad)
        guard challenge.isRoundComplete(tapped, round: round) else { return }

        if round >= challenge.steps.count {
            callbacks.cleared()
        } else {
            round += 1
            Task { await playback() }
        }
    }

    private func flash(_ pad: Int) {
        highlighted = pad
        Task {
            try? await Task.sleep(for: .milliseconds(180))
            if highlighted == pad && !isPlayingBack { highlighted = nil }
        }
    }
}
