import AlarmKit
import DawnbreakKit
import Foundation
import Synchronization
import Testing
@testable import Dawnbreak

/// AlarmKit, as far as `AlarmBridge` can tell, with the one behaviour that matters kept faithful:
/// the real framework refuses an id it already holds. Its daemon says so in as many words,
/// "Not scheduling an alarm with a duplicate ID", and the call throws. Nothing about that is
/// visible from the API, where `schedule(id:configuration:)` reads exactly like an upsert, and the
/// error it raises is an internal case that the app can only ever see as "some other error".
///
/// So an edit is a cancel and a schedule. That is what this double is for: the ordering is the
/// whole fix, and it cannot be proved against the framework itself — a unit test cannot answer the
/// system's permission alert, and the alarm daemon is not in the simulator's gift.
final class FakeAlarmSystem: AlarmScheduler {

    enum Call: Equatable {
        case cancel(UUID)
        case schedule(UUID)
        case followUp(UUID)
    }

    /// The duplicate-id refusal, in shape rather than in type.
    struct DuplicateID: Error {}

    private struct Log: Sendable {
        var calls: [Call] = []
        var armed: Set<UUID> = []
        /// The subset of `armed` the fake reports as ringing right now.
        var alerting: Set<UUID> = []
        /// Whether `snapshot()` answers at all. False plays the daemon being unreachable,
        /// which the bridge must treat as "no information", not as "nothing armed".
        var reachable = true
        /// How many more scheduling calls throw `refusal` before the fake starts accepting.
        /// `.max` refuses forever; 1 plays the daemon rejecting a fire date that slipped
        /// into the past, which a retry with a fresh date survives.
        var refusalsLeft = 0
        /// When each follow-up was asked to fire, in order. How long after a dodge the alarm
        /// comes back is a product decision, so it is asserted rather than assumed.
        var followUpDates: [Date] = []
    }

    let authorizationState: AlarmManager.AuthorizationState
    /// Thrown instead of arming anything, for the paths that only exist to report a refusal.
    private let refusal: (any Error)?
    private let log = Mutex(Log())

    init(
        authorization: AlarmManager.AuthorizationState = .authorized,
        refusal: (any Error)? = nil,
        refusalLimit: Int = .max
    ) {
        self.authorizationState = authorization
        self.refusal = refusal
        if refusal != nil {
            log.withLock { $0.refusalsLeft = refusalLimit }
        }
    }

    /// Marks an armed alarm as ringing, for the resolution fallbacks.
    func startAlerting(_ id: UUID) {
        log.withLock { _ = $0.alerting.insert(id) }
    }

    /// Plays the daemon being unreachable from here on.
    func becomeUnreachable() {
        log.withLock { $0.reachable = false }
    }

    var calls: [Call] { log.withLock { $0.calls } }
    var followUpDates: [Date] { log.withLock { $0.followUpDates } }

    /// How far out the last follow-up was armed, rounded to the second. The bridge builds its
    /// fire date from `Date()`, so the test compares an interval rather than an instant.
    var lastFollowUpDelay: TimeInterval? {
        guard let date = followUpDates.last else { return nil }
        return (date.timeIntervalSinceNow).rounded()
    }

    func requestAuthorization() async throws -> AlarmManager.AuthorizationState { authorizationState }

    func authorizationUpdates() -> AsyncStream<AlarmManager.AuthorizationState> {
        AsyncStream { $0.finish() }
    }

    func armedUpdates() -> AsyncStream<Set<UUID>> {
        AsyncStream { $0.finish() }
    }

    func snapshot() -> AlarmSnapshot? {
        log.withLock {
            $0.reachable ? AlarmSnapshot(scheduled: $0.armed, alerting: $0.alerting) : nil
        }
    }

    func cancel(id: UUID) {
        log.withLock {
            $0.calls.append(.cancel(id))
            $0.armed.remove(id)
            $0.alerting.remove(id)
        }
    }

    func schedule(_ alarm: AlarmDraft) async throws {
        try arm(alarm.id, as: .schedule(alarm.id))
    }

    func scheduleFollowUp(_ alarm: AlarmDraft, at fireDate: Date) async throws {
        log.withLock { $0.followUpDates.append(fireDate) }
        try arm(alarm.id, as: .followUp(alarm.id))
    }

