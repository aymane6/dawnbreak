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
    /// The ids the system actually holds, which is not the same thing as the ids in the store.
    /// The list marks an enabled alarm that is missing from here, because an alarm the app
    /// draws and the system has never heard of is the worst bug this app can have.
    private(set) var armedIDs: Set<UUID> = []

    /// Attached by the app at launch so the bridge reads the same store the screens do.
    ///
    /// Not optional at the point of use, and that is deliberate. An App Intent reaches this
    /// object from the lock screen, and nothing guarantees the SwiftUI app has been built by
    /// then: a stop that arrived first found no store, gave up, and took the alarm's only
    /// chance of coming back with it. So an unattached bridge opens the store itself, on the
    /// same directory the app uses, and the app's own instance replaces it a moment later.
    private var attachedAlarms: AlarmStore?
    private var attachedLog: WakeLogStore?

    private var alarms: AlarmStore {
        if let attachedAlarms { return attachedAlarms }
        let store = AlarmStore(directory: StoreLocation.supportDirectory())
        attachedAlarms = store
        return store
    }

    private var log: WakeLogStore {
        if let attachedLog { return attachedLog }
        let store = WakeLogStore(directory: StoreLocation.supportDirectory())
        attachedLog = store
        return store
    }

    /// Injected so the order these calls have to be made in is provable without an iPhone;
    /// see `AlarmScheduler`. The app always uses the real one.
    private let system: AlarmScheduler
    private var authorizationTask: Task<Void, Never>?
    private var armedTask: Task<Void, Never>?

    struct Failure: Identifiable, Hashable {
        let id = UUID()
        var messageKey: String
        var detail: String
    }

    /// How long after a dodged mission the alarm comes back. Short enough that going back
    /// to sleep does not work, long enough that the phone is not unusable.
    static let relentlessDelay: TimeInterval = 60

    /// "Straight away", for leaving the mission screen without finishing it. Not zero, and not
    /// one: AlarmKit refuses a fixed date in the past, and the few hundred milliseconds between
    /// building the date and the daemon accepting it are enough to make one second the past.
    /// Five is the smallest delay that is reliably still in the future and still reads as
    /// immediate to someone standing there.
    static let immediateDelay: TimeInterval = 5

    /// How long a mission actually being worked on buys, pushed out again on every round
    /// cleared. The rule the app owes the user is "the alarm comes back if the mission is not
    /// being done", and someone halfway through the second of three sums is doing it: ringing
    /// over them would punish the exact behaviour the alarm is for. Long enough not to
    /// interrupt a hard mission, short enough that a phone put down mid-mission rings again
    /// within three minutes.
    ///
    /// It is a push, never a cancel. An alarm is armed at every instant from the moment stop is
    /// pressed until the mission is cleared, because the alternative — cancelling for the
    /// duration of the mission — loses the morning outright if the app is killed while the
    /// screen is up, and killing the app is the first thing anyone tries.
    static let missionEngagedDelay: TimeInterval = 180

    init(system: AlarmScheduler = AlarmSystem()) {
        self.system = system
        authorization = system.authorizationState
        armedIDs = system.scheduledIDs()
    }

    func attach(alarms: AlarmStore, log: WakeLogStore) {
        attachedAlarms = alarms
        attachedLog = log
        observeAuthorization()
        observeArmed()
    }

    // MARK: - Authorization

    /// Requested at the moment the user arms their first alarm, not at launch. Asking for
    /// the right to interrupt someone's Focus mode before they have set an alarm earns a
    /// "no", and a denied AlarmKit permission makes the app pointless.
    @discardableResult
    func requestAuthorization() async -> AlarmManager.AuthorizationState {
        do {
            let state = try await system.requestAuthorization()
            authorization = state
            return state
        } catch {
            lastFailure = Failure(messageKey: "error.authorizationFailed", detail: String(describing: error))
            return system.authorizationState
        }
    }

    /// Also called by onboarding, whose permission page has to redraw the instant the system
    /// alert is answered — including when it is answered in Settings, with the app suspended.
    func observeAuthorization() {
        authorizationTask?.cancel()
        authorizationTask = Task { [weak self] in
            guard let self else { return }
            for await state in system.authorizationUpdates() {
                await MainActor.run { self.authorization = state }
            }
        }
    }

    /// Follows what the system holds, which changes without the app asking: a repeating alarm
    /// is re-armed after it fires, a one-off is dropped, and either way the list has to stop
    /// promising a ring the system is no longer going to make.
    func observeArmed() {
        armedTask?.cancel()
        armedTask = Task { [weak self] in
            guard let self else { return }
            for await ids in system.armedUpdates() {
                await MainActor.run { self.armedIDs = ids }
            }
        }
    }

    // MARK: - Scheduling

    /// Arms an alarm, replacing any previously scheduled version of it.
    ///
    /// Called on every edit and on every toggle, and the cancel is not optional. AlarmKit
    /// refuses an id it already holds: its daemon logs "Not scheduling an alarm with a
    /// duplicate ID" and the call throws. Scheduling on top of an existing alarm is therefore
    /// not an update, and the failure it produces is the quietest possible kind — the store
    /// keeps the edit, the system keeps the alarm it already had, and the app goes on drawing
    /// a time nothing is going to ring at. So every arm is a cancel and a schedule, in that
    /// order, whether or not the system is thought to know the id.
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

        system.cancel(id: alarm.id)
        do {
            try await system.schedule(alarm)
            lastFailure = nil
        } catch AlarmManager.AlarmError.maximumLimitReached {
            lastFailure = Failure(messageKey: "error.tooManyAlarms", detail: "")
        } catch {
            lastFailure = Failure(messageKey: "error.scheduleFailed", detail: String(describing: error))
        }
        armedIDs = system.scheduledIDs()
    }

    func cancel(_ id: UUID) {
        // A cancel for an alarm the system does not know about throws, and that is fine:
        // the desired end state is "not scheduled", which is already true.
        system.cancel(id: id)
        armedIDs = system.scheduledIDs()
    }

    /// Re-arms every enabled alarm. Run at launch, because an app update or a restore from
    /// backup leaves the store full of alarms the system has never been told about.
    func reconcile() async {
        // A mission still owed is not reconciled away. Its alarm is armed as a one-off
        // follow-up, so the store would look "not armed on its normal schedule" and the loop
        // below would replace the follow-up with tomorrow's alarm — cancelling the one ring
        // that was going to make the user get up.
        let owed = PendingMissionStore.loadIfFresh()?.alarmID
        let scheduled = system.scheduledIDs()
        for alarm in alarms.alarms where alarm.isEnabled && !scheduled.contains(alarm.id) && alarm.id != owed {
            await schedule(alarm)
        }
        // The reverse direction too: an alarm switched off while the app was closed.
        for id in scheduled where id != owed && alarms.alarm(id: id)?.isEnabled != true {
            cancel(id)
        }
    }

    // MARK: - Intent handling

    /// The alert's stop affordance was pressed.
    ///
    /// The alarm is now silent: the system did that before this ran, and no API can prevent it.
    /// AlarmKit always draws a stop affordance and there is no way to remove one. So the promise
    /// that the alarm cannot be dismissed without doing the mission is kept by what happens
    /// next, in this order:
    ///
    /// 1. The alarm is re-armed, a minute out. This first, and unconditionally, because it is
    ///    the half that works with the app in the background, killed, or never brought to the
    ///    front at all. Everything after it is presentation.
    /// 2. The mission is opened.
    ///
    /// It used to be the other way round, and every failure in step 2 silently cancelled step 1:
    /// the mission screen did not open *and* the alarm never came back, which is a stop button
    /// that works. That is the bug this ordering exists to make impossible.
    func handleStopPressed(alarmID: UUID) async {
        let pending = beginMission(alarmID: alarmID, countAsDodge: true)
        guard let pending, pending.relentless else { return }
        await armFollowUp(pending, after: Self.relentlessDelay)
    }

    /// The mission button was pressed. Same destination, but this is not a dodge.
    ///
    /// The follow-up is armed here too. Reaching the mission screen is not the same as clearing
    /// it: the user can walk away from it, and the phone can die. Only `missionCompleted` calls
    /// the morning done.
    func handleMissionRequested(alarmID: UUID) async {
        let pending = beginMission(alarmID: alarmID, countAsDodge: false)
        guard let pending, pending.relentless else { return }
        await armFollowUp(pending, after: Self.relentlessDelay)
    }

    func handleSnoozePressed(alarmID: UUID) async {
        guard var pending = beginMission(alarmID: alarmID, countAsDodge: false) else { return }
        guard pending.canSnooze else { return }
        pending.snoozeCount += 1
        PendingMissionStore.save(pending)
        activeMission = pending
        log.amendLatest(alarmID: alarmID) { $0.snoozeCount = pending.snoozeCount }
        await armFollowUp(pending, after: TimeInterval(pending.snooze.minutes * 60))
    }

    /// The mission screen was left with the mission still owed, or the app was killed while it
    /// was up. Brings the alarm straight back, which is the whole point of the screen being hard
    /// to leave: walking away from it is not a way out.
    func missionLeftUnfinished() async {
        guard let pending = activeMission ?? PendingMissionStore.loadIfFresh() else { return }
        await armFollowUp(pending, after: Self.immediateDelay)
    }

    /// The mission is on screen and being worked on: the round just cleared, or the screen just
    /// opened. Pushes the follow-up out rather than cancelling it, so the alarm does not ring
    /// over someone who is doing exactly what it asked.
    func missionInProgress() async {
        guard let pending = activeMission else { return }
        await armFollowUp(pending, after: Self.missionEngagedDelay)
    }

    /// Establishes what is owed for an alarm and puts the mission on screen.
    ///
    /// Returns the mission so the caller can act on it without reading `activeMission` back —
    /// that indirection is what made a failure here also skip the re-arm.
    ///
    /// Not `async`, and nothing in it can fail into a nil return except an id that is genuinely
    /// unknown: no alarm in the store, and no fresh handoff on disk either. A missing store
    /// entry alone is not enough to give up, because the record on disk holds everything the
    /// mission and the follow-up need.
    @discardableResult
    private func beginMission(alarmID: UUID, countAsDodge: Bool) -> PendingMission? {
        let stored = alarms.alarm(id: alarmID)
        let onDisk = PendingMissionStore.loadIfFresh().flatMap { $0.alarmID == alarmID ? $0 : nil }

        var pending: PendingMission
        if let onDisk {
            pending = onDisk
        } else if let stored {
            pending = PendingMission(alarm: stored, scheduledFor: stored.nextFireDate(after: Date().addingTimeInterval(-86_400)) ?? Date())
            // First sighting of this morning's alarm: open the wake record now, so a phone
            // that dies mid-mission still leaves evidence the alarm rang.
            log.append(WakeRecord(
                alarmID: alarmID,
                scheduledFor: pending.scheduledFor,
                outcome: .interrupted,
                mission: pending.mission.kind,
                difficulty: pending.mission.difficulty
            ))
        } else {
            // Genuinely nothing to demand: the alarm was deleted between ringing and the button
            // being pressed, and no handoff was ever written. Clear rather than open an empty
            // mission screen.
            PendingMissionStore.clear()
            activeMission = nil
            return nil
        }

        if countAsDodge {
            pending.dodgeCount += 1
            log.amendLatest(alarmID: alarmID) { $0.dodgeCount = pending.dodgeCount }
        }

        PendingMissionStore.save(pending)
        activeMission = pending
        return pending
    }

    /// Arms a one-off alarm `delay` from now, under the same id.
    ///
    /// Built from the pending mission rather than from the store, so a deleted alarm or an
    /// unreadable store cannot be the reason the alarm fails to come back. Reusing the id
    /// matters: a fresh id per dodge would leak an unbounded number of scheduled alarms into
    /// the system, and AlarmKit has a hard cap.
    private func armFollowUp(_ pending: PendingMission, after delay: TimeInterval) async {
        // Same duplicate-id refusal as `schedule`, and it bites hardest here: a repeating alarm
        // is put back by the system the moment it stops ringing, so the id is always taken by
        // the time a dodge tries to reuse it, and the follow-up would never arm. This is the
        // line whose absence meant a stopped alarm never rang again.
        system.cancel(id: pending.alarmID)
        do {
            try await system.scheduleFollowUp(pending.followUpDraft(), at: Date().addingTimeInterval(delay))
        } catch {
            // Named, because this failure is invisible otherwise: the alarm is already silent,
            // the mission screen is up, and the only symptom is a morning that never rings
            // again. A dialog naming the stage is what makes the next report diagnosable.
            lastFailure = Failure(messageKey: "error.scheduleFailed", detail: "follow-up: \(error)")
        }
        armedIDs = system.scheduledIDs()
    }

    // MARK: - Mission outcome

    /// The mission was cleared. Cancels the follow-up, closes the wake record, and puts the
    /// alarm back on its normal schedule.
    func missionCompleted(_ pending: PendingMission) async {
        let now = Date()
        log.amendLatest(alarmID: pending.alarmID) { record in
            record.dismissedAt = now
            record.outcome = pending.snoozeCount > 0 ? .completedAfterSnoozes : .completed
            record.secondsToDismiss = now.timeIntervalSince(pending.startedAt)
            record.snoozeCount = pending.snoozeCount
            record.dodgeCount = pending.dodgeCount
        }

        // Cleared before the alarm is stood down, and in this order on purpose: the mission
        // screen watches `activeMission`, and its disappearance is what would otherwise be read
        // as "left unfinished" and arm another follow-up five seconds later.
        PendingMissionStore.clear()
        activeMission = nil

        // Cancel first, then re-arm. A repeating alarm needs its recurrence put back,
        // because a dodge replaced it with a one-off follow-up.
        cancel(pending.alarmID)
        if let alarm = alarms.alarm(id: pending.alarmID) {
            if alarm.isOneShot {
                alarms.retireIfOneShot(id: alarm.id)
            } else {
                await schedule(alarm)
            }
        }
    }

    /// The escape hatch was used. Recorded honestly as a bail-out so the stats do not
    /// flatter the user, and the alarm is stood down rather than coming back.
    func missionAbandoned(_ pending: PendingMission) async {
        let now = Date()
        log.amendLatest(alarmID: pending.alarmID) { record in
            record.dismissedAt = now
            record.outcome = .bailedOut
            record.snoozeCount = pending.snoozeCount
            record.dodgeCount = pending.dodgeCount
        }
        PendingMissionStore.clear()
        activeMission = nil

        cancel(pending.alarmID)
        if let alarm = alarms.alarm(id: pending.alarmID) {
            if alarm.isOneShot {
                alarms.retireIfOneShot(id: alarm.id)
            } else {
                await schedule(alarm)
            }
        }
    }

    /// Called at launch and on every return to the foreground: a mission left pending by a
    /// killed app should resume, not vanish.
    ///
    /// Returns whether this is the first time this process has seen it. The app uses that to
    /// bring the alarm straight back: an app killed with the mission screen up is the one exit
    /// the screen itself cannot notice, and it is also the most obvious way to defeat the app.
    @discardableResult
    func restorePendingMission() -> Bool {
        let restored = PendingMissionStore.loadIfFresh()
        // "First sighting in this process", not "different from last time": the app is asked to
        // restore on every return to the foreground, and a user who glanced at Control Center
        // mid-mission has not escaped anything. Only a launch that finds a mission already owed
        // means the screen went away without the mission being settled.
        let isNew = restored != nil && activeMission == nil
        activeMission = restored
        return isNew
    }

    func clearFailure() { lastFailure = nil }
}

