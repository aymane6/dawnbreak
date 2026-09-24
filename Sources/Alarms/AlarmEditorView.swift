import DawnbreakKit
import SwiftUI

/// Create or edit one alarm. Presented as a sheet from the list.
struct AlarmEditorView: View {
    @Environment(\.app) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var draft: AlarmDraft
    @State private var enrolling = false
    @State private var previewingSound = false
    /// The mission being tried out, built from the draft at the moment the button is
    /// pressed. Nothing is armed: see `MissionRunnerView.Mode.rehearsal`.
    @State private var rehearsing: PendingMission?
    @State private var confirmingDelete = false
    private let isNew: Bool

    init(alarm: AlarmDraft, isNew: Bool) {
        _draft = State(initialValue: alarm)
        self.isNew = isNew
    }

    private var title: LocalizedStringKey { isNew ? "editor.title.new" : "editor.title.edit" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    TimeWheel(hour: $draft.hour, minute: $draft.minute, uses24Hour: app.preferences.usesTwentyFourHourClock)
                        .padding(.top, 4)

                    WeekdayPicker(selection: $draft.repeatDays)

                    labelCard
                    missionCard
                    chainCard
                    soundCard
                    behaviourCard

                    if !isNew {
                        Button(role: .destructive) {
                            confirmingDelete = true
                        } label: {
                            Text("action.deleteAlarm", bundle: .main)
                                .frame(maxWidth: .infinity, minHeight: Theme.Metric.minimumTarget)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.danger)
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, Theme.Metric.gutter)
                .padding(.bottom, 32)
            }
            .dawnCanvas()
            .scrollIndicators(.hidden)
            .navigationTitle(Text(title, bundle: .main))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Drawn here rather than by the bar, which cuts a title short instead of shrinking
                // it: between French or German Cancel and Save buttons, the title already fills the
                // gap on a 6.9-inch phone, and a 6.1-inch one is about 50 points narrower.
                ToolbarItem(placement: .principal) {
                    Text(title, bundle: .main)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityAddTraits(.isHeader)
                }
                .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Text("action.cancel", bundle: .main) }
                        .accessibilityIdentifier(AccessibilityID.editorCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: save) { Text("action.save", bundle: .main).bold() }
                        .disabled(draft.mission.isIncomplete)
                        .accessibilityIdentifier(AccessibilityID.editorSave)
                }
            }
            .sheet(isPresented: $enrolling) {
                EnrollmentView(mission: draft.mission.kind) { enrollment in
                    draft.mission.enrollment = enrollment
                }
            }
            .fullScreenCover(item: $rehearsing) { pending in
                MissionRunnerView(pending: pending, mode: .rehearsal)
            }
            // The same question the list's swipe asks: a mission set up with an enrolled
            // object is a minute of work, and one stray tap should not throw it away.
            .alert(Text("alarm.delete.title", bundle: .main), isPresented: $confirmingDelete) {
                Button(role: .destructive) {
                    app.bridge.cancel(draft.id)
                    app.alarms.remove(id: draft.id)
                    dismiss()
                } label: {
                    Text("action.delete", bundle: .main)
                }
                Button(role: .cancel) {} label: { Text("action.cancel", bundle: .main) }
            } message: {
                Text("alarm.delete.body", bundle: .main)
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Cards

    private var labelCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(titleKey: "editor.label")
                TextField(text: $draft.label) {
                    Text("editor.label.placeholder", bundle: .main)
                }
                .textFieldStyle(.plain)
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.textPrimary)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(Theme.surfaceRaised, in: .rect(cornerRadius: 12))
                .submitLabel(.done)
            }
        }
    }

    private var missionCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(titleKey: "editor.mission")

                MissionGrid(selected: draft.mission.kind) { kind in
                    // The tile already selected changes nothing. Tapping it used to throw away
                    // the object registered for it and start the enrollment again.
                    guard kind != draft.mission.kind else {
                        if draft.mission.isIncomplete { enrolling = true }
                        return
                    }
                    draft.mission.kind = kind
                    // The enrollment belongs to the mission that asked for it; carrying a
                    // barcode payload over to a photo mission would make the alarm
                    // unclearable in a way that looks like a bug.
                    draft.mission.enrollment = nil
                    if kind.needsEnrollment { enrolling = true }
                }

                Text(key: draft.mission.kind.subtitleKey)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if draft.mission.kind.needsEnrollment {
                    enrollmentRow
                }

                Divider().overlay(Theme.hairline)

                DifficultyPicker(selection: Binding(
                    get: { draft.mission.difficulty },
                    set: { level in
                        draft.mission.difficulty = level
                    }
                ))

                RoundsStepper(rounds: Binding(
                    get: { draft.mission.rounds },
                    set: { draft.mission.rounds = $0 }
                ))

                MissionPreviewRow(mission: draft.mission)

                // "Try this mission": the challenge exactly as the alarm will pose it, without
                // arming anything. This is how someone finds out what "brutal" means at 14:00
                // rather than at 06:00.
                Button {
                    var sample = draft
                    sample.volume = 0
                    sample.vibrate = false
                    var pending = PendingMission(alarm: sample, scheduledFor: Date())
                    pending.followOns = []
                    rehearsing = pending
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                        Text("editor.tryMission", bundle: .main)
                    }
                    .font(Theme.bodyFont.weight(.semibold))
                    .foregroundStyle(draft.mission.isIncomplete ? Theme.textTertiary : Theme.accent)
                    .frame(maxWidth: .infinity, minHeight: Theme.Metric.minimumTarget)
                    .background(Theme.accent.opacity(draft.mission.isIncomplete ? 0.06 : 0.13), in: .rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(draft.mission.isIncomplete)
                .accessibilityIdentifier(AccessibilityID.editorTryMission)
            }
        }
    }

    /// The follow-on chain: what the alarm demands again after this mission is cleared.
    private var chainCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(titleKey: "editor.chain")

                Text("editor.chain.detail", bundle: .main)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach($draft.followOns) { $followOn in
                    FollowOnRow(followOn: $followOn, position: (draft.followOns.firstIndex(where: { $0.id == followOn.id }) ?? 0) + 2) {
                        draft.followOns.removeAll { $0.id == followOn.id }
                    }
                }

                if draft.followOns.count < FollowOnMission.maximumCount {
                    Button {
                        draft.followOns.append(FollowOnMission(
                            mission: MissionConfig(kind: .shake, difficulty: draft.mission.difficulty)
                        ))
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text("editor.chain.add", bundle: .main)
                        }
                        .font(Theme.bodyFont.weight(.medium))
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity, minHeight: Theme.Metric.minimumTarget)
                        .background(Theme.surfaceRaised, in: .rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AccessibilityID.editorChainAdd)
                }
            }
        }
    }

    @ViewBuilder private var enrollmentRow: some View {
        Button { enrolling = true } label: {
            HStack(spacing: 12) {
                Image(systemName: draft.mission.enrollment == nil ? "plus.viewfinder" : "checkmark.circle.fill")
                    .foregroundStyle(draft.mission.enrollment == nil ? Theme.accent : Theme.success)
                VStack(alignment: .leading, spacing: 2) {
                    Text(key: draft.mission.enrollment == nil ? "editor.enroll.missing" : "editor.enroll.done")
                        .font(Theme.bodyFont.weight(.medium))
                        .foregroundStyle(Theme.textPrimary)
                    if let name = draft.mission.enrollment?.displayName {
                        Text(name)
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(minHeight: Theme.Metric.minimumTarget)
        }
        .buttonStyle(.plain)
    }

    private var soundCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(titleKey: "editor.sound")
                SoundRow(selection: $draft.soundName)

                // The lock-screen ring follows the iPhone's own volume; this is the level the
                // tone keeps playing at once the mission is open, which is all the app controls.
                LabeledSlider(
                    titleKey: "editor.volume",
                    value: $draft.volume,
                    range: 0.2...1,
                    format: { $0.formatted(.percent.precision(.fractionLength(0))) }
                )

                Toggle(isOn: $draft.vibrate) {
                    Text("editor.vibrate", bundle: .main)
                        .font(Theme.bodyFont)
                }
                .tint(Theme.accent)
            }
        }
    }

    private var behaviourCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(titleKey: "editor.behaviour")

                Toggle(isOn: $draft.relentless) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("editor.relentless", bundle: .main).font(Theme.bodyFont)
                        Text("editor.relentless.detail", bundle: .main)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(Theme.accent)

                Divider().overlay(Theme.hairline)

                Toggle(isOn: $draft.snooze.isAllowed) {
                    Text("editor.snooze.allow", bundle: .main).font(Theme.bodyFont)
                }
                .tint(Theme.accent)

                if draft.snooze.isAllowed {
                    Stepper(value: $draft.snooze.minutes, in: 1...30) {
                        HStack {
                            Text("editor.snooze.length", bundle: .main).font(Theme.bodyFont)
                            Spacer()
                            Text(localized("duration.minutes", draft.snooze.minutes))
                                .font(Theme.bodyFont.monospacedDigit())
                                .foregroundStyle(Theme.accent)
                        }
                    }

                    Picker(selection: Binding(
                        get: { draft.snooze.maxCount ?? 0 },
                        set: { draft.snooze.maxCount = $0 == 0 ? nil : $0 }
                    )) {
                        Text("editor.snooze.unlimited", bundle: .main).tag(0)
                        ForEach([1, 2, 3, 5], id: \.self) { count in
                            Text(localized("editor.snooze.count", count)).tag(count)
                        }
                    } label: {
                        Text("editor.snooze.max", bundle: .main).font(Theme.bodyFont)
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.accent)
                }
            }
        }
    }

    // MARK: - Save

    private func save() {
        var alarm = draft
        alarm.isEnabled = true
        // One difficulty per alarm: the picker above governs the whole morning, and a chain
        // whose second mission silently kept an older difficulty would be a surprise at 06:10.
        // One round each, too — the chain is already the multiplier.
        alarm.followOns = alarm.followOns.map { followOn in
            var adjusted = followOn
            adjusted.mission.difficulty = alarm.mission.difficulty
            adjusted.mission.rounds = 1
            return adjusted
        }
        app.alarms.upsert(alarm)
        Task { await app.bridge.schedule(alarm) }
        dismiss()
    }
}

