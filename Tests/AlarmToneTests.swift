import DawnbreakKit
import Foundation
import Testing
@testable import Dawnbreak

/// The tones, from the angle that failed: how many of them a person can actually reach.
///
/// The catalogue was never the problem. Fourteen `.caf` files shipped in the binary, fourteen cases
/// were declared, and every one of them was in the accessibility tree, so any test that counted
/// tones would have passed. What the owner saw on his own phone was four, because the picker was a
/// horizontal strip of 74pt tiles inside a card with the scroll indicator hidden, and three or four
/// is all that fits. A list nobody can see the end of is a list with four items in it.
@Suite("Alarm tones")
struct AlarmToneTests {

    /// The exact set, in order, because the order is the loudness ladder and the grid relies on it.
    @Test("Fourteen tones ship, gentlest first and worst last")
    func theCatalogueIsFixed() {
        #expect(AlarmSound.allCases.map(\.rawValue) == [
            "sunrise", "birdsong",
            "marimba", "cascade", "bellhop",
            "radar", "klaxon", "hammer", "spiral",
            "siren", "pulse", "hornet", "buzzer", "cicada",
        ])
    }

    /// The grid shows no class headers, and that is only honest if the classes are contiguous in
    /// declaration order: the icon and its colour then read as four bands without a word of text,
    /// which is four fewer strings to translate twelve times.
    @Test("The loudness classes are contiguous, so the grid needs no headings")
    func classesAreContiguous() {
        var seen: [AlarmSound.Loudness] = []
        for sound in AlarmSound.allCases where seen.last != sound.loudness {
            #expect(!seen.contains(sound.loudness), "\(sound.rawValue) restarts the \(sound.loudness) band")
            seen.append(sound.loudness)
        }
        #expect(seen == [.gentle, .standard, .harsh, .savage])
    }

    @Test("Every tone has a name in every language", arguments: AlarmSound.allCases)
    func everyToneIsNamed(sound: AlarmSound) {
        let name = localized(sound.titleKey)
        #expect(name != sound.titleKey, "\(sound.titleKey) has no translation at all")
        #expect(!name.isEmpty)
    }

    /// The identifiers the UI test counts. `ax.editor.tone.` must not be a prefix of the row that
    /// opens the grid, or a count of tiles would silently include the opener and pass with thirteen.
    @Test("Tile identifiers are unique and do not collide with the row that opens them")
    func identifiersDoNotCollide() {
        let tiles = AlarmSound.allCases.map { AccessibilityID.editorTone($0.rawValue) }
        #expect(Set(tiles).count == AlarmSound.allCases.count)
        #expect(!AccessibilityID.editorSoundRow.hasPrefix("ax.editor.tone."))
        #expect(!AccessibilityID.editorSoundGrid.hasPrefix("ax.editor.tone."))
    }

    /// A demo alarm seeds the first screenshot, so it must name a tone that exists.
    @Test("Every seeded demo alarm uses a real tone")
    func demoAlarmsUseRealTones() {
        let names = Set(AlarmSound.allCases.map(\.rawValue))
        for alarm in CaptureMode.demoAlarms() {
            #expect(names.contains(alarm.soundName), "\(alarm.soundName) is not a tone")
        }
    }
}
