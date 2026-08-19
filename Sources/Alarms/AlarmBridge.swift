import ActivityKit
import AlarmKit
import DawnbreakKit
import Foundation
import Observation
import SwiftUI

/// The only place that talks to AlarmKit.
///
/// Two responsibilities, kept together because they are two halves of one contract:
/// translating an `AlarmDraft` into an `AlarmConfiguration`, and handling the intents that
/// come back when the user presses something on the ringing alert.
@MainActor
@Observable
final class AlarmBridge {
    static let shared = AlarmBridge()

    private(set) var authorization: AlarmManager.AuthorizationState = .notDetermined
    /// Set when an alarm is ringing and the mission screen should be on screen. The root
    /// view watches this.
    private(set) var activeMission: PendingMission?
    /// Surfaced rather than logged: an alarm that failed to schedule is an alarm that will
    /// not ring, and the user has to find that out now rather than tomorrow morning.
    private(set) var lastFailure: Failure?

    /// Injected by the app at launch so the bridge can look up the full alarm for an id
    /// arriving from an intent, and can write the wake record.
    private var alarms: AlarmStore?
    private var log: WakeLogStore?

    private let manager = AlarmManager.shared
    private var updatesTask: Task<Void, Never>?

    struct Failure: Identifiable, Hashable {
        let id = UUID()
        var messageKey: String
        var detail: String
    }

    /// How long after a dodged mission the alarm comes back. Short enough that going back
    /// to sleep does not work, long enough that the phone is not unusable.
    static let relentlessDelay: TimeInterval = 60

    private init() {
        authorization = manager.authorizationState
    }

    func attach(alarms: AlarmStore, log: WakeLogStore) {
        self.alarms = alarms
        self.log = log
        observeAuthorization()
    }

    // MARK: - Authorization

    /// Requested at the moment the user arms their first alarm, not at launch. Asking for
    /// the right to interrupt someone's Focus mode before they have set an alarm earns a
    /// "no", and a denied AlarmKit permission makes the app pointless.
    @discardableResult
    func requestAuthorization() async -> AlarmManager.AuthorizationState {
        do {
            let state = try await AlarmSystem.requestAuthorization()
            authorization = state
            return state
        } catch {
            lastFailure = Failure(messageKey: "error.authorizationFailed", detail: String(describing: error))
            return manager.authorizationState
        }
    }

    /// Also called by onboarding, whose permission page has to redraw the instant the system
    /// alert is answered — including when it is answered in Settings, with the app suspended.
    func observeAuthorization() {
        updatesTask?.cancel()
        updatesTask = Task { [weak self] in
            guard let self else { return }
            for await state in manager.authorizationUpdates {
                await MainActor.run { self.authorization = state }
            }
        }
    }

    // MARK: - Scheduling

    /// Arms an alarm, replacing any previously scheduled version of it.
    ///
    /// Called on every edit and on every toggle, and it is idempotent: AlarmKit keys on the
    /// id, so re-scheduling the same id updates rather than duplicates.
    func schedule(_ alarm: AlarmDraft) async {
        guard alarm.isEnabled else {
            cancel(alarm.id)
            return
        }
        guard !alarm.mission.isIncomplete else {
            lastFailure = Failure(messageKey: "error.missionNeedsSetup", detail: alarm.mission.kind.rawValue)
            return
        }
        if authorization != .authorized {
            let state = await requestAuthorization()
            guard state == .authorized else {
                lastFailure = Failure(messageKey: "error.alarmPermissionDenied", detail: "\(state)")
                return
            }
        }

        do {
            try await AlarmSystem.schedule(alarm)
            lastFailure = nil
        } catch AlarmManager.AlarmError.maximumLimitReached {
            lastFailure = Failure(messageKey: "error.tooManyAlarms", detail: "")
        } catch {
            lastFailure = Failure(messageKey: "error.scheduleFailed", detail: String(describing: error))
        }
    }

    func cancel(_ id: UUID) {
        // A cancel for an alarm the system does not know about throws, and that is fine:
        // the desired end state is "not scheduled", which is already true.
        try? manager.cancel(id: id)
    }