// MARK: - Time wheel

/// Hour and minute wheels, plus a meridiem wheel in 12-hour regions.
///
/// Not `DatePicker`: an alarm is an hour and a minute, and `DatePicker` also ignores the
/// app's own 24-hour override, which exists because plenty of people on an en-US phone want
/// a 24-hour alarm clock.
struct TimeWheel: View {
    @Binding var hour: Int
    @Binding var minute: Int
    let uses24Hour: Bool

    var body: some View {
        HStack(spacing: 0) {
            Picker(selection: displayHour) {
                ForEach(hourRange, id: \.self) { value in
                    // "07" on a 24-hour wheel, as the system clock writes it; "7" beside AM/PM.
                    Text(uses24Hour ? String(format: "%02d", value).localizedDigits : value.formatted(.number.grouping(.never)))
                        .font(Theme.clock(26))
                        .tag(value)
                }
            } label: { Text("editor.hour", bundle: .main) }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)

            Picker(selection: $minute) {
                ForEach(0..<60, id: \.self) { value in
                    Text(String(format: "%02d", value).localizedDigits)
                        .font(Theme.clock(26))
                        .tag(value)
                }
            } label: { Text("editor.minute", bundle: .main) }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)

            if !uses24Hour {
                Picker(selection: isPM) {
                    Text("clock.am", bundle: .main).tag(false)
                    Text("clock.pm", bundle: .main).tag(true)
                } label: { Text("editor.meridiem", bundle: .main) }
                    .pickerStyle(.wheel)
                    .frame(width: 92)
            }
        }
        .labelsHidden()
        .frame(height: 168)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Metric.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.Metric.cardRadius).stroke(Theme.hairline))
        .accessibilityElement(children: .contain)
    }

    private var hourRange: [Int] { uses24Hour ? Array(0...23) : Array(1...12) }

    /// The wheel shows 1…12 in a 12-hour region; the model always stores 0…23.
    private var displayHour: Binding<Int> {
        Binding(
            get: {
                guard !uses24Hour else { return hour }
                return hour % 12 == 0 ? 12 : hour % 12
            },
            set: { shown in
                guard !uses24Hour else { hour = shown; return }
                let base = shown == 12 ? 0 : shown
                hour = base + (hour >= 12 ? 12 : 0)
            }
        )
    }

    private var isPM: Binding<Bool> {
        Binding(
            get: { hour >= 12 },
            set: { pm in
                let base = hour % 12
                hour = pm ? base + 12 : base
            }
        )
    }
}

