import DawnbreakKit
import SwiftUI

/// The home screen: the next alarm, then every alarm as a card.
struct AlarmListView: View {
    @Environment(\.app) private var app
    @State private var editing: EditorRoute?
    /// Ticks once a minute so the "in 7 h 20 min" line stays true without a timer per row.
    @State private var now = Date()

    private enum EditorRoute: Identifiable {
        case new
        case existing(AlarmDraft)

        var id: String {
            switch self {
            case .new: "new"
            case .existing(let alarm): alarm.id.uuidString
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    NextAlarmHeader(next: app.alarms.nextUp(now: now), now: now)
                        .padding(.bottom, 6)

                    if app.alarms.alarms.isEmpty {
                        EmptyAlarmsCard { addAlarm() }
                    } else {
                        ForEach(app.alarms.alarms) { alarm in
                            AlarmRow(
                                alarm: alarm,
                                now: now,
                                // `@Sendable`, so nonisolated, so the hop has to be spelled out.
                                // SwiftUI calls a Binding's setter from the main actor, which is
                                // why assuming it is sound rather than optimistic.
                                onToggle: { isOn in
                                    MainActor.assumeIsolated { toggle(alarm, to: isOn) }
                                },
                                onTap: { editing = .existing(alarm) },
                                onDelete: { delete(alarm) }
                            )
                        }
                    }
                }
                .padding(.horizontal, Theme.Metric.gutter)
                .padding(.bottom, 96)
            }
            .dawnCanvas()
            .scrollIndicators(.hidden)
            .navigationTitle(Text("alarms.title", bundle: .main))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: addAlarm) {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: Theme.Metric.minimumTarget, height: Theme.Metric.minimumTarget)
                    }
                    .accessibilityLabel(Text("alarms.add", bundle: .main))
                    .accessibilityIdentifier(AccessibilityID.addAlarm)
                }
            }
            .sheet(item: $editing) { route in
                switch route {
                case .new:
                    AlarmEditorView(alarm: AlarmDraft(), isNew: true)
                case .existing(let alarm):
                    AlarmEditorView(alarm: alarm, isNew: false)
                }
            }
            .overlay(alignment: .bottom) { permissionBanner }
            .task {
                // One minute is the resolution of everything on this screen, so the timer
                // fires on the minute boundary rather than every second.
                while !Task.isCancelled {
                    now = Date()
                    let secondsToNextMinute = 60 - (Calendar.current.component(.second, from: now))
                    try? await Task.sleep(for: .seconds(secondsToNextMinute))
                }
            }
            .alert(
                Text("error.title", bundle: .main),
                isPresented: Binding(get: { app.bridge.lastFailure != nil }, set: { if !$0 { app.bridge.clearFailure() } })
            ) {
                Button(role: .cancel) { app.bridge.clearFailure() } label: { Text("action.ok", bundle: .main) }
            } message: {
                if let failure = app.bridge.lastFailure {
                    Text(key: failure.messageKey)
                }
            }
        }
    }

    /// Shown when AlarmKit permission is missing, because in that state every alarm in the
    /// list is a lie: it will not ring.
    @ViewBuilder private var permissionBanner: some View {
        if app.bridge.authorization == .denied && !app.alarms.alarms.isEmpty {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.warning)
                VStack(alignment: .leading, spacing: 2) {
                    Text("permission.alarm.deniedTitle", bundle: .main)
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textPrimary)
                    Text("permission.alarm.deniedBody", bundle: .main)
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 8)
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("action.openSettings", bundle: .main)
                        .font(Theme.captionFont)
                }
                .buttonStyle(.bordered)
                .tint(Theme.warning)
            }
            .padding(14)
            .background(Theme.surfaceRaised, in: .rect(cornerRadius: Theme.Metric.controlRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.Metric.controlRadius).stroke(Theme.warning.opacity(0.4)))
            .padding(.horizontal, Theme.Metric.gutter)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Actions

    private func addAlarm() {
        guard app.allow(.addAlarm) else { return }
        editing = .new
    }

    private func toggle(_ alarm: AlarmDraft, to enabled: Bool) {
        app.alarms.setEnabled(enabled, id: alarm.id)
        guard var updated = app.alarms.alarm(id: alarm.id) else { return }
        updated.isEnabled = enabled
        Task { await app.bridge.schedule(updated) }
    }

    private func delete(_ alarm: AlarmDraft) {
        app.bridge.cancel(alarm.id)
        app.alarms.remove(id: alarm.id)
    }
}

// MARK: - Header

/// "Next alarm" with the countdown, or an invitation when nothing is armed.
private struct NextAlarmHeader: View {
    @Environment(\.app) private var app
    let next: (alarm: AlarmDraft, fireDate: Date)?
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let next {
                Text("alarms.nextUp", bundle: .main)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.8)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(formatter.digits(hour: next.alarm.hour, minute: next.alarm.minute))
                        .font(Theme.clock(52))
                        .foregroundStyle(Theme.textPrimary)
                    if let meridiem = formatter.meridiem(hour: next.alarm.hour) {
                        Text(meridiem)
                            .font(Theme.headlineFont)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer(minLength: 0)
                }

                if let components = next.alarm.timeUntilNextFire(from: now) {
                    Text(DurationCopy.untilNextFire(components))
                        .font(Theme.bodyFont)
                        .foregroundStyle(Theme.accent)
                }
            } else {
                Text("alarms.noneArmedTitle", bundle: .main)
                    .font(Theme.titleFont)
                    .foregroundStyle(Theme.textPrimary)
                Text("alarms.noneArmedBody", bundle: .main)
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }

    private var formatter: ClockFormatter {
        ClockFormatter(uses24Hour: app.preferences.usesTwentyFourHourClock)
    }
}

