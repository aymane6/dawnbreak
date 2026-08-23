import Foundation

/// A mission the alarm demands again later, after the previous one was cleared.
///
/// This is the "make sure I am actually up" feature: clearing one mission proves a moment of
/// wakefulness, not wakefulness. A follow-on rings the same alarm again a few minutes later
/// with a different challenge, and only clearing the last one ends the morning. The delay is
/// minutes of grace, not snooze: nothing needs pressing for it to happen, and there is no way
/// to decline it short of the emergency exit.
public struct FollowOnMission: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var mission: MissionConfig
    /// Minutes after the previous mission is cleared before the alarm rings again with this
    /// one. Clamped to a range where both ends stay honest: below one minute the user is
    /// still holding the phone, and beyond an hour they are long gone either way.
    public var minutesAfter: Int

    public init(id: UUID = UUID(), mission: MissionConfig = MissionConfig(kind: .shake), minutesAfter: Int = 10) {
        self.id = id
        self.mission = mission
        self.minutesAfter = min(max(minutesAfter, Self.minimumMinutes), Self.maximumMinutes)
    }

    public static let minimumMinutes = 1
    public static let maximumMinutes = 60

    /// How many follow-ons one alarm may carry. Three, so a morning is at most four missions
    /// long: past that the feature stops being a wake-up check and starts being a hostage
    /// situation, which is what the emergency exit exists to prevent, not to need.
    public static let maximumCount = 3
}