private extension String {
    /// Renders the ASCII digits of a preformatted string in the locale's numbering system.
    var localizedDigits: String {
        guard let value = Int(self) else { return self }
        let formatted = value.formatted(.number.grouping(.never))
        guard count > formatted.count,
              let zero = 0.formatted(.number.grouping(.never)).first else { return formatted }
        return String(repeating: String(zero), count: count - formatted.count) + formatted
    }
}

// MARK: - Weekday picker

struct WeekdayPicker: View {
    @Binding var selection: Set<Weekday>

    var body: some View {
        Card(padding: 12) {
            VStack(spacing: 12) {
                HStack(spacing: 6) {
                    ForEach(ordered, id: \.self) { day in
                        let isOn = selection.contains(day)
                        Button {
                            if isOn { selection.remove(day) } else { selection.insert(day) }
                        } label: {
                            Text(key: day.shortLocalizationKey)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity, minHeight: Theme.Metric.minimumTarget)
                                // Solid accent for a choice, as on every picker here; the
                                // gradient is kept for the one button that acts.
                                .foregroundStyle(isOn ? Theme.onAccent : Theme.textSecondary)
                                .background(isOn ? Theme.accent : Theme.surfaceRaised)
                                .clipShape(.rect(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(key: day.localizationKey))
                        .accessibilityAddTraits(isOn ? [.isSelected] : [])
                    }
                }

                HStack(spacing: 8) {
                    presetButton(titleKey: "repeat.never", days: [])
                    presetButton(titleKey: "repeat.weekdays", days: .weekdays)
                    presetButton(titleKey: "repeat.weekends", days: .weekend)
                    presetButton(titleKey: "repeat.everyDay", days: .everyDay)
                }
            }
        }
    }

    private var ordered: [Weekday] {
        Weekday.ordered(firstWeekday: Calendar.autoupdatingCurrent.firstWeekday)
    }

    private func presetButton(titleKey: String, days: Set<Weekday>) -> some View {
        Button { selection = days } label: {
            Text(key: titleKey)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: Theme.Metric.minimumTarget)
                .foregroundStyle(selection == days ? Theme.accent : Theme.textTertiary)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == days ? [.isSelected] : [])
    }
}

