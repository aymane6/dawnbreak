import DawnbreakKit
import SwiftUI
import UIKit

/// The screen that stands between the user and a silent phone.
///
/// It owns the chrome, the round counter, the audio, the escape hatch and the timer; the
/// twelve mission views own nothing but their own challenge and a callback. That split is
/// what keeps "three rounds of maths" from being reimplemented twelve times.
struct MissionRunnerView: View {
    @Environment(\.app) private var app
    let pending: PendingMission

    @State private var roundsCleared = 0
    @State private var audio = AlarmAudio()
    @State private var showingExitConfirmation = false
    @State private var phase: Phase = .running
    /// Bumped to force a fresh challenge. Every mission view is `.id`-keyed on it, so a new
    /// round is a new view rather than a reset method each mission has to implement.
    @State private var roundToken = 0
    @State private var secondsLeft: Int?
    @State private var flashMistake = false

    private enum Phase { case running, succeeded }

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()

            switch phase {
            case .running:
                running
            case .succeeded:
                MissionSuccessView(pending: pending, roundsCleared: roundsCleared) {
                    Task { await finish() }
                }
            }
        }
        .preferredColorScheme(.dark)
        // The alarm is ringing; the screen must not dim and lock while the user is halfway
        // through counting squats.
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            audio.start(
                soundName: pending.soundName,
                volume: pending.volume,
                rampSeconds: 0,
                vibrate: pending.vibrate
            )
            startTimerIfNeeded()
            // The mission is being done, so the alarm waiting to come back is pushed out. It is
            // not cancelled: something has to be armed at every instant until the mission is
            // cleared, or killing the app here would be the way out.
            Task { await app.bridge.missionInProgress() }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            audio.stop()
            // This screen going away without the mission being settled is not allowed to be a
            // way out. `missionCompleted` and `missionAbandoned` both clear the pending mission
            // before the cover dismisses, so a mission still owed here means the screen was
            // taken away by something that did not settle it — and then the alarm comes straight
            // back rather than never.
            if app.bridge.activeMission?.alarmID == pending.alarmID {
                Task { await app.bridge.missionLeftUnfinished() }
            }
        }
        // No interactive dismissal, no swipe: this is the one screen in the app that is
        // deliberately hard to leave. The escape hatch in the corner is the way out.
        .interactiveDismissDisabled()
    }

    // MARK: - Running

    private var running: some View {
        VStack(spacing: 0) {
            header

            ZStack {
                missionBody
                    .id(roundToken)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if flashMistake {
                    Theme.danger.opacity(0.18)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }

            footer
        }
        .animation(.easeOut(duration: 0.2), value: flashMistake)
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "alarm.waves.left.and.right.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .symbolEffect(.variableColor.iterative, options: .repeating)

                VStack(alignment: .leading, spacing: 1) {
                    // The anchor for "the mission screen is up" sits on this leaf rather than on
                    // the header container, because an accessibility modifier on a container is
                    // applied to everything inside it: identifying the whole header stamped
                    // `ax.mission.header` over the exit button's own identifier, and the test that
                    // checks the escape hatch exists could no longer find it.
                    Text(pending.label.isEmpty ? localized("app.name") : pending.label)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .accessibilityIdentifier(AccessibilityID.missionHeader)
                    Text(ClockFormatter(uses24Hour: app.preferences.usesTwentyFourHourClock)
                        .full(hour: hourNow, minute: minuteNow))
                        .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer(minLength: 8)

                if let secondsLeft {
                    CountdownPill(seconds: secondsLeft)
                }

                if app.preferences.emergencyExitEnabled {
                    Button { showingExitConfirmation = true } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.textTertiary)
                            .frame(width: Theme.Metric.minimumTarget, height: Theme.Metric.minimumTarget)
                    }
                    .accessibilityLabel(Text("mission.exit", bundle: .main))
                    .accessibilityIdentifier(AccessibilityID.missionExit)
                    .confirmationDialog(
                        Text("mission.exit.title", bundle: .main),
                        isPresented: $showingExitConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button(role: .destructive) {
                            Task { await abandon() }
                        } label: {
                            Text("mission.exit.confirm", bundle: .main)
                        }
                        Button(role: .cancel) {} label: { Text("mission.exit.keepGoing", bundle: .main) }
                    } message: {
                        Text("mission.exit.body", bundle: .main)
                    }
                }
            }

            RoundProgress(cleared: roundsCleared, total: pending.mission.rounds)
        }
        .padding(.horizontal, Theme.Metric.gutter)
        .padding(.top, 8)
        .padding(.bottom, 14)
        .background(Theme.surface.opacity(0.6))
    }

    @ViewBuilder private var missionBody: some View {
        let callbacks = MissionCallbacks(
            cleared: { clearRound() },
            mistake: { registerMistake() }
        )

        switch pending.mission.kind {
        case .math: MathMissionView(config: pending.mission, callbacks: callbacks)
        case .memory: MemoryMissionView(config: pending.mission, callbacks: callbacks)
        case .sequence: SequenceMissionView(config: pending.mission, callbacks: callbacks)
        case .typing: TypingMissionView(config: pending.mission, callbacks: callbacks)
        case .shake: ShakeMissionView(config: pending.mission, callbacks: callbacks)
        case .steps: StepsMissionView(config: pending.mission, callbacks: callbacks)
        case .squats: SquatsMissionView(config: pending.mission, callbacks: callbacks)
        case .photo: PhotoMissionView(config: pending.mission, callbacks: callbacks)
        case .barcode: BarcodeMissionView(config: pending.mission, callbacks: callbacks)
        case .draw: DrawMissionView(config: pending.mission, callbacks: callbacks)
        case .flap: FlapMissionView(config: pending.mission, callbacks: callbacks)
        case .breathe: BreatheMissionView(config: pending.mission, callbacks: callbacks)
        }
    }

    @ViewBuilder private var footer: some View {
        if pending.canSnooze {
            VStack(spacing: 6) {
                Button {
                    Task { await snooze() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "zzz")
                        Text(localized("mission.snooze", pending.snooze.minutes))
                    }
                }
                .buttonStyle(QuietButtonStyle())

                if let left = pending.snoozesLeft {
                    Text(localized("mission.snoozesLeft", left))
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .padding(.horizontal, Theme.Metric.gutter)
            .padding(.bottom, 14)
        }
    }

    // MARK: - Round flow

    private func clearRound() {
        audio.acknowledge()
        roundsCleared += 1
        if roundsCleared >= pending.mission.rounds {
            audio.stop()
            withAnimation(.spring(duration: 0.4)) { phase = .succeeded }
        } else {
            roundToken += 1
            startTimerIfNeeded()
            // Progress buys time. A three-round mission is not a dodge, and the alarm coming
            // back between rounds would be the app fighting the person doing what it asked.
            Task { await app.bridge.missionInProgress() }
        }
    }

    /// A wrong answer flashes the screen and restarts the round. It does not end the mission:
    /// punishing a sleepy mistake by making the alarm unclearable would be cruel and would
    /// also be the kind of thing that gets an app one-starred.
    private func registerMistake() {
        flashMistake = true
        Task {
            try? await Task.sleep(for: .milliseconds(320))
            flashMistake = false
        }
        roundToken += 1
        startTimerIfNeeded()
    }

    private func startTimerIfNeeded() {
        guard let limit = pending.mission.timeLimit else {
            secondsLeft = nil
            return
        }
        secondsLeft = Int(limit)
        let token = roundToken
        Task {
            while let current = secondsLeft, current > 0, token == roundToken, phase == .running {
                try? await Task.sleep(for: .seconds(1))
                guard token == roundToken else { return }
                secondsLeft = current - 1
            }
            // Running out restarts the round rather than failing the mission.
            if token == roundToken, phase == .running, secondsLeft == 0 {
                registerMistake()
            }
        }
    }

    // MARK: - Outcomes

    private func finish() async {
        await app.bridge.missionCompleted(pending)
    }

    private func abandon() async {
        audio.stop()
        await app.bridge.missionAbandoned(pending)
    }

    private func snooze() async {
        audio.stop()
        await app.bridge.handleSnoozePressed(alarmID: pending.alarmID)
    }

    private var hourNow: Int { Calendar.current.component(.hour, from: Date()) }
    private var minuteNow: Int { Calendar.current.component(.minute, from: Date()) }
}

