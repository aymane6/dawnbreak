import AlarmKit
import AppIntents
import DawnbreakKit
import Foundation

/// The two buttons AlarmKit draws on the ringing alert, as App Intents.
///
/// The design constraint worth stating: AlarmKit always draws a stop affordance. There is no
/// API to remove it, and there should not be — a user whose camera is broken must be able to
/// silence their phone. iOS 26.1 went further and draws its own, ignoring anything the app
/// passes. So "you cannot stop the alarm without completing the mission" cannot be enforced by
/// withholding a button, and is enforced by what happens after it is pressed instead: the alarm
/// is re-armed a minute out, and the mission is opened. Only clearing the mission cancels the
/// re-arm. Dodging it buys a minute, not the morning.
///
/// Which of those two happens first is load-bearing. Re-arming comes first, because it is the
/// half that works with the app in the background, killed, or never brought to the front at
/// all; opening a screen is a request the system can decline. When it was the other way round,
/// anything that stopped the mission screen from opening also stopped the alarm from ever coming
/// back, and the stop button worked exactly as a stop button.

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
