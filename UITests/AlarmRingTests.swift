import XCTest

/// The half of the wake-up journey a simulator can actually watch.
///
/// The report this suite exists for, in the reporter's words: "quand l'alarme sonne, si je
/// clique sur calcul ou sur arrêter, je ne vais jamais résoudre le challenge, rien ne se
/// passe." Chasing that through a real ring on this simulator found and killed three bugs —
/// the environment default re-pointing the shared bridge at a temporary directory, a stale
/// daemon read making reconciliation cancel a freshly armed alarm, and the intents' id
/// parameter arriving as nil — and then hit the wall this suite's shape records: the iOS 26.5
/// simulator schedules, fires and logs the alarm ("Firing event", "Requesting alarm alert"),
/// but never draws the alert. No alert, no buttons; the press itself is testable only on a
/// device, by a person.
///
/// So the journey is held in two pieces. The press's *consequences* — the follow-up armed
/// before anything else, the handoff written, the id resolved even when the parameter is
/// gone — are unit-tested in `MissionHandoffTests` against the scheduler double. What runs
/// here is the piece in between the press and the mission: an app launched with a mission
/// already owed, the exact state a lock-screen intent leaves behind, has to put the mission
/// screen on the glass. That is the half that was silently broken by the presentation-slot
/// collisions, and the half a simulator can verify.
@MainActor
final class AlarmRingTests: UITestCase {

    /// The state a lock-screen press leaves behind, then a cold launch into it. The mission
    /// screen must be what the user sees — not the alarm list, not onboarding, not a sheet.
    func testAnOwedMissionTakesTheScreenAtLaunch() {
        let app = XCUIApplication()
        app.launchArguments = [CaptureLaunch.e2eMissionArgument]
        app.launch()
        allowAlarmsIfAsked()

        XCTAssertTrue(
            element(AccessibilityID.missionHeader, in: app).waitForExistence(timeout: 30),
            "a mission was owed and the launch did not open it"
        )
    }

    /// And leaving it is not a way out: going home with the mission unsolved, then coming
    /// back, must land on the mission again, not on the list.
    func testAnUnsolvedMissionComesBackWithTheApp() {
        let app = XCUIApplication()
        app.launchArguments = [CaptureLaunch.e2eMissionArgument]
        app.launch()
        allowAlarmsIfAsked()
        waitFor(AccessibilityID.missionHeader, in: app)

        XCUIDevice.shared.press(.home)
        settle()
        app.activate()

        XCTAssertTrue(
            element(AccessibilityID.missionHeader, in: app).waitForExistence(timeout: 30),
            "the mission was still owed and coming back to the app lost it"
        )
    }

    /// AlarmKit's permission alert, if this simulator has never answered it.
    ///
    /// Matched in the simulator's language, not the test's: the alert is the system's. English
    /// says "Allow", French says "Autoriser" — and "Ne pas autoriser" is why the French match
    /// is exact rather than a prefix.
    private func allowAlarmsIfAsked() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        // Fifteen seconds, not five: on a simulator that has never seen the app, the prompt
        // arrives only once the launch seed asks for authorization, behind a cold start.
        guard alert.waitForExistence(timeout: 15) else { return }
        let allow = alert.buttons.matching(
            NSPredicate(format: "label BEGINSWITH[c] 'allow' OR label ==[c] 'autoriser'")
        ).firstMatch
        if allow.exists { allow.tap() }
    }
}
