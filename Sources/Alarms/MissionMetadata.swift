import AlarmKit
import DawnbreakKit
import Foundation

/// What travels with the alarm into the system.
///
/// AlarmKit hands this back to the widget extension when it draws the Live Activity, and
/// back to the app when the alarm's secondary button is pressed. It is the only channel
/// between the three processes, so it carries exactly what the lock-screen presentation and
/// the mission screen need — and nothing else, because it is serialised into a system
/// database the app does not control.
struct MissionMetadata: AlarmMetadata {
    /// The app's own alarm id, equal to the AlarmKit alarm id. Carried explicitly so the
    /// app can find the full `AlarmDraft` without depending on which id AlarmKit reports.
    var alarmID: UUID
    var mission: MissionKind
    var difficulty: Difficulty
    var rounds: Int
    /// The user's label, e.g. "Gym". Empty when they did not set one.
    var label: String
    /// Whether the alarm re-arms itself if the mission screen is abandoned. The widget
    /// shows a different subtitle when it does, so the user knows dodging will not work.
    var relentless: Bool
    /// Localized display name of the enrolled object, for a photo or barcode mission, so
    /// the Live Activity can say "photograph the kettle" on the lock screen.
    var enrollmentName: String?

    init(alarm: AlarmDraft) {
        self.alarmID = alarm.id
        self.mission = alarm.mission.kind
        self.difficulty = alarm.mission.difficulty
        self.rounds = alarm.mission.rounds
        self.label = alarm.label
        self.relentless = alarm.relentless
        self.enrollmentName = alarm.mission.enrollment?.displayName
    }
}