    /// Re-arms every enabled alarm. Run at launch, because an app update or a restore from
    /// backup leaves the store full of alarms the system has never been told about.
    func reconcile() async {
        guard let alarms else { return }
        let scheduled = Set(((try? manager.alarms) ?? []).map(\.id))
        for alarm in alarms.alarms where alarm.isEnabled && !scheduled.contains(alarm.id) {
            await schedule(alarm)
        }
        // The reverse direction too: an alarm switched off while the app was closed.
        for id in scheduled where alarms.alarm(id: id)?.isEnabled != true {
            cancel(id)
        }
    }

    // MARK: - Intent handling

    /// The alert's stop affordance was pressed.
    ///
    /// The alarm is now silent — the system did that before the intent ran, and no API can
    /// prevent it. What we can do is open the mission and, when the alarm is relentless,
    /// arm a follow-up. Clearing the mission cancels it.
    func handleStopPressed(alarmID: UUID) async {
        await beginMission(alarmID: alarmID, countAsDodge: true)
        guard let pending = activeMission, pending.relentless else { return }
        await armFollowUp(for: alarmID)
    }

    /// The mission button was pressed. Same destination, but this is not a dodge.
    func handleMissionRequested(alarmID: UUID) async {
        await beginMission(alarmID: alarmID, countAsDodge: false)
    }

    func handleSnoozePressed(alarmID: UUID) async {
        guard let alarm = alarms?.alarm(id: alarmID) else { return }
        var pending = PendingMissionStore.loadIfFresh() ?? PendingMission(alarm: alarm, scheduledFor: Date())
        guard pending.canSnooze else { return }
        pending.snoozeCount += 1
        PendingMissionStore.save(pending)
        activeMission = pending
        log?.amendLatest(alarmID: alarmID) { $0.snoozeCount = pending.snoozeCount }
        await armFollowUp(for: alarmID, after: TimeInterval(alarm.snooze.minutes * 60))
    }

    private func beginMission(alarmID: UUID, countAsDodge: Bool) async {
        guard let alarm = alarms?.alarm(id: alarmID) else {
            // The alarm was deleted between ringing and the button being pressed. Nothing
            // to demand, so clear the handoff rather than opening an empty mission screen.
            PendingMissionStore.clear()
            activeMission = nil
            return
        }

        var pending: PendingMission
        if let existing = PendingMissionStore.loadIfFresh(), existing.alarmID == alarmID {
            pending = existing
        } else {
            pending = PendingMission(alarm: alarm, scheduledFor: alarm.nextFireDate(after: Date().addingTimeInterval(-86_400)) ?? Date())
            // First sighting of this morning's alarm: open the wake record now, so a phone
            // that dies mid-mission still leaves evidence the alarm rang.
            log?.append(WakeRecord(
                alarmID: alarmID,
                scheduledFor: pending.scheduledFor,
                outcome: .interrupted,
                mission: pending.mission.kind,
                difficulty: pending.mission.difficulty
            ))
        }

        if countAsDodge {
            pending.dodgeCount += 1
            log?.amendLatest(alarmID: alarmID) { $0.dodgeCount = pending.dodgeCount }
        }

        PendingMissionStore.save(pending)
        activeMission = pending
    }

    /// Arms a one-off alarm a minute (or a snooze) from now, under the same id. Reusing the
    /// id matters: a fresh id per dodge would leak an unbounded number of scheduled alarms
    /// into the system, and AlarmKit has a hard cap.
    private func armFollowUp(for alarmID: UUID, after delay: TimeInterval = AlarmBridge.relentlessDelay) async {
        guard let alarm = alarms?.alarm(id: alarmID) else { return }
        do {
            try await AlarmSystem.scheduleFollowUp(alarm, at: Date().addingTimeInterval(delay))
        } catch {
            lastFailure = Failure(messageKey: "error.scheduleFailed", detail: String(describing: error))
        }
    }

    // MARK: - Mission outcome

