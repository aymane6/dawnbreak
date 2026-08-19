import Foundation
import Testing
@testable import Dawnbreak

/// The clock is the largest thing on the screen and the one piece of text that is wrong in the
/// most languages if it is built by interpolation. These cover the three ways it goes wrong:
/// the 12-hour boundaries, the leading zero, and the digits themselves.
@Suite("Clock formatting")
struct ClockFormatterTests {

    private func formatter(uses24Hour: Bool, locale: String = "en_GB") -> ClockFormatter {
        ClockFormatter(uses24Hour: uses24Hour, locale: Locale(identifier: locale))
    }

    @Test("A 24-hour clock pads the hour")
    func twentyFourHourPads() {
        #expect(formatter(uses24Hour: true).digits(hour: 7, minute: 5) == "07:05")
        #expect(formatter(uses24Hour: true).digits(hour: 0, minute: 0) == "00:00")
        #expect(formatter(uses24Hour: true).digits(hour: 23, minute: 59) == "23:59")
    }

    @Test("A 24-hour clock has no AM or PM to show")
    func twentyFourHourHasNoMeridiem() {
        // Nil rather than an empty string, so the layout can leave the label out entirely
        // instead of reserving a gap for it.
        #expect(formatter(uses24Hour: true).meridiem(hour: 9) == nil)
        #expect(formatter(uses24Hour: true).full(hour: 9, minute: 30) == "09:30")
    }

    @Test("Midnight and noon are 12, not 0", arguments: [
        (hour: 0, expected: "12:05"),
        (hour: 12, expected: "12:05"),
        (hour: 13, expected: "1:05"),
        (hour: 23, expected: "11:05"),
    ])
    func twelveHourBoundaries(hour: Int, expected: String) {
        #expect(formatter(uses24Hour: false).digits(hour: hour, minute: 5) == expected)
    }

    @Test("Morning is AM and afternoon is PM")
    func meridiemFlipsAtNoon() {
        #expect(formatter(uses24Hour: false).meridiem(hour: 0) == "AM")
        #expect(formatter(uses24Hour: false).meridiem(hour: 11) == "AM")
        #expect(formatter(uses24Hour: false).meridiem(hour: 12) == "PM")
        #expect(formatter(uses24Hour: false).meridiem(hour: 23) == "PM")
    }

    @Test("The time and the meridiem both survive being joined")
    func fullKeepsBothParts() throws {
        // Not asserted as "7:05 AM": the order and the space come from `clock.order`, which
        // Japanese writes as "%2$@%1$@" with no space at all. What must hold in every language is
        // that neither half was dropped on the way.
        let clock = formatter(uses24Hour: false)
        let full = clock.full(hour: 7, minute: 5)
        let meridiem = try #require(clock.meridiem(hour: 7))
        #expect(full.contains("7:05"))
        #expect(full.contains(meridiem))
    }

    @Test("Digits are drawn in the numbering system the region uses")
    func digitsFollowTheNumberingSystem() {
        // Egypt, not India: Hindi as spoken in India uses Western digits by default, so `hi`
        // would not exercise this path at all. Arabic in Egypt is the shipped language that
        // genuinely renders ٠٧:٠٥, and it is the one the Arabic listing is read in.
        #expect(formatter(uses24Hour: true, locale: "ar_EG").digits(hour: 7, minute: 5) == "٠٧:٠٥")
        #expect(formatter(uses24Hour: false, locale: "ar_EG").digits(hour: 19, minute: 5) == "٧:٠٥")
    }

    @Test("Padding is re-applied in the local zero, not the ASCII one")
    func paddingUsesTheLocalZero() {
        // The number style drops the leading zero, and pasting an ASCII "0" back on would produce
        // "0٥" on an Egyptian phone. Both digits have to come out of the same alphabet.
        let text = formatter(uses24Hour: true, locale: "ar_EG").digits(hour: 5, minute: 5)
        #expect(text == "٠٥:٠٥")
        #expect(!text.contains("0"))
    }

    @Test("A four-digit year's worth of grouping never appears in a clock")
    func minutesAreNeverGrouped() {
        // `IntegerFormatStyle` groups by default in most locales; a clock that reads "1 000" is
        // the classic symptom, and it only shows up in a locale that groups at four digits.
        let german = formatter(uses24Hour: true, locale: "de_DE")
        #expect(german.digits(hour: 10, minute: 30) == "10:30")
    }
}
