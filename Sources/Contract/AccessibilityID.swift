import Foundation

/// The identifiers the UI tests navigate by.
///
/// Compiled into the app target and into the UI test target, so renaming a control cannot leave
/// the test hunting for a name nothing answers to any more.
///
/// A UI test must not look for localized text. `app.buttons["Save"]` finds nothing on a Japanese
/// simulator, and the screenshot run visits twelve languages including one that reverses the
/// layout; an identifier is the only handle that reads the same in all of them. These are also
/// the only handles: everything else on screen is found through the accessibility labels real
/// users hear, which is a useful side effect, because a control the test cannot reach that way is
/// usually one VoiceOver cannot either.
///
/// Every value starts with `ax.` so that `make_strings.py` can tell an identifier from a
/// localization key: it fails the build on a dotted literal that has no translation, and these
/// are never translated.
enum AccessibilityID {
    /// Toolbar "+" on the alarm list.
    static let addAlarm = "ax.alarms.add"
    /// Every alarm card carries it, so the test taps `.firstMatch` to open the editor.
    static let alarmRow = "ax.alarm.row"

    static let editorSave = "ax.editor.save"
    static let editorCancel = "ax.editor.cancel"
    /// "Try this mission" in the editor, and the row that adds a follow-on to the chain.
    static let editorTryMission = "ax.editor.try"
    static let editorChainAdd = "ax.editor.chainAdd"
    /// The row that opens the tone list, and the grid it opens.
    ///
    /// Both exist because a horizontal strip of tiles hid ten of the fourteen tones: only three or
    /// four fitted, the scroll indicator was hidden, and the app read as having four alarm sounds.
    /// A UI test now counts the tiles and checks each one is inside the window and hittable without
    /// a single swipe, which is the only form of the assertion that would have failed before.
    static let editorSoundRow = "ax.editor.sound.row"
    static let editorSoundGrid = "ax.editor.sound.grid"

    /// One tile in the tone grid. The stem is deliberately not a prefix of `editorSoundRow`, so a
    /// test that counts elements beginning with `ax.editor.tone.` cannot also match the opener.
    static func editorTone(_ soundName: String) -> String { "ax.editor.tone.\(soundName)" }

    /// Proof that the mission screen is up. The header, not the escape hatch below it, which a
    /// user can switch off in settings and is therefore not always on screen.
    static let missionHeader = "ax.mission.header"
    /// The escape hatch, present only while `Preferences.emergencyExitEnabled` is on.
    static let missionExit = "ax.mission.exit"
    /// The banner that says the phone is being held. The smoke test looks for it, because "the
    /// mission refuses to count" is only a feature if the user is told so.
    static let squatsPhoneWarning = "ax.mission.squats.phoneWarning"

    /// The 7/30/90-day picker in the stats toolbar.
    static let statsWindow = "ax.stats.window"
    /// The appearance picker, far enough down the settings list to prove the screen scrolled.
    static let settingsAppearance = "ax.settings.appearance"
    /// The primary button on the onboarding pages.
    static let onboardingNext = "ax.onboarding.next"
}