    /// The mission was cleared. Cancels the follow-up, closes the wake record, and puts the
    /// alarm back on its normal schedule.
    func missionCompleted(_ pending: PendingMission) async {
        let now = Date()
        log?.amendLatest(alarmID: pending.alarmID) { record in
            record.dismissedAt = now
            record.outcome = pending.snoozeCount > 0 ? .completedAfterSnoozes : .completed
            record.secondsToDismiss = now.timeIntervalSince(pending.startedAt)
            record.snoozeCount = pending.snoozeCount
            record.dodgeCount = pending.dodgeCount
        }

        PendingMissionStore.clear()
        activeMission = nil

        // Cancel first, then re-arm. A repeating alarm needs its recurrence put back,
        // because a dodge replaced it with a one-off follow-up.
        cancel(pending.alarmID)
        if let alarm = alarms?.alarm(id: pending.alarmID) {
            if alarm.isOneShot {
                alarms?.retireIfOneShot(id: alarm.id)
            } else {
                await schedule(alarm)
            }
        }
    }

    /// The escape hatch was used. Recorded honestly as a bail-out so the stats do not
    /// flatter the user, and the alarm is stood down rather than coming back.
    func missionAbandoned(_ pending: PendingMission) async {
        let now = Date()
        log?.amendLatest(alarmID: pending.alarmID) { record in
            record.dismissedAt = now
            record.outcome = .bailedOut
            record.snoozeCount = pending.snoozeCount
            record.dodgeCount = pending.dodgeCount
        }
        PendingMissionStore.clear()
        activeMission = nil

        cancel(pending.alarmID)
        if let alarm = alarms?.alarm(id: pending.alarmID) {
            if alarm.isOneShot {
                alarms?.retireIfOneShot(id: alarm.id)
            } else {
                await schedule(alarm)
            }
        }
    }

    /// Called at launch: a mission left pending by a killed app should resume, not vanish.
    func restorePendingMission() {
        activeMission = PendingMissionStore.loadIfFresh()
    }

    func clearFailure() { lastFailure = nil }
}

/// The three calls that cross into AlarmKit, deliberately outside the main actor.
///
/// `AlarmManager` is a non-`Sendable` class and `AlarmConfiguration` is a non-`Sendable`
/// struct, so under strict concurrency neither can be handed from `@MainActor` to an `async`
/// framework method: the compiler has no way to know AlarmKit is safe to touch from another
/// thread, and it is right to refuse. What crosses instead is the `AlarmDraft`, which is a
/// `Sendable` value, and what comes back is a `Sendable` `AuthorizationState` or a thrown
/// error. So the configuration is built here, on this side of the boundary, out of the draft.
///
/// This is the only file that names `AlarmManager`, and this is the only type in it that is
/// allowed to build a configuration, which keeps "what the system is told about an alarm" in
/// one readable place rather than split between a scheduling method and a follow-up method.
private enum AlarmSystem {

    static func requestAuthorization() async throws -> AlarmManager.AuthorizationState {
        try await AlarmManager.shared.requestAuthorization()
    }

    /// Arms the alarm on its own schedule. The returned `Alarm` is discarded on purpose: the
    /// app's record of the alarm is the `AlarmDraft` in its store, and keeping a second copy
    /// of the same alarm in a second shape is how the two drift apart.
    static func schedule(_ alarm: AlarmDraft) async throws {
        let metadata = MissionMetadata(alarm: alarm)

        // The secondary button is the mission. Its label names the mission rather than
        // saying "Open", so the lock screen tells the user what they are about to be asked
        // to do before they commit to pressing it.
        let presentation = AlarmPresentation(alert: alert(
            title: alarm.label.isEmpty
                ? LocalizedStringResource("alarm.defaultTitle", defaultValue: "Dawnbreak")
                : LocalizedStringResource(stringLiteral: alarm.label),
            for: alarm
        ))

        _ = try await AlarmManager.shared.schedule(
            id: alarm.id,
            configuration: AlarmManager.AlarmConfiguration(
                schedule: schedule(for: alarm),
                attributes: AlarmAttributes(presentation: presentation, metadata: metadata, tintColor: Theme.accent),
                stopIntent: StopAlarmIntent(alarmID: alarm.id),
                secondaryIntent: StartMissionIntent(alarmID: alarm.id),
                sound: tone(for: alarm)
            )
        )
    }

