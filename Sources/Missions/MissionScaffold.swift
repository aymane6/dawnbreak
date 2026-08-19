import SwiftUI

/// The layout every mission shares: an instruction, the challenge, and whatever control the
/// mission needs at the bottom. Written once so twelve screens cannot drift apart in spacing.
struct MissionScaffold<Challenge: View, Control: View>: View {
    let instructionKey: String
    /// Overrides the instruction when a mission needs to name something, e.g. "Photograph
    /// the kettle". Localized by the caller.
    var instruction: String?
    @ViewBuilder var challenge: Challenge
    @ViewBuilder var control: Control

    var body: some View {
        VStack(spacing: 0) {
            Text(instruction ?? localized(instructionKey))
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 28)
                .padding(.top, 18)

            Spacer(minLength: 12)

            challenge
                .frame(maxWidth: .infinity)

            Spacer(minLength: 12)

            control
                .padding(.horizontal, Theme.Metric.gutter)
                .padding(.bottom, 10)
        }
    }
}

extension MissionScaffold where Control == EmptyView {
    init(instructionKey: String, instruction: String? = nil, @ViewBuilder challenge: () -> Challenge) {
        self.instructionKey = instructionKey
        self.instruction = instruction
        self.challenge = challenge()
        self.control = EmptyView()
    }
}

/// A big number with a target under it: "4 / 10 push-ups". Used by every counting mission,
/// which is five of the twelve.
struct CountReadout: View {
    let count: Int
    let target: Int
    let unitKey: String

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(count.formatted(.number.grouping(.never)))
                    .font(Theme.clock(84))
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText(value: Double(count)))
                Text(verbatim: "/")
                    .font(Theme.clock(40))
                    .foregroundStyle(Theme.textTertiary)
                Text(target.formatted(.number.grouping(.never)))
                    .font(Theme.clock(40))
                    .foregroundStyle(Theme.textSecondary)
            }
            Text(key: unitKey)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.textTertiary)
                .textCase(.uppercase)
                .tracking(1)
        }
        .animation(.spring(duration: 0.3), value: count)
        .accessibilityElement()
        .accessibilityLabel(Text(key: unitKey))
        .accessibilityValue(localized("mission.progress.value", count, target))
    }
}

/// A ring that fills as a count approaches its target. Sits behind the readout on the motion
/// missions, where there is nothing else to look at.
struct ProgressRing: View {
    let fraction: Double
    var lineWidth: CGFloat = 12

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.surfaceRaised, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, fraction)))
                .stroke(Theme.dawnGradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.3), value: fraction)
        }
    }
}

/// The permission wall a camera or motion mission shows instead of a dead viewfinder.
///
/// It has its own escape route on purpose: a user who denied camera access and set a squat
/// alarm has to be able to get out, and the runner's corner button may be off if they turned
/// the escape hatch off in settings.
struct MissionUnavailableView: View {
    let titleKey: String
    let bodyKey: String
    let onOverride: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.warning)
            Text(key: titleKey)
                .font(Theme.headlineFont)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text(key: bodyKey)
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("action.openSettings", bundle: .main)
            }
            .buttonStyle(DawnButtonStyle())

            Button(action: onOverride) {
                Text("mission.unavailable.dismiss", bundle: .main)
            }
            .buttonStyle(QuietButtonStyle())
        }
        .padding(28)
    }
}