// MARK: - Row

private struct AlarmRow: View {
    @Environment(\.app) private var app
    let alarm: AlarmDraft
    let now: Date
    /// Sendable because it is handed to `Binding(get:set:)`, whose setter is `@isolated(any)
    /// @Sendable` in the iOS 26 SDK; a plain `(Bool) -> Void` there compiles with a data-race
    /// warning. Not `@MainActor` as well, which is what it really is: that annotation crashes
    /// swift-frontend in IRGen on Xcode 26.5 while emitting the `@isolated(any)` thunk.
    let onToggle: @Sendable (Bool) -> Void
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var confirmingDelete = false

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(formatter.digits(hour: alarm.hour, minute: alarm.minute))
                                .font(Theme.clock(38))
                            if let meridiem = formatter.meridiem(hour: alarm.hour) {
                                Text(meridiem)
                                    .font(Theme.captionFont)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .foregroundStyle(alarm.isEnabled ? Theme.textPrimary : Theme.textTertiary)

                        Text(repeatSummary)
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.textSecondary)
                    }

                    Spacer(minLength: 8)

                    Toggle("", isOn: Binding(get: { alarm.isEnabled }, set: onToggle))
                        .labelsHidden()
                        .tint(Theme.accent)
                        .accessibilityLabel(Text("alarms.toggle", bundle: .main))
                }

                if !alarm.label.isEmpty {
                    Text(alarm.label)
                        .font(Theme.bodyFont.weight(.medium))
                        .foregroundStyle(alarm.isEnabled ? Theme.textPrimary : Theme.textTertiary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    MissionChip(mission: alarm.mission, dimmed: !alarm.isEnabled)
                    if alarm.relentless {
                        Chip(systemImage: "repeat", titleKey: "alarm.relentless.short", dimmed: !alarm.isEnabled)
                    }
                    if alarm.mission.isIncomplete {
                        Chip(systemImage: "exclamationmark.circle.fill", titleKey: "alarm.needsSetup", tint: Theme.warning, dimmed: false)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .contentShape(.rect)
        .onTapGesture(perform: onTap)
        .contextMenu {
            Button(role: .destructive) { confirmingDelete = true } label: {
                Label { Text("action.delete", bundle: .main) } icon: { Image(systemName: "trash") }
            }
        }
        // A confirmation, not a swipe-to-delete without one: deleting the alarm that gets
        // someone to work is not an undoable mistake at 23:00.
        .alert(Text("alarm.delete.title", bundle: .main), isPresented: $confirmingDelete) {
            Button(role: .destructive, action: onDelete) { Text("action.delete", bundle: .main) }
            Button(role: .cancel) {} label: { Text("action.cancel", bundle: .main) }
        } message: {
            Text("alarm.delete.body", bundle: .main)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("alarms.rowHint", bundle: .main))
        // After `.combine`, so it lands on the element the test can actually tap rather than on
        // a container the combined child has replaced.
        .accessibilityIdentifier(AccessibilityID.alarmRow)
    }

    private var formatter: ClockFormatter {
        ClockFormatter(uses24Hour: app.preferences.usesTwentyFourHourClock)
    }

    /// "Every day"/"Weekdays" when the set has a name, otherwise the short day names in the
    /// region's own week order.
    private var repeatSummary: String {
        if let key = alarm.repeatDays.repeatSummaryKey { return localized(key) }
        let firstWeekday = Calendar.autoupdatingCurrent.firstWeekday
        return Weekday.ordered(firstWeekday: firstWeekday)
            .filter { alarm.repeatDays.contains($0) }
            .map { localized($0.shortLocalizationKey) }
            .joined(separator: localized("list.separator"))
    }
}

// MARK: - Chips

private struct MissionChip: View {
    let mission: MissionConfig
    let dimmed: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: mission.kind.systemImage)
                .font(.system(size: 11, weight: .semibold))
            Text(key: mission.kind.titleKey)
                .font(.system(size: 12, weight: .medium, design: .rounded))
            if mission.rounds > 1 {
                Text(verbatim: "×\(mission.rounds.formatted(.number.grouping(.never)))")
                    .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .foregroundStyle(dimmed ? Theme.textTertiary : Theme.accent)
        .background((dimmed ? Theme.textTertiary : Theme.accent).opacity(0.14), in: .capsule)
    }
}

private struct Chip: View {
    let systemImage: String
    let titleKey: String
    var tint: Color = Theme.textSecondary
    let dimmed: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
            Text(key: titleKey)
                .font(.system(size: 12, weight: .medium, design: .rounded))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .foregroundStyle(dimmed ? Theme.textTertiary : tint)
        .background((dimmed ? Theme.textTertiary : tint).opacity(0.12), in: .capsule)
    }
}

// MARK: - Empty state

private struct EmptyAlarmsCard: View {
    let onAdd: () -> Void

    var body: some View {
        Card(padding: 26) {
            VStack(spacing: 16) {
                Image(systemName: "sunrise.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(Theme.dawnGradient)
                Text("alarms.empty.title", bundle: .main)
                    .font(Theme.headlineFont)
                    .foregroundStyle(Theme.textPrimary)
                Text("alarms.empty.body", bundle: .main)
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                Button(action: onAdd) {
                    Text("alarms.empty.action", bundle: .main)
                }
                .buttonStyle(DawnButtonStyle())
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private extension View {
    func sheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        sheet(isPresented: Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } })) {
            if let value = item.wrappedValue {
                content(value)
            }
        }
    }
}