/// Everything the bridge asks of AlarmKit, behind a protocol.
///
/// It exists for one reason: the order of `cancel` and `schedule` is load-bearing, AlarmKit
/// refuses a duplicate id, and neither fact can be tested against the real framework — a unit
/// test cannot answer the system's permission alert, and an iPhone is not in the loop. So the
/// order is provable against a double instead, and `AlarmSchedulingTests` is what would have
/// caught this.
///
/// `Sendable` and nonisolated throughout, because the implementation has to be: see
/// `AlarmSystem`.
protocol AlarmScheduler: Sendable {
    var authorizationState: AlarmManager.AuthorizationState { get }
    func requestAuthorization() async throws -> AlarmManager.AuthorizationState
    func authorizationUpdates() -> AsyncStream<AlarmManager.AuthorizationState>

    /// The ids the system holds right now, empty if it cannot be asked.
    func scheduledIDs() -> Set<UUID>
    func armedUpdates() -> AsyncStream<Set<UUID>>
    /// Silent when there is nothing to cancel: the caller wants the end state, not the call.
    func cancel(id: UUID)
    func schedule(_ alarm: AlarmDraft) async throws
    func scheduleFollowUp(_ alarm: AlarmDraft, at fireDate: Date) async throws
}

/// The calls that cross into AlarmKit, deliberately outside the main actor.
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
struct AlarmSystem: AlarmScheduler {

