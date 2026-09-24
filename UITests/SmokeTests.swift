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

    /// Every alarm tone has to be reachable, and reachable without knowing to swipe.
    ///
    /// This is the test that was missing when the owner reported that the app had four alarm sounds.
    /// It had fourteen, and all fourteen were in the accessibility tree, so counting them would have
    /// passed: they sat in a horizontal strip of 74pt tiles inside a card, with the scroll indicator
    /// hidden, and only three or four were on screen. So the assertion is not that the tiles exist.
    /// It is that each one is inside the window and hittable, after zero swipes.
    ///
    /// Run in Arabic as well, where the names are longer and the layout is mirrored, because a tile
    /// pushed off the edge by a translation is the same bug with a different cause.
    func testEveryAlarmToneIsReachableFromTheEditor() {
        for locale in [CaptureLocale.english, .arabic] {
            let app = launch(.alarms, in: locale)
            waitFor(AccessibilityID.alarmRow, in: app).tap()
            waitFor(AccessibilityID.editorSave, in: app)

            // The row that opens the list lives in the sound card, below the fold on a small screen.
            scrollTo(AccessibilityID.editorSoundRow, in: app).tap()
            // The first tile rather than the grid: an identifier on a `LazyVGrid` is an identifier on
            // a layout container, and SwiftUI does not publish those as accessibility elements.
            waitFor(AccessibilityID.editorTone("sunrise"), in: app)

            let window = app.windows.firstMatch.frame
            for name in Self.everyToneRawValue {
                let tile = element(AccessibilityID.editorTone(name), in: app)
                XCTAssertTrue(tile.waitForExistence(timeout: 5), "\(locale.language): no tile for \(name)")
                XCTAssertTrue(tile.isHittable, "\(locale.language): the tile for \(name) cannot be tapped")
                XCTAssertTrue(
                    window.contains(tile.frame),
                    "\(locale.language): the tile for \(name) is outside the window at \(tile.frame)"
                )
            }
            app.terminate()
        }
    }

    /// Choosing one has to stick, through the push, the save, and a reopen.
    func testChoosingAToneSticksThroughSaveAndReopen() {
        let app = launch(.alarms)
        waitFor(AccessibilityID.alarmRow, in: app).tap()
        waitFor(AccessibilityID.editorSave, in: app)
        scrollTo(AccessibilityID.editorSoundRow, in: app).tap()

        // The last tone in the grid, which is also the one that no strip ever showed.
        let cicada = waitFor(AccessibilityID.editorTone("cicada"), in: app)
        cicada.tap()
        XCTAssertTrue(cicada.isSelected, "tapping a tone did not select it")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        element(AccessibilityID.editorSave, in: app).tap()

        waitFor(AccessibilityID.alarmRow, in: app).tap()
        scrollTo(AccessibilityID.editorSoundRow, in: app).tap()
        XCTAssertTrue(
            waitFor(AccessibilityID.editorTone("cicada"), in: app).isSelected,
            "the chosen tone did not survive save and reopen"
        )
    }

    /// The fourteen, spelled out here rather than read from `AlarmSound`: the UI test bundle sees
    /// only the app target and `Sources/Contract`, so the model is invisible to it. Written twice on
    /// purpose, and `AlarmToneTests` in the unit bundle pins the same list against the real enum, so
    /// a tone added in one place and forgotten in the other fails there.
    static let everyToneRawValue = [
        "sunrise", "birdsong",
        "marimba", "cascade", "bellhop",
        "radar", "klaxon", "hammer", "spiral",
        "siren", "pulse", "hornet", "buzzer", "cicada",
    ]

    /// The editor's two newest promises: a mission can be tried before anything is armed, and
    /// the rehearsal's exit is always there and always works, because nobody does squats to leave a
    /// settings screen. The follow-on chain's add button is checked in the same pass.
    func testAMissionCanBeRehearsedFromTheEditorAndLeft() {
        let app = launch(.alarms)
        waitFor(AccessibilityID.alarmRow, in: app).tap()
        waitFor(AccessibilityID.editorSave, in: app)

        XCTAssertTrue(element(AccessibilityID.editorChainAdd, in: app).exists,
                      "the follow-on chain is missing from the editor")

        let tryButton = element(AccessibilityID.editorTryMission, in: app)
        XCTAssertTrue(tryButton.exists, "the try-this-mission button is missing")
        tryButton.tap()

        waitFor(AccessibilityID.missionHeader, in: app)
        let exit = waitFor(AccessibilityID.missionExit, in: app)
        exit.tap()
        XCTAssertTrue(
            element(AccessibilityID.missionHeader, in: app).waitForNonExistence(timeout: 5),
            "the rehearsal did not close on its exit"
        )
        XCTAssertTrue(element(AccessibilityID.editorSave, in: app).waitForExistence(timeout: 5),
                      "leaving the rehearsal lost the editor")
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
        // Below the fold on the smaller phones: the appearance picker proves both that the
        // screen came up and that its list scrolls.
        scrollTo(AccessibilityID.settingsAppearance, in: app)
        assertNothingIsCoveringTheScreen(app)
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