    private func arm(_ id: UUID, as call: Call) throws {
        let (taken, refusing) = log.withLock {
            $0.calls.append(call)
            let refusing = $0.refusalsLeft > 0
            if refusing { $0.refusalsLeft -= 1 }
            return ($0.armed.contains(id), refusing)
        }
        if refusing, let refusal { throw refusal }
        // The refusal this whole file exists for, and it comes after the call is recorded
        // because the real one is recorded by the daemon too, in its log, as a rejection.
        if taken { throw DuplicateID() }
        log.withLock { _ = $0.armed.insert(id) }
    }
}

/// The bug this suite was written for: an alarm was set, then edited, and the edit was refused
/// with "iOS refused to schedule this alarm". The store kept the edit, the system kept the alarm
/// it already had, the list went on drawing the new time, and nothing rang at either one.
@MainActor
@Suite("Alarm scheduling")
struct AlarmSchedulingTests {

    private static func draft(hour: Int = 7, minute: Int = 0) -> AlarmDraft {
        AlarmDraft(hour: hour, minute: minute, mission: .default)
    }

    @Test("An edit cancels before it schedules, so the id is free when the new alarm is armed")
    func editCancelsFirst() async {
        let system = FakeAlarmSystem()
        let bridge = AlarmBridge(system: system)
        var alarm = Self.draft(hour: 6, minute: 15)

        await bridge.schedule(alarm)
        alarm.minute = 45
        await bridge.schedule(alarm)

        #expect(system.calls == [
            .cancel(alarm.id), .schedule(alarm.id),
            .cancel(alarm.id), .schedule(alarm.id),
        ])
        #expect(bridge.lastFailure == nil)
        #expect(bridge.armedIDs == [alarm.id])
    }

    @Test("Editing an alarm three times over leaves it armed every time")
    func repeatedEditsStayArmed() async {
        let system = FakeAlarmSystem()
        let bridge = AlarmBridge(system: system)
        var alarm = Self.draft()

        for minute in [0, 15, 30, 45] {
            alarm.minute = minute
            await bridge.schedule(alarm)
            #expect(bridge.lastFailure == nil)
            #expect(bridge.armedIDs == [alarm.id], "the edit to :\(minute) left nothing armed")
        }
    }

    @Test("Switching an alarm off cancels it and arms nothing")
    func disablingCancels() async {
        let system = FakeAlarmSystem()
        let bridge = AlarmBridge(system: system)
        var alarm = Self.draft()

        await bridge.schedule(alarm)
        alarm.isEnabled = false
        await bridge.schedule(alarm)

        #expect(system.calls.filter { $0 == .schedule(alarm.id) }.count == 1)
        #expect(bridge.armedIDs.isEmpty)
    }

    @Test("A refusal is reported with the framework's own words attached")
    func refusalCarriesItsReason() async {
        struct Unlucky: Error {}
        let bridge = AlarmBridge(system: FakeAlarmSystem(refusal: Unlucky()))

        await bridge.schedule(Self.draft())

        #expect(bridge.lastFailure?.messageKey == "error.scheduleFailed")
        // Cryptic, and the point: the dialog now shows this, so the next report of a refused
        // alarm names the reason instead of only the symptom.
        #expect(bridge.lastFailure?.detail.contains("Unlucky") == true)
        #expect(bridge.armedIDs.isEmpty)
    }

    @Test("The one refusal AlarmKit spells out gets its own message")
    func alarmLimitHasItsOwnMessage() async {
        let bridge = AlarmBridge(system: FakeAlarmSystem(refusal: AlarmManager.AlarmError.maximumLimitReached))

        await bridge.schedule(Self.draft())

        #expect(bridge.lastFailure?.messageKey == "error.tooManyAlarms")
    }

    @Test("A denied permission is not reported as a scheduling failure")
    func deniedPermissionSaysSo() async {
        let system = FakeAlarmSystem(authorization: .denied)
        let bridge = AlarmBridge(system: system)

        await bridge.schedule(Self.draft())

        #expect(bridge.lastFailure?.messageKey == "error.alarmPermissionDenied")
        #expect(system.calls.isEmpty)
    }

    @Test("A mission that still needs setup is refused before the system is asked")
    func incompleteMissionNeverReachesTheSystem() async {
        let system = FakeAlarmSystem()
        let bridge = AlarmBridge(system: system)
        let alarm = AlarmDraft(mission: MissionConfig(kind: .photo))

        await bridge.schedule(alarm)

        #expect(bridge.lastFailure?.messageKey == "error.missionNeedsSetup")
        #expect(system.calls.isEmpty)
    }
}
