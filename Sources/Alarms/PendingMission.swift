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
    }

    var canSnooze: Bool {
        guard snooze.isAllowed else { return false }
        guard let maximum = snooze.maxCount else { return true }
        return snoozeCount < maximum
    }

    var snoozesLeft: Int? {
        guard let maximum = snooze.maxCount else { return nil }
        return max(0, maximum - snoozeCount)
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

    static func loadIfFresh(now: Date = Date()) -> PendingMission? {
        guard let mission = load() else { return nil }
        guard now.timeIntervalSince(mission.startedAt) < staleAfter else {
            clear()
            return nil
        }
        return mission
    }
}
