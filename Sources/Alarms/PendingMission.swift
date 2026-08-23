import DawnbreakKit
import Foundation

/// The handoff between the ringing alarm and the mission screen.
///
/// An App Intent fired from the lock screen and the app's UI are not guaranteed to be the
/// same process, and even when they are, the app may be cold-launched by the intent. So the
/// "which alarm is ringing and what does it demand" question is answered by a file in the
/// shared container rather than by memory: whoever wakes up first writes it, whoever draws
/// the screen reads it.
struct PendingMission: Codable, Hashable, Sendable {
    var alarmID: UUID
    /// When the alarm was scheduled to ring. Used for the wake record, and for the
    /// "you took 3 min" line, so it must be the scheduled instant rather than `Date()` at
    /// the moment the intent happened to run.
    var scheduledFor: Date
    /// When the alert actually appeared. `Date()` at intent time.
    var startedAt: Date
    var mission: MissionConfig
    var label: String
    var soundName: String
    var volume: Double
    var vibrate: Bool
    var snooze: AlarmDraft.SnoozePolicy
    var relentless: Bool
    /// Bumped every time the user snoozes, so the mission screen can hide the button once
    /// the allowance is spent.
    var snoozeCount: Int = 0
    /// Bumped every time the alert is dismissed without the mission being cleared.
    var dodgeCount: Int = 0
    /// Which demand of the morning this is: 0 is the alarm's own mission, 1… are the
    /// follow-ons. Carried with the whole chain, because the alarm may be deleted or the
    /// store unreadable between stages and the next demand still has to be knowable.
    var stage: Int = 0
    var followOns: [FollowOnMission] = []
    /// Set on a stage that is scheduled but not yet due: the previous mission was cleared
    /// and the alarm will ring again at about this instant. Until then this record must not
    /// open the mission screen — it exists so the ring's intent finds the right stage, not
    /// so the user meets mission two while putting the phone down after mission one.
    var notBefore: Date?

    init(alarm: AlarmDraft, scheduledFor: Date, startedAt: Date = Date()) {
        self.alarmID = alarm.id
        self.scheduledFor = scheduledFor
        self.startedAt = startedAt
        self.mission = alarm.mission
        self.label = alarm.label
        self.soundName = alarm.soundName
        self.volume = alarm.volume
        self.vibrate = alarm.vibrate
        self.snooze = alarm.snooze
        self.relentless = alarm.relentless
        self.followOns = alarm.followOns
    }

