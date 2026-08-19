import Foundation

/// One alarm event, written when the mission is cleared or abandoned. This is the whole
/// data set behind the stats screen, and it never leaves the device.
public struct WakeRecord: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var alarmID: UUID
    /// When the alarm was supposed to ring.
    public var scheduledFor: Date
    /// When the mission was actually cleared. `nil` when it was never cleared.
    public var dismissedAt: Date?
    public var outcome: Outcome
    public var mission: MissionKind
    public var difficulty: Difficulty
    /// Seconds from the alarm ringing to the mission being cleared.
    public var secondsToDismiss: TimeInterval?
    public var snoozeCount: Int
    /// How many times the mission screen was abandoned and the alarm re-armed itself.
    public var dodgeCount: Int

    public enum Outcome: String, Codable, Hashable, Sendable, CaseIterable {
        /// Mission cleared. The only outcome that counts as a win.
        case completed
        /// Snoozed to the end of the allowance, then cleared.
        case completedAfterSnoozes
        /// The user cleared it with the emergency escape hatch.
        case bailedOut
        /// The alarm was silenced by the system or the phone died mid-mission.
        case interrupted

        public var isWin: Bool { self == .completed || self == .completedAfterSnoozes }
        public var titleKey: String { "outcome.\(rawValue)" }
    }

    public init(
        id: UUID = UUID(),
        alarmID: UUID,
        scheduledFor: Date,
        dismissedAt: Date? = nil,
        outcome: Outcome,
        mission: MissionKind,
        difficulty: Difficulty,
        secondsToDismiss: TimeInterval? = nil,
        snoozeCount: Int = 0,
        dodgeCount: Int = 0
    ) {
        self.id = id
        self.alarmID = alarmID
        self.scheduledFor = scheduledFor
        self.dismissedAt = dismissedAt
        self.outcome = outcome
        self.mission = mission
        self.difficulty = difficulty
        self.secondsToDismiss = secondsToDismiss
        self.snoozeCount = snoozeCount
        self.dodgeCount = dodgeCount
    }

    /// Minutes between the scheduled time and the actual dismissal. Negative is possible:
    /// the user can clear an alarm early from the app.
    public var minutesLate: Double? {
        guard let dismissedAt else { return nil }
        return dismissedAt.timeIntervalSince(scheduledFor) / 60
    }
}
