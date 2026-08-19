import DawnbreakKit
import SwiftUI

/// Create or edit one alarm. Presented as a sheet from the list.
struct AlarmEditorView: View {
    @Environment(\.app) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var draft: AlarmDraft
    @State private var enrolling = false
    @State private var previewingSound = false
    private let isNew: Bool

    init(alarm: AlarmDraft, isNew: Bool) {
        _draft = State(initialValue: alarm)
        self.isNew = isNew
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    TimeWheel(hour: $draft.hour, minute: $draft.minute, uses24Hour: app.preferences.usesTwentyFourHourClock)
                        .padding(.top, 4)

                    WeekdayPicker(selection: $draft.repeatDays)

                    labelCard
                    missionCard
                    soundCard
                    behaviourCard

                    if !isNew {
                        Button(role: .destructive) {
                            app.bridge.cancel(draft.id)
                            app.alarms.remove(id: draft.id)
                            dismiss()
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
            .navigationTitle(Text(isNew ? "editor.title.new" : "editor.title.edit", bundle: .main))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
                    guard app.allow(.mission(kind)) else { return }
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
                        guard app.allow(.difficulty(level)) else { return }
                        draft.mission.difficulty = level
                    }
                ))

                RoundsStepper(rounds: Binding(
                    get: { draft.mission.rounds },
                    set: { count in
                        guard app.allow(.rounds(count)) else { return }
                        draft.mission.rounds = count
                    }
                ), maximum: app.entitlement.maximumRounds)

                MissionPreviewRow(mission: draft.mission)
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
                Image(systemName: "chevron.right")
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
                SoundPicker(selection: $draft.soundName)

                LabeledSlider(
                    titleKey: "editor.volume",
                    value: $draft.volume,
                    range: 0.2...1,
                    format: { "\(Int(($0 * 100).rounded()))%" }
                )

                Toggle(isOn: $draft.vibrate) {
                    Text("editor.vibrate", bundle: .main)
                        .font(Theme.bodyFont)
                }
                .tint(Theme.accent)

                // Gentle wake ramps the in-app mission audio up from silence. It is off by
                // default because someone who chose this app wants to be woken, not eased.
                LabeledSlider(
                    titleKey: "editor.gentleWake",
                    value: Binding(
                        get: { Double(draft.gentleWakeSeconds) },
                        set: { draft.gentleWakeSeconds = Int($0.rounded()) }
                    ),
                    range: 0...120,
                    step: 15,
                    format: { $0 < 1 ? localized("editor.gentleWake.off") : localized("duration.seconds", Int($0)) }
                )
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
                    Text(value.formatted(.number.grouping(.never)))
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
                                .foregroundStyle(isOn ? .white : Theme.textSecondary)
                                .background {
                                    if isOn {
                                        Theme.dawnGradient
                                    } else {
                                        Theme.surfaceRaised
                                    }
                                }
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
                .frame(maxWidth: .infinity, minHeight: 32)
                .foregroundStyle(selection == days ? Theme.accent : Theme.textTertiary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mission grid

private struct MissionGrid: View {
    @Environment(\.app) private var app
    let selected: MissionKind
    let onSelect: (MissionKind) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(sorted) { kind in
                let isSelected = kind == selected
                let locked = !app.entitlement.allows(kind)
                Button { onSelect(kind) } label: {
                    VStack(spacing: 5) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: kind.systemImage)
                                .font(.system(size: 20))
                                .frame(width: 30, height: 24)
                            if locked {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 8, weight: .bold))
                                    .offset(x: 6, y: -3)
                                    .foregroundStyle(Theme.warning)
                            }
                        }
                        Text(key: kind.titleKey)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity, minHeight: 68)
                    .foregroundStyle(isSelected ? .white : Theme.textSecondary)
                    .background {
                        if isSelected {
                            Theme.dawnGradient
                        } else {
                            Theme.surfaceRaised
                        }
                    }
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
    @Environment(\.app) private var app
    @Binding var selection: Difficulty

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(titleKey: "editor.difficulty")
            HStack(spacing: 6) {
                ForEach(Difficulty.allCases, id: \.self) { level in
                    let isOn = level == selection
                    let locked = !app.entitlement.allows(level)
                    Button { selection = level } label: {
                        HStack(spacing: 4) {
                            Text(key: level.titleKey)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                            if locked {
                                Image(systemName: "lock.fill").font(.system(size: 8, weight: .bold))
                            }
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .foregroundStyle(isOn ? .white : Theme.textSecondary)
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
    let maximum: Int

    var body: some View {
        Stepper(value: Binding(get: { rounds }, set: { rounds = $0 }), in: 1...MissionConfig.maxRounds) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("editor.rounds", bundle: .main).font(Theme.bodyFont)
                    if maximum < MissionConfig.maxRounds {
                        Text("editor.rounds.freeLimit", bundle: .main)
                            .font(.caption2)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                Spacer()
                Text(rounds.formatted(.number.grouping(.never)))
                    .font(Theme.bodyFont.monospacedDigit())
                    .foregroundStyle(Theme.accent)
            }
        }
    }
}

/// One line describing exactly what the alarm will demand, so nobody discovers at 06:00
/// that "brutal" meant two hundred steps.
private struct MissionPreviewRow: View {
    let mission: MissionConfig

    var body: some View {
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
        return detail + localized("preview.roundsSuffix", mission.rounds)
    }
}

// MARK: - Shared controls

struct SectionLabel: View {
    let titleKey: String

    var body: some View {
        Text(key: titleKey)
            .font(Theme.captionFont)
            .foregroundStyle(Theme.textTertiary)
            .textCase(.uppercase)
            .tracking(0.7)
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

private struct SoundPicker: View {
    @Binding var selection: String
    @State private var preview = SoundPreviewer()

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(sorted) { sound in
                    let isOn = sound.rawValue == selection
                    Button {
                        selection = sound.rawValue
                        preview.play(sound.rawValue)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: sound.isGentle ? "waveform" : "speaker.wave.3.fill")
                                .font(.system(size: 15))
                            Text(key: sound.titleKey)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .lineLimit(1)
                        }
                        .frame(width: 74, height: 58)
                        .foregroundStyle(isOn ? .white : Theme.textSecondary)
                        .background(isOn ? Theme.accent : Theme.surfaceRaised, in: .rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? [.isSelected] : [])
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .onDisappear { preview.stop() }
    }

    /// Gentle tones first: someone browsing the list is more likely to be looking for a way
    /// to be woken kindly than for the klaxon.
    private var sorted: [AlarmSound] {
        AlarmSound.allCases.sorted { ($0.isGentle ? 0 : 1, $0.rawValue) < ($1.isGentle ? 0 : 1, $1.rawValue) }
    }
}