/// What a mission view can tell the runner. Two closures, because a mission has exactly two
/// things to report.
struct MissionCallbacks {
    var cleared: () -> Void
    var mistake: () -> Void
}

// MARK: - Chrome pieces

private struct RoundProgress: View {
    let cleared: Int
    let total: Int

    var body: some View {
        HStack(spacing: 10) {
            if total > 1 {
                Text(verbatim: "\(cleared.formatted(.number.grouping(.never))) / \(total.formatted(.number.grouping(.never)))")
                    .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.accent)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surfaceRaised)
                    Capsule()
                        .fill(Theme.dawnGradient)
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 5)
        }
        .accessibilityElement()
        .accessibilityLabel(Text("mission.progress", bundle: .main))
        .accessibilityValue(localized("mission.progress.value", cleared, total))
    }

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1, Double(cleared) / Double(total))
    }
}

private struct CountdownPill: View {
    let seconds: Int

    var body: some View {
        Text(seconds.formatted(.number.grouping(.never)))
            .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(seconds <= 5 ? Theme.danger : Theme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Theme.surfaceRaised, in: .capsule)
            .accessibilityLabel(Text("mission.timeLeft", bundle: .main))
            .accessibilityValue(localized("duration.seconds", seconds))
    }
}

// MARK: - Success

private struct MissionSuccessView: View {
    @Environment(\.app) private var app
    let pending: PendingMission
    let roundsCleared: Int
    let onDone: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            Image(systemName: "sun.max.fill")
                .font(.system(size: 74))
                .foregroundStyle(Theme.dawnGradient)
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)

            VStack(spacing: 8) {
                Text("mission.done.title", bundle: .main)
                    .font(Theme.titleFont)
                    .foregroundStyle(Theme.textPrimary)
                Text(localized("mission.done.body", DurationCopy.spent(elapsed)))
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if streak > 1 {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                    Text(localized("mission.done.streak", streak))
                }
                .font(Theme.headlineFont)
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Theme.accent.opacity(0.14), in: .capsule)
            }

            Spacer()

            Button(action: onDone) {
                Text("mission.done.action", bundle: .main)
            }
            .buttonStyle(DawnButtonStyle())
            .padding(.horizontal, Theme.Metric.gutter)
            .padding(.bottom, 28)
        }
        .task {
            withAnimation(.spring(duration: 0.5)) { appeared = true }
        }
    }

    private var elapsed: TimeInterval { Date().timeIntervalSince(pending.startedAt) }

    /// Includes this morning, which is not yet in the log: the record is written when the
    /// runner finishes, and showing "streak 0" on the screen that celebrates the streak
    /// would be absurd.
    private var streak: Int { app.log.stats().currentStreak + 1 }
}
