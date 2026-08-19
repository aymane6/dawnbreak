import XCTest

/// The handful of things that have to be true of the built app before anything else matters: it
/// launches, the six screens come up, the mission screen cannot be swiped away, and no language
/// shows a raw localization key.
///
/// Deliberately small. A UI test is the slowest and least specific test there is, so anything
/// that can be asserted about the model or the catalogs is asserted in `DawnbreakTests` instead;
/// what is left here is what only a running app on a simulator can prove.
final class SmokeTests: UITestCase {

    /// Every seeded alarm reaches the list.
    ///
    /// Four is `CaptureMode.demoAlarms()`, which `CaptureDataTests` pins from the app's side. The
    /// screenshots and the editor test both assume a row is there to open, so this is the
    /// assertion that says why they can.
    func testTheAlarmListComesUpWithEverySeededAlarm() {
        let app = launch(.alarms)
        waitFor(AccessibilityID.addAlarm, in: app)
        XCTAssertEqual(matches(AccessibilityID.alarmRow, in: app).count, 4)
        assertNothingIsCoveringTheScreen(app)
    }

    /// Tapping a row opens that alarm, and cancelling puts the list back.
    func testTheEditorOpensOnAnAlarmAndCloses() {
        let app = launch(.alarms)
        waitFor(AccessibilityID.alarmRow, in: app).tap()

        let save = waitFor(AccessibilityID.editorSave, in: app)
        // Enabled, because the alarm being edited already has a complete mission. A disabled
        // Save on an existing alarm means `MissionConfig.isIncomplete` has started lying.
        XCTAssertTrue(save.isEnabled)

        element(AccessibilityID.editorCancel, in: app).tap()
        XCTAssertTrue(
            element(AccessibilityID.editorSave, in: app).waitForNonExistence(timeout: 5),
            "the editor sheet stayed up after cancel"
        )
        XCTAssertTrue(element(AccessibilityID.addAlarm, in: app).exists)
    }

    /// The promise the whole app rests on: the mission screen does not go away because someone
    /// swiped at it half asleep.
    ///
    /// It is a `fullScreenCover` rather than a sheet for exactly this reason, and the difference
    /// between the two is one word in `RootView` that no unit test can see.
    func testARingingMissionDoesNotGoAwayOnASwipe() {
        let app = launch(.mission)
        waitFor(AccessibilityID.missionHeader, in: app)
        // The deliberate escape hatch, which is on by default. Its absence would mean a user who
        // genuinely cannot finish the mission has no way out, which is a support nightmare.
        XCTAssertTrue(element(AccessibilityID.missionExit, in: app).exists)

        app.swipeDown()
        app.swipeDown()
        XCTAssertTrue(element(AccessibilityID.missionHeader, in: app).exists, "the mission was swiped away")
    }

    /// Onboarding walks to the end and hands over to the app.
    ///
    /// Four taps on the primary button: three page turns and then "start". The permission request
    /// is a separate button on the third page and is deliberately not tapped, because granting it
    /// means a system alert, and a test that depends on the wording of an Apple alert breaks on an
    /// OS update.
    func testOnboardingWalksThroughToTheAlarmList() {
        let app = launch(.onboarding)
        for _ in 0..<4 {
            waitFor(AccessibilityID.onboardingNext, in: app).tap()
        }
        XCTAssertTrue(
            element(AccessibilityID.addAlarm, in: app).waitForExistence(timeout: anchorTimeout),
            "onboarding finished without showing the app"
        )
    }

    func testTheStatsScreenComesUp() {
        let app = launch(.stats)
        waitFor(AccessibilityID.statsWindow, in: app)
        assertNothingIsCoveringTheScreen(app)
    }

    func testTheSettingsScreenComesUp() {
        let app = launch(.settings)
        waitFor(AccessibilityID.settingsAppearance, in: app)
        assertNothingIsCoveringTheScreen(app)
    }