// MARK: - Mission grid

private struct MissionGrid: View {
    let selected: MissionKind
    let onSelect: (MissionKind) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(sorted) { kind in
                let isSelected = kind == selected
                Button { onSelect(kind) } label: {
                    VStack(spacing: 5) {
                        Image(systemName: kind.systemImage)
                            .font(.system(size: 20))
                            .frame(width: 30, height: 24)
                        Text(key: kind.titleKey)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity, minHeight: 68)
                    .foregroundStyle(isSelected ? Theme.onAccent : Theme.textSecondary)
                    .background(isSelected ? Theme.accent : Theme.surfaceRaised)
                    .clipShape(.rect(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
    }

    /// Gentlest first, so the list opens with something a new user will actually pick rather
    /// than with twenty-five squats.
    private var sorted: [MissionKind] {
        MissionKind.allCases.sorted { $0.effortRank < $1.effortRank }
    }
}

private struct DifficultyPicker: View {
    @Binding var selection: Difficulty

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(titleKey: "editor.difficulty")
            HStack(spacing: 6) {
                ForEach(Difficulty.allCases, id: \.self) { level in
                    let isOn = level == selection
                    Button { selection = level } label: {
                        Text(key: level.titleKey)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, minHeight: Theme.Metric.minimumTarget)
                            .foregroundStyle(isOn ? Theme.onAccent : Theme.textSecondary)
                            .background(isOn ? Theme.accent : Theme.surfaceRaised, in: .rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? [.isSelected] : [])
                }
            }
        }
    }
}

private struct RoundsStepper: View {
    @Binding var rounds: Int

    var body: some View {
        Stepper(value: Binding(get: { rounds }, set: { rounds = $0 }), in: 1...MissionConfig.maxRounds) {
            HStack {
                Text("editor.rounds", bundle: .main).font(Theme.bodyFont)
                Spacer()
                Text(rounds.formatted(.number.grouping(.never)))
                    .font(Theme.bodyFont.monospacedDigit())
                    .foregroundStyle(Theme.accent)
            }
        }
    }
}

/// One follow-on: which mission comes next and how many minutes of grace precede it.
///
/// The picker offers only the missions that need no enrollment: a follow-on with an
/// unphotographed reference object would make the alarm unclearable, and threading the whole
/// enrollment flow through this row buys nothing the main mission slot does not already offer.
private struct FollowOnRow: View {
    @Binding var followOn: FollowOnMission
    /// 2 for the first follow-on: the alarm's own mission is number 1.
    let position: Int
    let onDelete: () -> Void

