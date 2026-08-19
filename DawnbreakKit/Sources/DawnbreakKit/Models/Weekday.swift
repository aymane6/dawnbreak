import Foundation

/// The seven weekdays, stored as the ISO-8601 number so the JSON on disk survives a
/// change of `Locale.Weekday`'s internal representation and can be compared across
/// devices in different regions.
public enum Weekday: Int, Codable, Hashable, Sendable, CaseIterable, Comparable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    public static func < (lhs: Weekday, rhs: Weekday) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Monday-first vs Sunday-first is a regional choice, and getting it wrong makes the
    /// weekday picker feel foreign. `Calendar.firstWeekday` is 1 for Sunday.
    public static func ordered(firstWeekday: Int) -> [Weekday] {
        let all = Weekday.allCases
        // firstWeekday 1 = Sunday, 2 = Monday, ... mapped onto our Monday = 1 scale.
        let startISO = firstWeekday == 1 ? 7 : firstWeekday - 1
        guard let start = all.firstIndex(where: { $0.rawValue == startISO }) else { return all }
        return Array(all[start...] + all[..<start])
    }

    /// The `Calendar` component value, which counts Sunday as 1.
    public var calendarWeekday: Int { self == .sunday ? 1 : rawValue + 1 }

    public init?(calendarWeekday: Int) {
        switch calendarWeekday {
        case 1: self = .sunday
        case 2...7: self = Weekday(rawValue: calendarWeekday - 1)!
        default: return nil
        }
    }

    /// Key into the string catalog. Kept explicit rather than interpolated so a
    /// `grep` for the key in the catalog finds it.
    public var localizationKey: String {
        switch self {
        case .monday: "weekday.monday"
        case .tuesday: "weekday.tuesday"
        case .wednesday: "weekday.wednesday"
        case .thursday: "weekday.thursday"
        case .friday: "weekday.friday"
        case .saturday: "weekday.saturday"
        case .sunday: "weekday.sunday"
        }
    }

    public var shortLocalizationKey: String { localizationKey + ".short" }
}

public extension Set<Weekday> {
    static var weekdays: Set<Weekday> { [.monday, .tuesday, .wednesday, .thursday, .friday] }
    static var weekend: Set<Weekday> { [.saturday, .sunday] }
    static var everyDay: Set<Weekday> { Set(Weekday.allCases) }

    /// The label the alarm row shows under the time: "Every day", "Weekdays",
    /// "Weekends", "Never", or the short day names.
    var repeatSummaryKey: String? {
        if isEmpty { return "repeat.never" }
        if self == .everyDay { return "repeat.everyDay" }
        if self == .weekdays { return "repeat.weekdays" }
        if self == .weekend { return "repeat.weekends" }
        return nil
    }
}
