import XCTest

/// Photographs the App Store listing: six screens in each of twelve languages, seventy-two
/// images, no hands.
///
/// Why a UI test and not a person with a simulator: the set has to be retaken every time the
/// layout moves, and a person retaking seventy-two screenshots will quietly stop at English.
/// Worse, a hand-taken set is inconsistent by nature, a different alarm and a different day's
/// statistics in each language, and the store shows the twelve sets to twelve audiences who each
/// assume theirs describes the app.
///
/// One test method per language rather than a single loop, for three reasons: the report says
/// which language failed, `-only-testing:DawnbreakUITests/ScreenshotTests/testCaptureJapanese`
/// retakes one language without retaking eleven, and `-parallel-testing-enabled YES` spreads the
/// twelve across simulator clones. Each clone writes to its own language directory, so there is
/// nothing to serialise.
final class ScreenshotTests: UITestCase {

    // MARK: - The twelve runs

    func testCaptureEnglish() throws { try capture(.english) }
    func testCaptureArabic() throws { try capture(.arabic) }
    func testCaptureGerman() throws { try capture(.german) }
    func testCaptureSpanish() throws { try capture(.spanish) }
    func testCaptureFrench() throws { try capture(.french) }
    func testCaptureHindi() throws { try capture(.hindi) }
    func testCaptureItalian() throws { try capture(.italian) }
    func testCaptureJapanese() throws { try capture(.japanese) }
    func testCaptureKorean() throws { try capture(.korean) }
    func testCapturePortuguese() throws { try capture(.portuguese) }
    func testCaptureRussian() throws { try capture(.russian) }
    func testCaptureChinese() throws { try capture(.chinese) }

    // MARK: - The run

