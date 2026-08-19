import Foundation
import SwiftUI

/// Helpers for the keys that are computed rather than written as literals.
///
/// Xcode's String Catalog extracts keys from literal `Text("…")` at build time. A lot of this
/// app's keys are not literals (`mission.\(kind).title` is derived from an enum) so those keys
/// live in the catalog because `scripts/make_strings.py` puts them there, and are looked up at
/// runtime through these two helpers. That script generates the derived keys from the same enum
/// case lists the code switches over, and fails if a key on screen has no row, which is what
/// stops the two drifting apart.
extension Text {
    /// A `Text` from a key held in a variable.
    init(key: String) {
        self.init(LocalizedStringKey(key), bundle: .main)
    }
}

/// A localized string for the cases that need a `String` rather than a `Text`: accessibility
/// labels, values passed to UIKit, and format arguments.
func localized(_ key: String) -> String {
    String(localized: String.LocalizationValue(key), bundle: .main)
}

/// Formats one of the catalog's `%lld`/`%@` entries.
///
/// The `locale:` argument is what makes `%.1f` render "7,5" in French rather than "7.5", and
/// what groups a four-digit count correctly. Omitting it is the single most common way a
/// localized app still looks English.
func localized(_ key: String, _ arguments: any CVarArg...) -> String {
    String(format: localized(key), locale: .autoupdatingCurrent, arguments: arguments)
}

/// Formats a wall-clock time the way the user's region and their 24-hour override want it.
///
/// Not `Date.FormatStyle` on a synthesised `Date`: an alarm is an hour and a minute, and
/// building a `Date` for it just to format it invites the timezone bugs the model avoids.
struct ClockFormatter {
    var uses24Hour: Bool
    var locale: Locale = .autoupdatingCurrent

    /// "07:05" or "7:05".
    func digits(hour: Int, minute: Int) -> String {
        let displayHour = uses24Hour ? hour : (hour % 12 == 0 ? 12 : hour % 12)
        let hourText = uses24Hour
            ? String(format: "%02d", displayHour)
            : String(displayHour)
        return "\(localise(hourText)):\(localise(String(format: "%02d", minute)))"
    }

    /// "AM"/"PM", or nil in a 24-hour region so the layout can omit the label entirely.
    func meridiem(hour: Int) -> String? {
        guard !uses24Hour else { return nil }
        return hour < 12 ? localized("clock.am") : localized("clock.pm")
    }

    func full(hour: Int, minute: Int) -> String {
        let time = digits(hour: hour, minute: minute)
        guard let meridiem = meridiem(hour: hour) else { return time }
        // Not `"\(time) \(meridiem)"`: Japanese and Chinese write 午前7:05, with the label
        // first and no space. `clock.order` carries that decision per locale.
        return localized("clock.order", time, meridiem)
    }

    /// Renders ASCII digits in the locale's own numbering system, so a Hindi or Arabic
    /// interface shows ٧:٠٥ rather than 7:05 next to otherwise localized text.
    private func localise(_ digitsOnly: String) -> String {
        guard let value = Int(digitsOnly) else { return digitsOnly }
        var style = IntegerFormatStyle<Int>().locale(locale)
        style = style.grouping(.never)
        let formatted = value.formatted(style)
        // Zero-padding has to be reapplied: the number style drops the leading zero.
        guard digitsOnly.count > formatted.count, let zero = locale.zeroDigit else { return formatted }
        return String(repeating: String(zero), count: digitsOnly.count - formatted.count) + formatted
    }
}

private extension Locale {
    /// The locale's own zero, used to pad "5" to "05" in whatever numbering system is active.
    var zeroDigit: Character? {
        0.formatted(IntegerFormatStyle<Int>().locale(self)).first
    }
}

/// "in 7 h 20 min" under an alarm row, and "3 min 12 s" on the stats screen.
enum DurationCopy {
    /// The countdown to the next fire, rounded down to the minute. Deliberately not
    /// `RelativeDateTimeFormatter`: "in 8 hours" hides the 55 minutes that decide whether
    /// the user goes to bed now.
    static func untilNextFire(_ components: DateComponents) -> String {
        let days = components.day ?? 0
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0

        if days > 0 {
            return localized("countdown.days", days, hours)
        }
        if hours > 0 {
            return localized("countdown.hoursMinutes", hours, minutes)
        }
        if minutes > 0 {
            return localized("countdown.minutes", minutes)
        }
        return localized("countdown.imminent")
    }

    /// How long the mission took.
    static func spent(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        if total < 60 { return localized("duration.seconds", total) }
        return localized("duration.minutesSeconds", total / 60, total % 60)
    }
}
