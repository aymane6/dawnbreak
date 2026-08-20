import Foundation

/// The launch arguments that put the app into its screenshot state.
///
/// Compiled into the app target *and* into the UI test target, because the two processes have to
/// agree on these strings exactly: the test writes them into `XCUIApplication.launchArguments`
/// and the app reads them out of `ProcessInfo`. A typo on one side does not fail to compile, it
/// silently produces seventy-two screenshots of an empty alarm list, and nothing about the run
/// looks wrong until someone opens the images.
enum CaptureLaunch {
    /// Presence of this flag is what makes a launch a capture run. Everything else is optional.
    static let argument = "-dawnbreak-capture"
    /// Followed by a `Screen` raw value.
    static let screenArgument = "-dawnbreak-capture-screen"
    /// Seeds the free tier instead of Pro.
    ///
    /// The store screenshots are taken with Pro on, because a listing full of padlocks sells
    /// nothing. The test that walks the path the review notes describe needs the opposite: an
    /// account that already has Pro shows "Pro is active" in settings, with no upgrade row to tap
    /// and no purchase screen behind it.
    static let freeArgument = "-dawnbreak-capture-free"

    /// Followed by a number of seconds: a Debug launch arms one real alarm that far out, through
    /// the real bridge and the real AlarmKit daemon, for the end-to-end ring test. Not a capture
    /// flag: the run it starts is the ordinary app, and the whole point is that nothing is faked.
    /// The behaviour behind it is compiled out of Release; only the string lives here, because the
    /// test target has to spell it identically.
    static let e2eAlarmArgument = "-dawnbreak-e2e-alarm"

    /// A Debug launch that starts with a mission already owed, as if a lock-screen intent had
    /// just run: the handoff written to the shared container, the alarm in the store, nothing
    /// faked past that point. What the test then watches is the half of the journey the app
    /// owns — the mission screen taking the display, over whatever else wanted it.
    static let e2eMissionArgument = "-dawnbreak-e2e-mission"

    /// Where the seeded run stores its data. A suite rather than `.standard` so a capture run
    /// cannot overwrite the preferences of an app already installed on the same simulator.
    static let defaultsSuite = "com.aymbam.dawnbreak.capture"

    /// The screens the store listing needs, in the order they are shown there.
    ///
    /// The order is the screenshot order, so the numbering the App Store sorts by comes from
    /// `allCases` rather than being written twice. `editor` is the one the test still has to tap
    /// for, because opening that sheet is `AlarmListView`'s own state.
    enum Screen: String, CaseIterable {
        case alarms, editor, mission, stats, settings, onboarding

        /// `01-alarms`, `02-editor`, … The prefix is what makes the set sort correctly in Finder
        /// and in the App Store Connect upload, which orders by filename.
        var fileStem: String {
            let position = (Screen.allCases.firstIndex(of: self) ?? 0) + 1
            return String(format: "%02d-%@", position, rawValue)
        }

        /// The headline drawn above the framed screenshot on the store page, and the line under it.
        ///
        /// A store listing is read at thumbnail size, so the caption is most of what a reader takes
        /// in. These are keys rather than English literals because the caption has to be in the
        /// language of the screenshot it sits on, and it comes out of the same catalog the screen
        /// behind it did: one table, twelve languages, checked by the same tests. The compositor
        /// reads them from the built app's `.lproj`, which is why they ship in the bundle even
        /// though no screen displays them.
        var captionKey: String { "shot.caption.\(rawValue)" }
        var subcaptionKey: String { "shot.sub.\(rawValue)" }
    }

    /// `free` is a Bool rather than an `Entitlement` so that this file keeps importing nothing but
    /// Foundation: it is compiled into the widget and into the UI test target as well as the app.
    static func arguments(for screen: Screen, free: Bool = false) -> [String] {
        [argument, screenArgument, screen.rawValue] + (free ? [freeArgument] : [])
    }
}