    private static let delays = [1, 2, 5, 10, 15, 20, 30, 45, 60]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(verbatim: "\(position.formatted(.number.grouping(.never)))")
                    .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.accent)
                    .frame(width: 26, height: 26)
                    .background(Theme.accent.opacity(0.16), in: .circle)

                Picker(selection: $followOn.mission.kind) {
                    ForEach(choices) { kind in
                        Label {
                            Text(key: kind.titleKey)
                        } icon: {
                            Image(systemName: kind.systemImage)
                        }
                        .tag(kind)
                    }
                } label: {
                    Text("editor.mission", bundle: .main)
                }
                .pickerStyle(.menu)
                .tint(Theme.textPrimary)
                .labelsHidden()

                Spacer(minLength: 0)

                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(width: Theme.Metric.minimumTarget, height: Theme.Metric.minimumTarget)
                }
                .buttonStyle(.plain)
                // This removes one mission from the chain, not the alarm.
                .accessibilityLabel(Text("action.delete", bundle: .main))
            }

            HStack {
                Text("editor.chain.after", bundle: .main)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Picker(selection: $followOn.minutesAfter) {
                    ForEach(Self.delays, id: \.self) { minutes in
                        Text(localized("duration.minutes", minutes)).tag(minutes)
                    }
                } label: {
                    Text("editor.chain.after", bundle: .main)
                }
                .pickerStyle(.menu)
                .tint(Theme.accent)
                .labelsHidden()
            }
        }
        .padding(12)
        .background(Theme.surfaceRaised.opacity(0.6), in: .rect(cornerRadius: 12))
    }

    private var choices: [MissionKind] {
        MissionKind.allCases
            .filter { !$0.needsEnrollment }
            .sorted { $0.effortRank < $1.effortRank }
    }
}

/// One line describing exactly what the alarm will demand, so nobody discovers at 06:00
/// that "brutal" meant two hundred steps.
private struct MissionPreviewRow: View {
    let mission: MissionConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "eye")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                Text(summary)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            // Said where the mission is still a choice, not once it is ringing. An alarm that asks
            // fifteen squats of somebody half asleep is the shape of app App Review's 1.4.5 is
            // written for, and the answer to it is one honest sentence in front of the decision.
            if mission.kind.isPhysical {
                HStack(spacing: 8) {
                    Image(systemName: "figure.walk.motion")
                        .font(.caption)
                        .foregroundStyle(Theme.warning)
                    Text("mission.physicalCaution", bundle: .main)
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(10)
        .background(Theme.surfaceRaised.opacity(0.6), in: .rect(cornerRadius: 12))
    }

    private var summary: String {
        let detail: String = switch mission.kind {
        case .math: localized("preview.math", mission.math.digits)
        case .memory: localized("preview.memory", mission.memory.litTiles, mission.memory.side, mission.memory.side)
        case .sequence: localized("preview.sequence", mission.sequenceLength)
        case .typing: localized("preview.typing", mission.typingWordCount)
        case .shake: localized("preview.shake", mission.shakeCount)
        case .steps: localized("preview.steps", mission.stepTarget)
        case .squats: localized("preview.squats", mission.squatTarget)
        case .photo: localized("preview.photo", mission.enrollment?.displayName ?? localized("preview.photo.unset"))
        case .barcode: localized("preview.barcode", mission.enrollment?.displayName ?? localized("preview.barcode.unset"))
        case .draw: localized("preview.draw")
        case .flap: localized("preview.flap", mission.flapTarget)
        case .breathe: localized("preview.breathe", mission.breathe.cycles)
        }
        guard mission.rounds > 1 else { return detail }
        let rounds = localized("preview.rounds", mission.rounds)
        // A mid-dot rather than a translated suffix: glued on bare, the old suffix read
        // "2-digit sums3 rounds", and the dot needs no translating in any of the twelve.
        return "\(detail) · \(rounds)"
    }
}

// MARK: - Shared controls

struct SectionLabel: View {
    let titleKey: String

    var body: some View {
        Text(key: titleKey)
            .font(Theme.captionFont)
            .foregroundStyle(Theme.textTertiary)
            .eyebrow(tracking: 0.7)
    }
}

private struct LabeledSlider: View {
    let titleKey: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 0.05
    let format: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(key: titleKey).font(Theme.bodyFont)
                Spacer()
                Text(format(value))
                    .font(Theme.captionFont.monospacedDigit())
                    .foregroundStyle(Theme.accent)
            }
            Slider(value: $value, in: range, step: step)
                .tint(Theme.accent)
                .accessibilityLabel(Text(key: titleKey))
                .accessibilityValue(format(value))
        }
    }
}