    /// Arms the same alarm as a one-off at `fireDate`, under the same id, with a title that
    /// says why it came back. Reusing the id matters: a fresh id per dodge would leak an
    /// unbounded number of scheduled alarms into the system, and AlarmKit has a hard cap.
    static func scheduleFollowUp(_ alarm: AlarmDraft, at fireDate: Date) async throws {
        let presentation = AlarmPresentation(alert: alert(
            title: LocalizedStringResource("alarm.followUpTitle", defaultValue: "Mission not done"),
            for: alarm
        ))

        _ = try await AlarmManager.shared.schedule(
            id: alarm.id,
            configuration: AlarmManager.AlarmConfiguration(
                schedule: .fixed(fireDate),
                attributes: AlarmAttributes(presentation: presentation, metadata: MissionMetadata(alarm: alarm), tintColor: Theme.accent),
                stopIntent: StopAlarmIntent(alarmID: alarm.id),
                secondaryIntent: StartMissionIntent(alarmID: alarm.id),
                sound: tone(for: alarm)
            )
        )
    }

    /// Builds the ringing alert's presentation across both AlarmKit spellings.
    ///
    /// iOS 26.1 removed `stopButton` from the initialiser: the system draws its own stop
    /// affordance and ignores anything passed. 26.0 still requires the argument. Branching
    /// here rather than raising the deployment target keeps the app on every iPhone that has
    /// AlarmKit at all, and the two call sites do not have to know about it.
    private static func alert(title: LocalizedStringResource, for alarm: AlarmDraft) -> AlarmPresentation.Alert {
        let secondaryButton = AlarmButton(
            text: LocalizedStringResource(stringLiteral: alarm.mission.kind.titleKey),
            textColor: .white,
            systemImageName: alarm.mission.kind.systemImage
        )

        if #available(iOS 26.1, *) {
            return AlarmPresentation.Alert(
                title: title,
                secondaryButton: secondaryButton,
                secondaryButtonBehavior: .custom
            )
        }
        return AlarmPresentation.Alert(
            title: title,
            stopButton: AlarmButton(
                text: LocalizedStringResource("alarm.stop", defaultValue: "Stop"),
                textColor: .white,
                systemImageName: "stop.fill"
            ),
            secondaryButton: secondaryButton,
            secondaryButtonBehavior: .custom
        )
    }

    /// The tone the system plays, named the way notification sounds are named.
    ///
    /// `AlertSound.named(_:)` is documented with the same sentence as
    /// `UNNotificationSound.soundNamed(_:)` ("a file that's in your app's main bundle or the
    /// Library/Sounds folder"), and that API takes the filename with its extension. If the
    /// name misses, the system rings its own default alarm sound rather than staying silent,
    /// which is the failure this app can survive; `AlarmAudio` keeps playing the same tone
    /// once the mission screen is up either way.
    private static func tone(for alarm: AlarmDraft) -> AlertConfiguration.AlertSound {
        .named("\(alarm.soundName).caf")
    }

    private static func schedule(for alarm: AlarmDraft) -> Alarm.Schedule {
        let time = Alarm.Schedule.Relative.Time(hour: alarm.hour, minute: alarm.minute)
        let recurrence: Alarm.Schedule.Relative.Recurrence = alarm.repeatDays.isEmpty
            ? .never
            // `Locale.Weekday` is AlarmKit's vocabulary; our `Weekday` is the stored one.
            : .weekly(alarm.repeatDays.sorted().map(\.localeWeekday))
        return .relative(.init(time: time, repeats: recurrence))
    }
}

private extension Weekday {
    /// Our stored weekday, in AlarmKit's vocabulary.
    var localeWeekday: Locale.Weekday {
        switch self {
        case .monday: .monday
        case .tuesday: .tuesday
        case .wednesday: .wednesday
        case .thursday: .thursday
        case .friday: .friday
        case .saturday: .saturday
        case .sunday: .sunday
        }
    }
}
