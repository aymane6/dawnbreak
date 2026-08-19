import DawnbreakKit
import SwiftUI

/// Shake the phone N times.
struct ShakeMissionView: View {
    let config: MissionConfig
    let callbacks: MissionCallbacks

    @State private var monitor = ShakeMonitor()
    @State private var cleared = false

    var body: some View {
        Group {
            if monitor.isAvailable {
                MissionScaffold(instructionKey: MissionKind.shake.instructionKey) {
                    ZStack {
                        ProgressRing(fraction: fraction)
                            .frame(width: 230, height: 230)
                        VStack(spacing: 10) {
                            Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                                .font(.system(size: 30))
                                .foregroundStyle(Theme.accent)
                                .rotationEffect(.degrees(monitor.intensity * 10 - 5))
                                .animation(.spring(duration: 0.15), value: monitor.intensity)
                            CountReadout(count: min(monitor.count, target), target: target, unitKey: "mission.shake.unit")
                        }
                    }
                }
            } else {
                MissionUnavailableView(
                    titleKey: "mission.shake.unavailable.title",
                    bodyKey: "mission.shake.unavailable.body",
                    onOverride: { callbacks.cleared() }
                )
            }
        }
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
        .onChange(of: monitor.count) { _, count in
            guard !cleared, count >= target else { return }
            cleared = true
            callbacks.cleared()
        }
    }

    private var target: Int { config.shakeCount }
    private var fraction: Double { Double(monitor.count) / Double(max(1, target)) }
}

/// Walk N steps.
struct StepsMissionView: View {
    let config: MissionConfig
    let callbacks: MissionCallbacks

    @State private var monitor = StepMonitor()
    @State private var cleared = false

    var body: some View {
        Group {
            if monitor.isAvailable && !monitor.isDenied {
                MissionScaffold(instructionKey: MissionKind.steps.instructionKey) {
                    ZStack {
                        ProgressRing(fraction: fraction)
                            .frame(width: 230, height: 230)
                        VStack(spacing: 10) {
                            Image(systemName: "figure.walk")
                                .font(.system(size: 30))
                                .foregroundStyle(Theme.accent)
                                .symbolEffect(.pulse, options: .repeating)
                            CountReadout(count: min(monitor.steps, target), target: target, unitKey: "mission.steps.unit")
                        }
                    }
                } control: {
                    Text("mission.steps.hint", bundle: .main)
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .multilineTextAlignment(.center)
                }
            } else {
                MissionUnavailableView(
                    titleKey: monitor.isDenied ? "mission.steps.denied.title" : "mission.steps.unavailable.title",
                    bodyKey: monitor.isDenied ? "mission.steps.denied.body" : "mission.steps.unavailable.body",
                    onOverride: { callbacks.cleared() }
                )
            }
        }
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
        .onChange(of: monitor.steps) { _, steps in
            guard !cleared, steps >= target else { return }
            cleared = true
            callbacks.cleared()
        }
    }

    private var target: Int { config.stepTarget }
    private var fraction: Double { Double(monitor.steps) / Double(max(1, target)) }
}

/// Guided breathing. The one mission that is not a test.
///
/// It exists because "wake up gently" is a real want, and because an alarm that cannot be
/// cleared by anyone who is genuinely unwell is a bad alarm. It still takes 40 seconds of
/// held attention, which is enough to be awake at the end of it.
struct BreatheMissionView: View {
    let config: MissionConfig
    let callbacks: MissionCallbacks

    @State private var cyclesDone = 0
    @State private var stage: Stage = .inhale
    @State private var scale: CGFloat = 0.55

    private enum Stage {
        case inhale, hold, exhale

        var labelKey: String {
            switch self {
            case .inhale: "mission.breathe.inhale"
            case .hold: "mission.breathe.hold"
            case .exhale: "mission.breathe.exhale"
            }
        }
    }

    var body: some View {
        MissionScaffold(
            instructionKey: MissionKind.breathe.instructionKey,
            instruction: localized(stage.labelKey)
        ) {
            VStack(spacing: 26) {
                ZStack {
                    Circle()
                        .fill(Theme.dawnGradient)
                        .opacity(0.22)
                        .scaleEffect(scale)
                    Circle()
                        .stroke(Theme.accent.opacity(0.6), lineWidth: 2)
                        .scaleEffect(scale)
                    Text(key: stage.labelKey)
                        .font(Theme.headlineFont)
                        .foregroundStyle(Theme.textPrimary)
                }
                .frame(width: 250, height: 250)

                Text(localized("mission.breathe.cycle", cyclesDone + 1, config.breathe.cycles))
                    .font(Theme.captionFont.monospacedDigit())
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .task { await run() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(key: stage.labelKey))
    }

    private func run() async {
        let pattern = config.breathe
        while cyclesDone < pattern.cycles {
            await animate(to: 1.0, over: pattern.inhale, stage: .inhale)
            await animate(to: 1.0, over: pattern.hold, stage: .hold)
            await animate(to: 0.55, over: pattern.exhale, stage: .exhale)
            guard !Task.isCancelled else { return }
            cyclesDone += 1
        }
        callbacks.cleared()
    }

    private func animate(to target: CGFloat, over seconds: Double, stage: Stage) async {
        self.stage = stage
        withAnimation(.easeInOut(duration: seconds)) { scale = target }
        try? await Task.sleep(for: .seconds(seconds))
    }
}