    /// Decoding is by hand for the fields added after the first TestFlight build, so a
    /// mission owed across an app update is not dropped by a missing key.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        alarmID = try c.decode(UUID.self, forKey: .alarmID)
        scheduledFor = try c.decode(Date.self, forKey: .scheduledFor)
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        mission = try c.decode(MissionConfig.self, forKey: .mission)
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        soundName = try c.decodeIfPresent(String.self, forKey: .soundName) ?? AlarmSound.default.rawValue
        volume = try c.decodeIfPresent(Double.self, forKey: .volume) ?? 0.9
        vibrate = try c.decodeIfPresent(Bool.self, forKey: .vibrate) ?? true
        snooze = try c.decodeIfPresent(AlarmDraft.SnoozePolicy.self, forKey: .snooze) ?? AlarmDraft.SnoozePolicy()
        relentless = try c.decodeIfPresent(Bool.self, forKey: .relentless) ?? true
        snoozeCount = try c.decodeIfPresent(Int.self, forKey: .snoozeCount) ?? 0
        dodgeCount = try c.decodeIfPresent(Int.self, forKey: .dodgeCount) ?? 0
        stage = try c.decodeIfPresent(Int.self, forKey: .stage) ?? 0
        followOns = try c.decodeIfPresent([FollowOnMission].self, forKey: .followOns) ?? []
        notBefore = try c.decodeIfPresent(Date.self, forKey: .notBefore)
    }

    // MARK: - The chain

    /// How many missions this morning demands in total.
    var totalStages: Int { 1 + followOns.count }

    /// The follow-on that comes after this stage, or nil when this is the last demand.
    var upNext: FollowOnMission? {
        followOns.indices.contains(stage) ? followOns[stage] : nil
    }

    /// The record for the next stage, owed from `fireDate`. Everything resets except the
    /// morning's identity and its history: the wake record keeps counting from the first
    /// ring, so the dodge and snooze tallies ride along.
    func nextStage(ringingAt fireDate: Date) -> PendingMission? {
        guard let followOn = upNext else { return nil }
        var next = self
        next.mission = followOn.mission
        next.stage = stage + 1
        next.scheduledFor = fireDate
        next.startedAt = fireDate
        next.notBefore = fireDate.addingTimeInterval(-Self.dueMargin)
        return next
    }

    /// How early a scheduled stage counts as due. The daemon rings at the instant it was
    /// given; opening the mission to someone who opens the app a moment before that is
    /// better than a ring whose intent finds a record that claims it is not due yet.
    static let dueMargin: TimeInterval = 60

    var canSnooze: Bool {
        guard snooze.isAllowed else { return false }
        guard let maximum = snooze.maxCount else { return true }
        return snoozeCount < maximum
    }

    var snoozesLeft: Int? {
        guard let maximum = snooze.maxCount else { return nil }
        return max(0, maximum - snoozeCount)
    }

    /// The alarm to re-arm with, rebuilt from this record rather than looked up.
    ///
    /// The follow-up has to happen even when the store cannot answer for the id — the alarm was
    /// deleted, the app was cold-launched by the intent and the store is still loading, the file
    /// is unreadable. Every one of those used to end with the alarm never coming back, which is
    /// the one outcome this app cannot have: a stop that succeeds is a morning lost.
    ///
    /// Everything the follow-up needs is here, because it is armed as a one-off at a fixed
    /// instant: the id, the sound, the mission that names the button, and the label. `hour` and
    /// `minute` are carried for completeness and are not read — `.fixed(_:)` ignores them.
    func followUpDraft() -> AlarmDraft {
        AlarmDraft(
            id: alarmID,
            hour: Calendar.current.component(.hour, from: scheduledFor),
            minute: Calendar.current.component(.minute, from: scheduledFor),
            label: label,
            mission: mission,
            soundName: soundName,
            volume: volume,
            vibrate: vibrate,
            snooze: snooze,
            relentless: relentless
        )
    }
}

/// Reads and writes the pending mission. Free functions on a namespace rather than a class:
/// this is touched from an App Intent, from the app, and potentially from the widget
/// extension, and none of them should own an instance the others cannot see.
enum PendingMissionStore {
    private static var url: URL {
        StoreLocation.supportDirectory().appendingPathComponent("pending-mission.json")
    }

    private static var file: JSONFileStore<PendingMission?> {
        JSONFileStore(url: url, fallback: { nil })
    }

    static func load() -> PendingMission? { file.load() }

    static func save(_ mission: PendingMission) {
        try? file.save(mission)
    }

    /// Cleared once the mission is settled, so a relaunch hours later does not reopen a
    /// mission screen for an alarm that rang this morning.
    static func clear() {
        try? FileManager.default.removeItem(at: url)
    }

    /// A pending mission older than this is stale: the phone was off, or the app was never
    /// opened. Reopening a mission screen for it would be baffling, so it is discarded.
    static let staleAfter: TimeInterval = 2 * 60 * 60

    /// The mission owed right now: fresh, and past its `notBefore` if it has one. This is
    /// what opens the mission screen and what the ring's intent acts on.
    static func loadIfFresh(now: Date = Date()) -> PendingMission? {
        guard let mission = loadUpcoming(now: now) else { return nil }
        if let notBefore = mission.notBefore, now < notBefore { return nil }
        return mission
    }

    /// The mission owed now *or scheduled for later*: a chained stage waiting for its ring.
    /// Reconciliation reads this one — the waiting stage's follow-up is armed under the
    /// alarm's id, and re-arming the alarm on its normal schedule would replace the ring
    /// that continues the morning with one tomorrow.
    static func loadUpcoming(now: Date = Date()) -> PendingMission? {
        guard let mission = load() else { return nil }
        // Staleness is measured from when the stage becomes due, not from when it was
        // written: a stage scheduled forty minutes out is not forty minutes old.
        let reference = mission.notBefore.map { max($0, mission.startedAt) } ?? mission.startedAt
        guard now.timeIntervalSince(reference) < staleAfter else {
            clear()
            return nil
        }
        return mission
    }
}