    private func capture(_ locale: CaptureLocale) throws {
        let root = try outputRoot()
        try XCTSkipUnless(isWanted(locale), "\(locale.store) is not in DAWNBREAK_SHOTS_ONLY")

        let directory = root.appending(path: locale.store, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var taken: [[String: Any]] = []
        var pixels: [Int] = []

        for screen in CaptureLaunch.Screen.allCases where isWanted(screen) {
            let app = launch(screen, in: locale)
            try reach(screen, in: app)
            assertNothingIsCoveringTheScreen(app)
            settle()

            let shot = XCUIScreen.main.screenshot()
            let file = directory.appending(path: "\(screen.fileStem).png")
            do {
                try shot.pngRepresentation.write(to: file, options: .atomic)
            } catch {
                // The image is the only artefact of the run, so hand it to the result bundle
                // before failing: a permissions problem on the output directory should still
                // leave something to look at.
                let attachment = XCTAttachment(screenshot: shot)
                attachment.name = "\(locale.store)-\(screen.fileStem)"
                attachment.lifetime = .keepAlways
                add(attachment)
                throw error
            }

            pixels = try size(of: shot)
            taken.append(["screen": screen.rawValue, "file": file.lastPathComponent, "pixels": pixels])
            app.terminate()
        }

        try writeManifest(locale, screens: taken, pixels: pixels, to: directory)
    }

    /// Gets the app to the screen, and proves it arrived.
    ///
    /// Everything except the editor is chosen at launch. The editor is the alarm list's own
    /// `@State`, and adding a launch argument to open a sheet would mean shipping a code path
    /// whose only caller is this test, so this is the one screen the run taps for.
    private func reach(_ screen: CaptureLaunch.Screen, in app: XCUIApplication) throws {
        switch screen {
        case .alarms:
            waitFor(AccessibilityID.addAlarm, in: app)
        case .editor:
            waitFor(AccessibilityID.addAlarm, in: app)
            // An existing alarm rather than the "+" button: a new alarm is a screenshot of
            // default values, and this one shows a label, a repeat schedule and a mission.
            waitFor(AccessibilityID.alarmRow, in: app).tap()
            waitFor(AccessibilityID.editorSave, in: app)
        case .mission:
            waitFor(AccessibilityID.missionHeader, in: app)
        case .stats:
            waitFor(AccessibilityID.statsWindow, in: app)
        case .settings:
            waitFor(AccessibilityID.settingsAppearance, in: app)
        case .onboarding:
            waitFor(AccessibilityID.onboardingNext, in: app)
        }
    }

    // MARK: - Guards

    /// The pixel dimensions, checked against what the App Store accepts.
    ///
    /// A run on the wrong simulator produces a complete, plausible, rejected set: App Store
    /// Connect refuses the upload on size, after all twelve languages have been taken. Cheaper
    /// to fail on the first image.
    private func size(of shot: XCUIScreenshot) throws -> [Int] {
        let image = try XCTUnwrap(shot.image.cgImage, "the screenshot has no bitmap")
        let size = [image.width, image.height]
        XCTAssertTrue(
            Self.acceptedSizes.contains(size),
            "\(size[0])x\(size[1]) is not an App Store iPhone size; capture on a 6.9-inch simulator"
        )
        return size
    }

    /// The two portrait sizes the 6.9-inch iPhone slot takes, which is the only slot Apple still
    /// requires. iPhone 16/17 Pro Max is the first, 15 Pro Max and 15/16 Plus the second.
    private static let acceptedSizes = [[1320, 2868], [1290, 2796]]

    // MARK: - Output

    /// Where the images go, or a skip.
    ///
    /// A skip rather than a default path, because ⌘U in Xcode runs this target too, and taking
    /// seventy-two screenshots into a temporary directory nobody will look at is a five-minute
    /// wait imposed on someone who wanted to run the smoke tests. `scripts/shots.sh` passes
    /// `TEST_RUNNER_DAWNBREAK_SHOTS`, which is how xcodebuild forwards a variable into the test
    /// runner process.
    private func outputRoot() throws -> URL {
        let path = ProcessInfo.processInfo.environment["DAWNBREAK_SHOTS"] ?? ""
        try XCTSkipIf(path.isEmpty, "no output directory; run scripts/shots.sh to take screenshots")
        return URL(filePath: path, directoryHint: .isDirectory)
    }

    /// What the compositor reads before it frames these images.
    ///
    /// It needs the pixel size to scale to the listing canvas, and the layout direction to decide
    /// which side the caption hangs on. Both are properties of the run, so the run records them
    /// rather than the compositor inferring them from the file.
    private func writeManifest(
        _ locale: CaptureLocale,
        screens: [[String: Any]],
        pixels: [Int],
        to directory: URL
    ) throws {
        let environment = ProcessInfo.processInfo.environment
        let manifest: [String: Any] = [
            "store": locale.store,
            "language": locale.language,
            "appleLocale": locale.appleLocale,
            "layoutDirection": locale.isRightToLeft ? "rightToLeft" : "leftToRight",
            "device": environment["SIMULATOR_DEVICE_NAME"] ?? "unknown",
            "model": environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "unknown",
            "pixels": pixels,
            "screens": screens,
        ]
        let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: directory.appending(path: "manifest.json"), options: .atomic)
    }

    // MARK: - Narrowing a run

    /// `DAWNBREAK_SHOTS_ONLY=fr-FR,ja` retakes two languages. Matches either spelling, because
    /// the person typing it is looking at either a directory name or a `.lproj` folder.
    private func isWanted(_ locale: CaptureLocale) -> Bool {
        let wanted = list("DAWNBREAK_SHOTS_ONLY")
        return wanted.isEmpty || wanted.contains(locale.store) || wanted.contains(locale.language)
    }

    /// `DAWNBREAK_SHOTS_SCREENS=stats` retakes one screen after moving one card.
    private func isWanted(_ screen: CaptureLaunch.Screen) -> Bool {
        let wanted = list("DAWNBREAK_SHOTS_SCREENS")
        return wanted.isEmpty || wanted.contains(screen.rawValue)
    }

    private func list(_ variable: String) -> Set<String> {
        let raw = ProcessInfo.processInfo.environment[variable] ?? ""
        return Set(raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
    }
}
