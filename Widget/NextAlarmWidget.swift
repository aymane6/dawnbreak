import DawnbreakKit
import SwiftUI
import WidgetKit

/// The next alarm, on the home screen and the lock screen.
///
/// Its job is the question people actually ask before bed: what time am I getting up, and
/// what will it make me do. Nothing is tappable beyond opening the app, because a widget
/// that can disarm an alarm by accident is a widget that makes someone late.
struct NextAlarmWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.aymbam.dawnbreak.nextAlarm", provider: NextAlarmProvider()) { entry in
            NextAlarmWidgetView(entry: entry)
                .containerBackground(Theme.canvas.gradient, for: .widget)
        }
        .configurationDisplayName(Text("widget.next.name", bundle: .main))
        .description(Text("widget.next.description", bundle: .main))
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

struct NextAlarmEntry: TimelineEntry {
    let date: Date
    let hour: Int
    let minute: Int
    let mission: MissionKind?
    let label: String
    let rounds: Int
    let isEmpty: Bool

    static let placeholder = NextAlarmEntry(
        date: .distantPast, hour: 6, minute: 30, mission: .math, label: "", rounds: 3, isEmpty: false
    )
}

struct NextAlarmProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextAlarmEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (NextAlarmEntry) -> Void) {
        completion(entry(now: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextAlarmEntry>) -> Void) {
        let now = Date()
        let current = entry(now: now)
        // Refreshed just after the alarm it is showing fires, because that is the moment the
        // answer changes; and at least once an hour so a repeating alarm's "tomorrow" does
        // not linger past midnight.
        let alarms = AlarmStore.peek()
        let nextChange = AlarmStore.nextUp(in: alarms.filter(\.isEnabled), now: now)?.fireDate.addingTimeInterval(60)
        let reload = min(nextChange ?? now.addingTimeInterval(3600), now.addingTimeInterval(3600))
        completion(Timeline(entries: [current], policy: .after(reload)))
    }

    private func entry(now: Date) -> NextAlarmEntry {
        let alarms = AlarmStore.peek().filter(\.isEnabled)
        guard let next = AlarmStore.nextUp(in: alarms, now: now) else {
            return NextAlarmEntry(date: now, hour: 0, minute: 0, mission: nil, label: "", rounds: 0, isEmpty: true)
        }
        return NextAlarmEntry(
            date: now,
            hour: next.alarm.hour,
            minute: next.alarm.minute,
            mission: next.alarm.mission.kind,
            label: next.alarm.label,
            rounds: next.alarm.mission.rounds,
            isEmpty: false
        )
    }
}

struct NextAlarmWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NextAlarmEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(inlineText)
        case .accessoryRectangular:
            rectangular
        case .systemMedium:
            medium
        default:
            small
        }
    }

    // MARK: - Families

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: entry.isEmpty ? "alarm.slash" : "alarm.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text("widget.next.title", bundle: .main)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Theme.accent)

            Spacer(minLength: 0)

            if entry.isEmpty {
                Text("widget.next.none", bundle: .main)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(timeText)
                    .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                if let mission = entry.mission {
                    HStack(spacing: 4) {
                        Image(systemName: mission.systemImage)
                            .font(.system(size: 10))
                        Text(key: mission.titleKey)
                            .font(.system(size: 11))
                            .lineLimit(1)
                    }
                    .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var medium: some View {
        HStack(spacing: 14) {
            small
            if !entry.isEmpty, let mission = entry.mission {
                Divider().overlay(Theme.hairline)
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: mission.systemImage)
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.dawnGradient)
                    Text(key: mission.instructionKey)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    if !entry.label.isEmpty {
                        Text(entry.label)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// The lock-screen rectangle. Tinted rendering strips colour, so this leans on weight and
    /// the SF Symbol rather than the accent.
    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: entry.isEmpty ? "alarm.slash" : "alarm.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text("widget.next.title", bundle: .main)
                    .font(.system(size: 11, weight: .semibold))
            }
            if entry.isEmpty {
                Text("widget.next.none", bundle: .main).font(.system(size: 13))
            } else {
                Text(timeText)
                    .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                if let mission = entry.mission {
                    Text(key: mission.titleKey)
                        .font(.system(size: 11))
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Copy

    private var clock: ClockFormatter {
        ClockFormatter(uses24Hour: Preferences.regionPrefers24Hour())
    }

    private var timeText: String {
        clock.full(hour: entry.hour, minute: entry.minute)
    }

    private var inlineText: String {
        entry.isEmpty ? localized("widget.next.none") : localized("widget.next.inline", timeText)
    }
}