/// The tone, as one row that opens the list.
///
/// It replaced a horizontal strip of tiles, and the strip is worth describing because it hid ten of
/// the fourteen tones from the person who wrote them. 74pt tiles inside a card leave 317 usable
/// points on a 6.1-inch screen and 364 on a 6.9-inch one, so three or four tiles showed; the scroll
/// indicator was hidden; and nothing else said there was more. The owner tested the shipped build
/// and reported that the app had four alarm sounds. He was reading the screen correctly.
///
/// A row that pushes a screen is the fix rather than a wider strip, because fourteen tiles laid out
/// in the card would add about 230 points to an editor that already scrolls, and because a pushed
/// list is where iOS users look for a choice among many.
private struct SoundRow: View {
    @Binding var selection: String

    var body: some View {
        NavigationLink {
            SoundPickerScreen(selection: $selection)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: sound.loudness.systemImage)
                    .font(.system(size: 15))
                    .foregroundStyle(sound.loudness.tint)
                    .frame(width: 22)
                Text(key: sound.titleKey)
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 8)
                // The count, so the row says out loud how many there are. `verbatim` because it is
                // a number in the user's own digits, not a sentence: Arabic renders it in
                // Arabic-Indic digits through the formatter, and no new string is needed in twelve
                // languages to say "14".
                Text(verbatim: AlarmSound.allCases.count.formatted(.number.grouping(.never)))
                    .font(Theme.captionFont.monospacedDigit())
                    .foregroundStyle(Theme.textTertiary)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(minHeight: Theme.Metric.minimumTarget)
            // The whole row, not just the glyphs: without it the tappable area is the text's own
            // twenty points, which is under the minimum target and reports as a twenty-point element
            // to a UI test asking whether it can be tapped.
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.editorSoundRow)
    }

    private var sound: AlarmSound { AlarmSound(rawValue: selection) ?? .default }
}

/// Every tone at once, three to a row, loudest last.
///
/// Fourteen tiles in five rows of 68 points is 372 points, which fits without scrolling on the
/// smallest screen the app supports. That is the whole design goal: the number of tones has to be
/// countable at a glance, because the last version of this screen made ten of them invisible.
private struct SoundPickerScreen: View {
    @Binding var selection: String
    @State private var preview = SoundPreviewer()

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(spacing: 10), count: 3), spacing: 10) {
                ForEach(AlarmSound.allCases) { sound in
                    tile(sound)
                }
            }
            .padding(.horizontal, Theme.Metric.gutter)
            .padding(.vertical, 16)
            .accessibilityIdentifier(AccessibilityID.editorSoundGrid)
        }
        .dawnCanvas()
        .scrollIndicators(.hidden)
        .navigationTitle(Text("editor.sound", bundle: .main))
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { preview.stop() }
    }

    private func tile(_ sound: AlarmSound) -> some View {
        let isOn = sound.rawValue == selection
        return Button {
            selection = sound.rawValue
            preview.play(sound.rawValue)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: sound.loudness.systemImage)
                    .font(.system(size: 17))
                    .foregroundStyle(isOn ? Theme.onAccent : sound.loudness.tint)
                Text(key: sound.titleKey)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    // Two lines, not one: "Sonnenaufgang" and "Canto de pássaros" do not fit a
                    // third of a 6.1-inch screen on one line, and a truncated tone name is a tone
                    // nobody picks.
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 68)
            .padding(.horizontal, 4)
            .foregroundStyle(isOn ? Theme.onAccent : Theme.textSecondary)
            .background(isOn ? Theme.accent : Theme.surfaceRaised, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.editorTone(sound.rawValue))
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}

private extension AlarmSound.Loudness {
    /// Named `systemImage` so `make_strings` skips it: SF Symbol names, not localization keys.
    var systemImage: String {
        switch self {
        case .gentle: "waveform"
        case .standard: "speaker.wave.2.fill"
        case .harsh: "speaker.wave.3.fill"
        case .savage: "exclamationmark.triangle.fill"
        }
    }

    /// A colour on the icon rather than a label under it: each tile is a third of the screen wide and
    /// already holds the tone's name, which in some of the twelve languages takes the whole width.
    var tint: Color {
        switch self {
        case .gentle, .standard: Theme.textSecondary
        case .harsh: Theme.accent
        case .savage: Theme.danger
        }
    }
}
