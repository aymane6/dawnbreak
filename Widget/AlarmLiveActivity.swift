import ActivityKit
import AlarmKit
import DawnbreakKit
import SwiftUI
import WidgetKit

/// The ringing alarm, as it appears on the lock screen and in the Dynamic Island.
///
/// Informational only, deliberately. AlarmKit draws the stop and mission buttons itself from
/// the `AlarmPresentation` and the two intents the app supplied at schedule time; adding a
/// second set here would mean compiling the intents into this extension as well, and two
/// copies of the type that carries an alarm id across processes is a bug waiting for a
/// release. What this view owes the user is the one thing the system buttons cannot say:
/// which mission is about to be demanded, and whether stopping will actually work.
struct AlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<MissionMetadata>.self) { context in
            LockScreenAlarmView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Theme.canvas.opacity(0.92))
                .activitySystemActionForegroundColor(Theme.accent)
        } dynamicIsland: { context in
            let metadata = context.attributes.metadata

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "alarm.waves.left.and.right.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.dawnGradient)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ModeReadout(state: context.state, compact: true)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(titleText(metadata))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let metadata {
                        MissionSummary(metadata: metadata)
                    }
                }
            } compactLeading: {
                Image(systemName: "alarm.fill")
                    .foregroundStyle(Theme.accent)
            } compactTrailing: {
                ModeReadout(state: context.state, compact: true)
            } minimal: {
                Image(systemName: "alarm.fill")
                    .foregroundStyle(Theme.accent)
            }
            .keylineTint(Theme.accent)
        }
    }

    private func titleText(_ metadata: MissionMetadata?) -> String {
        guard let metadata, !metadata.label.isEmpty else { return localized("alarm.defaultTitle") }
        return metadata.label
    }
}

/// The lock-screen presentation.
private struct LockScreenAlarmView: View {
    let attributes: AlarmAttributes<MissionMetadata>
    let state: AlarmPresentationState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Theme.dawnGradient)
                        .frame(width: 36, height: 36)
                        .opacity(0.22)
                    Image(systemName: "alarm.waves.left.and.right.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.dawnGradient)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(headline)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text(key: subheadKey)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)
                ModeReadout(state: state, compact: false)
            }

            if let metadata = attributes.metadata {
                MissionSummary(metadata: metadata)
            }
        }
        .padding(14)
    }

    private var headline: String {
        guard let label = attributes.metadata?.label, !label.isEmpty else {
            return localized("alarm.defaultTitle")
        }
        return label
    }

    /// A relentless alarm says so here. Knowing that pressing stop only buys a minute is the
    /// difference between doing the mission now and doing it four times.
    private var subheadKey: String {
        guard let metadata = attributes.metadata else { return "widget.subhead.default" }
        return metadata.relentless ? "widget.subhead.relentless" : "widget.subhead.default"
    }
}

/// What the alarm is going to ask for, named plainly.
private struct MissionSummary: View {
    let metadata: MissionMetadata

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: metadata.mission.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Theme.dawnGradient, in: .circle)

            VStack(alignment: .leading, spacing: 1) {
                Text(key: metadata.mission.titleKey)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)
        }
        .accessibilityElement(children: .combine)
    }

    /// "3 rounds · Hard", or the enrolled object's name when there is one, because "the
    /// kettle" is more useful at 06:00 than "medium".
    private var detail: String {
        if let name = metadata.enrollmentName, !name.isEmpty {
            return name
        }
        let rounds = localized("widget.rounds", metadata.rounds)
        return "\(rounds) · \(localized(metadata.difficulty.titleKey))"
    }
}

/// The right-hand readout: the alarm's time while it is ringing, the remaining countdown
/// while it is snoozed, and the paused total while it is held.
private struct ModeReadout: View {
    let state: AlarmPresentationState
    let compact: Bool

    var body: some View {
        switch state.mode {
        case .alert(let alert):
            Text(clock.digits(hour: alert.time.hour, minute: alert.time.minute))
                .font(.system(size: compact ? 14 : 19, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(Theme.accent)
        case .countdown(let countdown):
            // `timerInterval` rather than a computed string: the system redraws this without
            // waking the extension, which is the only way a lock-screen countdown stays
            // accurate to the second.
            Text(timerInterval: Date.now...countdown.fireDate, countsDown: true)
                .font(.system(size: compact ? 14 : 19, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(Theme.warning)
                .frame(minWidth: compact ? 46 : 62)
        case .paused:
            Image(systemName: "pause.circle.fill")
                .font(.system(size: compact ? 15 : 20))
                .foregroundStyle(Theme.textSecondary)
        @unknown default:
            // AlarmKit's mode is a non-frozen enum, so a future iOS can add one, and this view
            // has nothing but the mode to draw from: inventing a time here would mean showing a
            // wrong one. The alarm glyph says "this alarm is in a state this build does not
            // know", which is honest, and the label and mission next to it still read.
            Image(systemName: "alarm.fill")
                .font(.system(size: compact ? 15 : 20))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    /// The extension cannot read the app's `Preferences`, which live in the app container's
    /// `UserDefaults`. The region's own convention is the honest fallback, and it is what the
    /// lock screen's own clock uses anyway.
    private var clock: ClockFormatter {
        ClockFormatter(uses24Hour: Preferences.regionPrefers24Hour())
    }
}
