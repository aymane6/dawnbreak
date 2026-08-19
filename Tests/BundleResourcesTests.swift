import DawnbreakKit
import Foundation
import Testing
import UIKit
@testable import Dawnbreak

/// What has to be *inside* the built app, as opposed to what the source says.
///
/// Every failure here is a shipping failure that compiles cleanly: a tone the editor offers and
/// AlarmKit cannot find, an icon App Store Connect rejects the upload for, an export-compliance
/// key whose absence turns every submission into a questionnaire.
@Suite("Bundle resources")
struct BundleResourcesTests {

    @Test("Every offered alarm tone is in the bundle", arguments: AlarmSound.allCases)
    func everyToneIsBundled(sound: AlarmSound) {
        // The same spelling AlarmKit is handed: `AlertConfiguration.AlertSound.named("radar.caf")`
        // resolves against the main bundle, so a tone the picker lists and the bundle lacks rings
        // as silence, which is the one bug this app cannot have.
        #expect(Bundle.main.url(forResource: sound.rawValue, withExtension: "caf") != nil, "\(sound.rawValue).caf")
    }

    @Test("The bundle carries no tone the app cannot offer")
    func noOrphanTones() throws {
        let bundled = Set(
            try #require(Bundle.main.urls(forResourcesWithExtension: "caf", subdirectory: nil))
                .map { $0.deletingPathExtension().lastPathComponent }
        )
        #expect(bundled == Set(AlarmSound.allCases.map(\.rawValue)), "bundled: \(bundled.sorted())")
    }

    @Test("The app icon compiled into the bundle")
    func appIconIsPresent() throws {
        // Read from the built Info.plist rather than by loading the image: this is the key App
        // Store Connect looks at, and an asset catalog with a missing 1024pt entry produces a
        // bundle that installs fine and fails at upload.
        let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any]
        let primary = try #require(icons?["CFBundlePrimaryIcon"] as? [String: Any])
        let files = try #require(primary["CFBundleIconFiles"] as? [String])
        #expect(!files.isEmpty)
        #expect(primary["CFBundleIconName"] as? String == "AppIcon")
    }

    @Test("The accent colour resolves from the asset catalog")
    func accentColourIsPresent() {
        #expect(UIColor(named: "AccentColor") != nil)
        #expect(UIColor(named: "LaunchBackground") != nil, "the launch screen would be black")
    }

    @Test("Live Activities and background audio are declared")
    func alarmCapabilitiesAreDeclared() {
        // AlarmKit draws the ringing alarm as a Live Activity; without the first key the alarm
        // rings with no way to reach the mission. Without the second, the tone stops the moment
        // the screen locks itself again mid-mission.
        #expect(Bundle.main.object(forInfoDictionaryKey: "NSSupportsLiveActivities") as? Bool == true)
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        #expect(modes?.contains("audio") == true)
    }

    @Test("The app is portrait-only, as every mission assumes")
    func orientationsArePortraitOnly() {
        let orientations = Bundle.main.object(forInfoDictionaryKey: "UISupportedInterfaceOrientations") as? [String]
        #expect(orientations == ["UIInterfaceOrientationPortrait"])
    }

    @Test("Export compliance is answered in the bundle")
    func encryptionIsDeclared() {
        // Missing, this stops every single upload on a questionnaire. The app uses nothing beyond
        // the exempt system TLS, so the answer is a flat no.
        #expect(Bundle.main.object(forInfoDictionaryKey: "ITSAppUsesNonExemptEncryption") as? Bool == false)
    }

    @Test("The version numbers are the shape App Store Connect accepts")
    func versionsAreWellFormed() throws {
        let marketing = try #require(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        let build = try #require(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
        #expect(marketing.wholeMatch(of: /[0-9]+\.[0-9]+(\.[0-9]+)?/) != nil, "CFBundleShortVersionString \(marketing)")
        #expect(Int(build) != nil, "CFBundleVersion \(build) has to be an integer that only ever goes up")
    }

    @Test("The App Group the widget reads is spelled the way the bundle is")
    func appGroupIsCoherent() {
        // A group container is only handed to a signed build, so on an unsigned simulator run it
        // is nil and `StoreLocation` falls back to the app's own support directory. Asserting the
        // container exists would therefore be asserting how the test was launched. What holds on
        // every run is the part a typo breaks: the identifier is `group.` + the bundle id, which
        // is what both entitlements files declare, and the stores get a directory to write to.
        // That the two entitlements files agree is checked by `scripts/asc-preflight.py`, which
        // can read them; a test inside the bundle cannot.
        #expect(StoreLocation.appGroup == "group.\(Bundle.main.bundleIdentifier ?? "")")

        let directory = StoreLocation.supportDirectory()
        #expect(directory.lastPathComponent == "Dawnbreak")
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: StoreLocation.appGroup) {
            // Signed run: then it really has to be the shared container, because a widget reading
            // an empty container draws a blank lock screen.
            #expect(directory.path.hasPrefix(container.path), "the stores are not writing into the shared container")
        }
    }
}
