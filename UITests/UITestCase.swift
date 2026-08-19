import XCTest

/// What every UI test in this target needs: a launch, a handle, and a wait.
///
/// The rules encoded here are the two that make a twelve-language UI test possible at all.
/// Nothing is found by its text, because the same control is called "Save", "保存" and "حفظ"
/// depending on the run, and nothing is reached by navigating, because the tab bar's first tab
/// is on the right in Arabic. Every screen is chosen with a launch argument and every control is
/// found by an identifier out of `Sources/Contract`.
///
/// `@MainActor` on the class rather than on each test: XCUIApplication, XCUIElement and
/// XCUIScreen are all main-actor isolated in the iOS 26 SDK, and a UI test has nowhere else to
/// run. Subclasses inherit the isolation, so every `test…` method below is on the main actor
/// without saying so.
@MainActor
class UITestCase: XCTestCase {

    /// Long enough for a cold Debug launch on a busy machine running twelve simulator clones at
    /// once. These are not latency tests, and a timeout that fires early costs a whole rerun.
    let anchorTimeout: TimeInterval = 90

    /// The async form, because the synchronous `setUp()` is nonisolated and cannot be overridden
    /// by a main-actor method.
    override func setUp() async throws {
        try await super.setUp()
        // A failed anchor means everything after it is testing the wrong screen. Stop there.
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    /// Launches the app onto a given screen, in a given language.
    ///
    /// Always in capture mode, even for the smoke tests. Not for the screenshots: for the two
    /// things the flag also does, which is seed data worth asserting against and keep the app
    /// from asking for the alarm permission on launch. A UI test that has to dismiss a system
    /// alert before it can begin is a UI test that fails the first time Apple rewords the alert.
    /// `free` seeds the free tier, which only the paywall screenshot wants: everything else is
    /// photographed with Pro on, and a Pro account cannot reach the purchase screen.
    func launch(
        _ screen: CaptureLaunch.Screen,
        in locale: CaptureLocale = .english,
        free: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = CaptureLaunch.arguments(for: screen, free: free) + locale.launchArguments
        app.launch()
        return app
    }

    /// Finds an element by identifier without caring what kind of element it is.
    ///
    /// A SwiftUI `Picker` is a button in one style and a segmented control in another, and a row
    /// with `.accessibilityElement(children: .combine)` is neither. Querying `app.buttons[…]` for
    /// something that turned into a segmented control fails with "no matches found", which reads
    /// like the identifier is wrong when the identifier is fine. Searching every type costs a
    /// fraction of a second per screen and cannot go wrong that way.
    func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        matches(identifier, in: app).firstMatch
    }

    func matches(_ identifier: String, in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: identifier)
    }

    /// Waits for an element and returns it, so a caller can go straight on to tapping it.
    @discardableResult
    func waitFor(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        let element = element(identifier, in: app)
        XCTAssertTrue(element.waitForExistence(timeout: anchorTimeout), "\(identifier) never appeared")
        return element
    }

    /// A beat for the last animation to land.
    ///
    /// XCUITest waits for the app to be idle before a query or a tap, but `XCUIScreen.screenshot`
    /// does not wait for anything: it photographs whatever is on the glass, including the middle
    /// frame of a sheet still sliding up. Sleeping the test process does not slow the app down,
    /// which is why this is a sleep rather than a poll for a condition that has no name.
    func settle() {
        Thread.sleep(forTimeInterval: 0.9)
    }

    /// Fails if anything is on top of the app.
    ///
    /// This is the classic way a screenshot run produces seventy-two unusable images: one
    /// permission alert, dismissed by nobody, sitting over every shot. `CaptureMode` is written
    /// to ask for nothing, and this is the assertion that keeps it that way.
    func assertNothingIsCoveringTheScreen(_ app: XCUIApplication) {
        XCTAssertFalse(app.alerts.firstMatch.exists, "an alert from the app is over the screen")
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertFalse(springboard.alerts.firstMatch.exists, "a system alert is over the screen")
        XCTAssertEqual(app.state, .runningForeground, "the app is not in front")
    }
}