    /// The path the reviewer's notes describe: Settings, then Dawnbreak Pro, on the free tier.
    ///
    /// `metadata/review_information/notes.txt` tells Apple to get to the purchase screen that way,
    /// and a reviewer who cannot follow those notes files a rejection rather than a bug report. The
    /// row exists only on the free tier: on Pro it is "Pro is active" with nothing to tap, so this
    /// is also the assertion that the seeded tier is the one being tested.
    ///
    /// Prices are not part of it. They need a StoreKit test session inside the app's own process,
    /// which a UI test runner cannot give it, and they are what `ReviewShotTests` exists for.
    func testTheFreeTierReachesThePaywallFromSettings() {
        let app = launch(.settings, free: true)
        waitFor(AccessibilityID.settingsUpgrade, in: app).tap()
        XCTAssertTrue(
            element(AccessibilityID.paywallPurchase, in: app).waitForExistence(timeout: anchorTimeout),
            "Settings no longer reaches the paywall, and the review notes say it does"
        )
    }

    /// Every one of the twelve languages launches, and none of them shows a raw key.
    ///
    /// `LocalizationTests` already proves the catalogs are complete, from the compiled tables.
    /// This proves the app is *reading* them: a locale left out of the target, a `Text("alarms.
    /// title")` that resolves against the wrong bundle, or a `.lproj` the build never produced
    /// all look identical from the catalog's side and show up here as a dotted string on screen.
    func testEveryLanguageLaunches() {
        for locale in CaptureLocale.all {
            let app = launch(.alarms, in: locale)
            XCTAssertTrue(
                element(AccessibilityID.addAlarm, in: app).waitForExistence(timeout: anchorTimeout),
                "the app did not come up in \(locale.language)"
            )
            assertNothingIsCoveringTheScreen(app)

            // A closure rather than `map(\.label)`: `label` is main-actor isolated and a key path
            // cannot carry isolation, so `\.label` does not compile under Swift 6.
            let raw = app.staticTexts.allElementsBoundByIndex.map { $0.label }.filter(Self.looksLikeAKey)
            XCTAssertTrue(raw.isEmpty, "\(locale.language) shows untranslated keys: \(raw)")
            app.terminate()
        }
    }

    /// Arabic mirrors the layout and counts in Arabic-Indic digits.
    ///
    /// Both are properties of the run rather than of the app: the first comes from the language,
    /// the second from `-AppleLocale ar_EG`, and the Arabic screenshots are worthless if either
    /// silently fails to take effect. Checked here rather than by looking at the images, because
    /// nobody reviewing a pull request opens seventy-two PNGs.
    func testArabicMirrorsTheLayoutAndUsesArabicDigits() {
        let arabic = launch(.alarms, in: .arabic)
        let add = waitFor(AccessibilityID.addAlarm, in: arabic)
        XCTAssertLessThan(add.frame.midX, arabic.frame.midX, "the toolbar button did not move to the leading edge")

        let labels = arabic.staticTexts.allElementsBoundByIndex.map { $0.label }
        XCTAssertTrue(labels.contains(where: Self.hasArabicIndicDigits), "the clock is not in Arabic-Indic digits")
        arabic.terminate()

        let english = launch(.alarms, in: .english)
        let englishAdd = waitFor(AccessibilityID.addAlarm, in: english)
        XCTAssertGreaterThan(englishAdd.frame.midX, english.frame.midX, "the toolbar button is not on the right")
    }

    // MARK: - Reading the screen

    /// Whether a label looks like a localization key that was never translated.
    ///
    /// A lowercase word followed by at least one dotted component: `alarms.title`,
    /// `mission.math.subtitle`. A version number is not caught, because it starts with a digit;
    /// a translated string is not caught, because translations contain spaces or non-Latin
    /// script; and the app's own name is not caught, because it is capitalised.
    private static func looksLikeAKey(_ label: String) -> Bool {
        label.wholeMatch(of: /[a-z][a-z0-9]*(\.[A-Za-z0-9]+)+/) != nil
    }

    private static func hasArabicIndicDigits(_ label: String) -> Bool {
        label.unicodeScalars.contains { (0x0660...0x0669).contains(Int($0.value)) }
    }
}