    var authorizationState: AlarmManager.AuthorizationState {
        AlarmManager.shared.authorizationState
    }

    func requestAuthorization() async throws -> AlarmManager.AuthorizationState {
        try await AlarmManager.shared.requestAuthorization()
    }

    func authorizationUpdates() -> AsyncStream<AlarmManager.AuthorizationState> {
        stream { AlarmManager.shared.authorizationUpdates }
    }

    /// `alarms` throws when the daemon cannot be reached, and an unreachable daemon holds
    /// nothing this app can rely on, so that reads as "none armed" rather than as a crash.
    func scheduledIDs() -> Set<UUID> {
        Set(((try? AlarmManager.shared.alarms) ?? []).map(\.id))
    }

    func armedUpdates() -> AsyncStream<Set<UUID>> {
        stream { AlarmManager.shared.alarmUpdates.map { Set($0.map(\.id)) } }
    }

    func cancel(id: UUID) {
        try? AlarmManager.shared.cancel(id: id)
    }

    /// AlarmKit's update sequences are opaque types, which cannot be named in a protocol.
    /// Republished as an `AsyncStream`, which can, and which a double can also produce.
    private func stream<Source: AsyncSequence<Element, Never>, Element: Sendable>(
        _ source: @Sendable @escaping () -> Source
    ) -> AsyncStream<Element> {
        AsyncStream { continuation in
            let task = Task {
                for await value in source() { continuation.yield(value) }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Arms the alarm on its own schedule. The returned `Alarm` is discarded on purpose: the
    /// app's record of the alarm is the `AlarmDraft` in its store, and keeping a second copy
    /// of the same alarm in a second shape is how the two drift apart.
    func schedule(_ alarm: AlarmDraft) async throws {
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
    func scheduleFollowUp(_ alarm: AlarmDraft, at fireDate: Date) async throws {
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
    private func alert(title: LocalizedStringResource, for alarm: AlarmDraft) -> AlarmPresentation.Alert {
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
    private func tone(for alarm: AlarmDraft) -> AlertConfiguration.AlertSound {
        .named("\(alarm.soundName).caf")
    }

    private func schedule(for alarm: AlarmDraft) -> Alarm.Schedule {
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
