import AVFoundation
import DawnbreakKit
import SwiftUI

/// Point the camera at the object you registered.
struct PhotoMissionView: View {
    let config: MissionConfig
    let callbacks: MissionCallbacks

    @State private var recogniser = ObjectRecogniser()
    @State private var matchedFor: TimeInterval = 0
    @State private var cleared = false

    /// The match has to hold for this long. A single frame that happens to score a kettle
    /// while the camera swings past the counter is not the user photographing the kettle.
    private static let requiredHoldSeconds: TimeInterval = 0.6

    var body: some View {
        Group {
            switch recogniser.permission {
            case .granted:
                viewfinder
            case .unknown:
                ProgressView().tint(Theme.accent)
            case .denied, .unavailable:
                MissionUnavailableView(
                    titleKey: "mission.camera.denied.title",
                    bodyKey: "mission.camera.denied.body",
                    onOverride: { callbacks.cleared() }
                )
            }
        }
        .task {
            await recogniser.start(position: .back)
            await watchForMatch()
        }
        .onDisappear { recogniser.stop() }
    }

    private var viewfinder: some View {
        MissionScaffold(
            instructionKey: MissionKind.photo.instructionKey,
            instruction: localized("mission.photo.find", config.enrollment?.displayName ?? "")
        ) {
            ZStack {
                CameraPreview(session: recogniser.engine.session)
                    .clipShape(.rect(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(isMatching ? Theme.success : Theme.hairline, lineWidth: 3)
                    )
                    .padding(.horizontal, Theme.Metric.gutter)

                if isMatching {
                    VStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("mission.photo.holdStill", bundle: .main)
                        }
                        .font(Theme.captionFont)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Theme.success.opacity(0.9), in: .capsule)
                        .padding(.bottom, 22)
                    }
                }
            }
            .frame(maxHeight: 420)
        } control: {
            Text(hintText)
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
                .frame(minHeight: 32)
        }
    }

    private var isMatching: Bool {
        guard let reference = config.enrollment?.reference else { return false }
        return recogniser.matches(reference: reference, threshold: config.recognitionThreshold)
    }

    /// What the classifier currently thinks it is looking at, so a user standing in front of
    /// the wrong object is not left guessing why nothing is happening.
    private var hintText: String {
        guard let best = recogniser.bestLabel, best.confidence > 0.15 else {
            return localized("mission.photo.searching")
        }
        return localized("mission.photo.seeing", best.label)
    }

    private func watchForMatch() async {
        // Polling at 10 Hz rather than observing: the classifier updates several times a
        // second and the hold timer needs a steady tick, not a callback per frame.
        while !cleared && !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(100))
            if isMatching {
                matchedFor += 0.1
                if matchedFor >= Self.requiredHoldSeconds {
                    cleared = true
                    recogniser.stop()
                    callbacks.cleared()
                }
            } else {
                matchedFor = 0
            }
        }
    }
}

/// Scan the barcode you registered.
struct BarcodeMissionView: View {
    let config: MissionConfig
    let callbacks: MissionCallbacks

    @State private var reader = BarcodeReader()
    @State private var wrongCode: String?

    var body: some View {
        Group {
            switch reader.permission {
            case .granted:
                scanner
            case .unknown:
                ProgressView().tint(Theme.accent)
            case .denied, .unavailable:
                MissionUnavailableView(
                    titleKey: "mission.camera.denied.title",
                    bodyKey: "mission.camera.denied.body",
                    onOverride: { callbacks.cleared() }
                )
            }
        }
        .task { await reader.start() }
        .onDisappear { reader.stop() }
        .onChange(of: reader.lastPayload) { _, payload in
            guard let payload else { return }
            if payload == config.enrollment?.reference {
                reader.stop()
                callbacks.cleared()
            } else {
                // Not a mistake in the runner's sense: scanning the wrong box should not
                // restart the round, it should just say so.
                wrongCode = payload
            }
        }
    }

    private var scanner: some View {
        MissionScaffold(
            instructionKey: MissionKind.barcode.instructionKey,
            instruction: localized("mission.barcode.find", config.enrollment?.displayName ?? "")
        ) {
            ZStack {
                CameraPreview(session: reader.engine.session)
                    .clipShape(.rect(cornerRadius: 24))
                    .padding(.horizontal, Theme.Metric.gutter)

                // A reticle, so the user knows where to hold the box.
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.accent, lineWidth: 3)
                    .frame(width: 250, height: 150)
                    .shadow(color: .black.opacity(0.4), radius: 8)
            }
            .frame(maxHeight: 420)
        } control: {
            if wrongCode != nil {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                    Text("mission.barcode.wrong", bundle: .main)
                }
                .font(Theme.captionFont)
                .foregroundStyle(Theme.danger)
                .frame(minHeight: 32)
            } else {
                Text("mission.barcode.hint", bundle: .main)
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .frame(minHeight: 32)
            }
        }
    }
}

/// Squats, counted by the front camera.
struct SquatsMissionView: View {
    let config: MissionConfig
    let callbacks: MissionCallbacks

    @State private var counter = SquatCounter()
    @State private var cleared = false

    var body: some View {
        Group {
            switch counter.permission {
            case .granted:
                counting
            case .unknown:
                ProgressView().tint(Theme.accent)
            case .denied, .unavailable:
                MissionUnavailableView(
                    titleKey: "mission.camera.denied.title",
                    bodyKey: "mission.squats.denied.body",
                    onOverride: { callbacks.cleared() }
                )
            }
        }
        .task { await counter.start() }
        .onDisappear { counter.stop() }
        .onChange(of: counter.count) { _, count in
            guard !cleared, count >= config.squatTarget else { return }
            cleared = true
            counter.stop()
            callbacks.cleared()
        }
    }

    private var counting: some View {
        MissionScaffold(
            instructionKey: MissionKind.squats.instructionKey,
            instruction: localized(counter.state.promptKey)
        ) {
            ZStack {
                CameraPreview(session: counter.engine.session)
                    .clipShape(.rect(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(counter.state == .waitingForBody ? Theme.warning : Theme.hairline, lineWidth: 3)
                    )
                    // Mirrored, because a front-camera view of yourself that moves the wrong
                    // way when you lean is disorienting.
                    .scaleEffect(x: -1, y: 1)
                    .padding(.horizontal, Theme.Metric.gutter)

                VStack {
                    Spacer()
                    CountReadout(
                        count: min(counter.count, config.squatTarget),
                        target: config.squatTarget,
                        unitKey: "mission.squats.unit"
                    )
                    .padding(.vertical, 12)
                    .padding(.horizontal, 22)
                    .background(.black.opacity(0.55), in: .rect(cornerRadius: 20))
                    .padding(.bottom, 20)
                }
            }
            .frame(maxHeight: 460)
        } control: {
            DepthGauge(depth: counter.depth)
        }
    }
}

/// How deep the current squat is. Feedback matters here: without it a user who is not
/// squatting far enough has no idea why the counter is not moving.
private struct DepthGauge: View {
    let depth: Double

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surfaceRaised)
                    Capsule()
                        .fill(depth > 0.9 ? AnyShapeStyle(Theme.success) : AnyShapeStyle(Theme.dawnGradient))
                        .frame(width: proxy.size.width * min(1, max(0, depth)))
                }
            }
            .frame(height: 8)
            Text("mission.squats.depth", bundle: .main)
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
        }
        .animation(.easeOut(duration: 0.15), value: depth)
        .accessibilityElement()
        .accessibilityLabel(Text("mission.squats.depth", bundle: .main))
        .accessibilityValue(Text(depth, format: .percent.precision(.fractionLength(0))))
    }
}
