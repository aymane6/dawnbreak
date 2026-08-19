import AlarmKit
import AppIntents
import DawnbreakKit
import Foundation

/// The two buttons AlarmKit draws on the ringing alert, as App Intents.
///
/// The design constraint worth stating: AlarmKit always draws a stop affordance. There is no
/// API to remove it, and there should not be — a user whose camera is broken must be able to
/// silence their phone. So "you cannot stop the alarm without completing the mission" is
/// implemented honestly: pressing stop opens the mission and, if the alarm is set to be
/// relentless, arms a follow-up a minute later. Clearing the mission is what cancels the
/// follow-up. Dodging the mission buys a minute, not the morning.

/// Fired by the alert's own stop affordance.
struct StopAlarmIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop alarm"
    static let description = IntentDescription("Silences the alarm and opens the mission that dismisses it for good.")
    /// The whole point: the app comes to the front on the mission screen rather than the
    /// alarm simply going quiet.
    static let openAppWhenRun = true
    /// Hidden from the Shortcuts library, which is also why these three titles are the only
    /// user-facing strings in the app left in English: nobody sees them. An intent whose one
    /// parameter is an alarm's UUID is not something a person can usefully build a shortcut
    /// out of, and offering it would put "Stop alarm" in Shortcuts next to a text field
    /// expecting a UUID.
    static let isDiscoverable = false

    @Parameter(title: "Alarm")
    var alarmID: String

    init() {}
    init(alarmID: UUID) { self.alarmID = alarmID.uuidString }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: alarmID) else { return .result() }
        await AlarmBridge.shared.handleStopPressed(alarmID: id)
        return .result()
    }
}

/// Fired by the alert's secondary button, the one labelled with the mission.
struct StartMissionIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Start mission"
    static let description = IntentDescription("Opens the wake-up mission for this alarm.")
    static let openAppWhenRun = true
    static let isDiscoverable = false

    @Parameter(title: "Alarm")
    var alarmID: String

    init() {}
    init(alarmID: UUID) { self.alarmID = alarmID.uuidString }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: alarmID) else { return .result() }
        await AlarmBridge.shared.handleMissionRequested(alarmID: id)
        return .result()
    }
}

/// Fired by the countdown presentation's pause button when the user snoozes.
struct SnoozeAlarmIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Snooze"
    static let description = IntentDescription("Silences the alarm for a few minutes, then rings again.")
    /// The one that must not open the app: a snooze is a request to be left alone for nine
    /// minutes, and bringing the app to the front would defeat it.
    static let openAppWhenRun = false
    static let isDiscoverable = false

    @Parameter(title: "Alarm")
    var alarmID: String

    init() {}
    init(alarmID: UUID) { self.alarmID = alarmID.uuidString }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: alarmID) else { return .result() }
        await AlarmBridge.shared.handleSnoozePressed(alarmID: id)
        return .result()
    }
}
