import Foundation
import Observation

/// App-wide preferences. Small, flat, and backed by `UserDefaults` rather than the JSON
/// store: these are the settings iOS itself may need to read before the store is open.
@MainActor
@Observable
public final class Preferences {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasCompletedOnboarding = defaults.bool(forKey: Key.onboarded)
        self.usesTwentyFourHourClockOverride = defaults.object(forKey: Key.clockOverride) as? Bool
        self.hapticsEnabled = defaults.object(forKey: Key.haptics) as? Bool ?? true
        self.bedtimeReminderEnabled = defaults.bool(forKey: Key.bedtimeOn)
        self.bedtimeHour = defaults.object(forKey: Key.bedtimeHour) as? Int ?? 23
        self.bedtimeMinute = defaults.object(forKey: Key.bedtimeMinute) as? Int ?? 0
        self.sleepGoalHours = defaults.object(forKey: Key.sleepGoal) as? Double ?? 8
        self.emergencyExitEnabled = defaults.object(forKey: Key.emergencyExit) as? Bool ?? true
        self.appearance = Appearance(rawValue: defaults.string(forKey: Key.appearance) ?? "") ?? .dark
    }

    enum Key {
        static let onboarded = "pref.onboarded"
        static let clockOverride = "pref.clock24hOverride"
        static let haptics = "pref.haptics"
        static let bedtimeOn = "pref.bedtimeReminder"
        static let bedtimeHour = "pref.bedtimeHour"
        static let bedtimeMinute = "pref.bedtimeMinute"
        static let sleepGoal = "pref.sleepGoalHours"
        static let emergencyExit = "pref.emergencyExit"
        static let appearance = "pref.appearance"
    }

    /// Dark is the default because the app's main job happens at 06:00 in a dark bedroom.
    /// Light is offered, not forced, and `.system` is there for people who switch.
    public enum Appearance: String, CaseIterable, Sendable, Identifiable {
        case dark, light, system
        public var id: String { rawValue }
        public var titleKey: String { "appearance.\(rawValue)" }
    }

    public var hasCompletedOnboarding: Bool { didSet { defaults.set(hasCompletedOnboarding, forKey: Key.onboarded) } }
    /// `nil` means follow the region. Some people want the 24h clock on an en-US phone.
    public var usesTwentyFourHourClockOverride: Bool? {
        didSet { defaults.set(usesTwentyFourHourClockOverride, forKey: Key.clockOverride) }
    }
    public var hapticsEnabled: Bool { didSet { defaults.set(hapticsEnabled, forKey: Key.haptics) } }
    public var bedtimeReminderEnabled: Bool { didSet { defaults.set(bedtimeReminderEnabled, forKey: Key.bedtimeOn) } }
    public var bedtimeHour: Int { didSet { defaults.set(bedtimeHour, forKey: Key.bedtimeHour) } }
    public var bedtimeMinute: Int { didSet { defaults.set(bedtimeMinute, forKey: Key.bedtimeMinute) } }
    public var sleepGoalHours: Double { didSet { defaults.set(sleepGoalHours, forKey: Key.sleepGoal) } }
    /// The escape hatch on the mission screen. On by default and never removable: an alarm
    /// app that can trap a user with a broken camera in a screen they cannot leave is an
    /// App Review rejection and, more to the point, indefensible.
    public var emergencyExitEnabled: Bool { didSet { defaults.set(emergencyExitEnabled, forKey: Key.emergencyExit) } }
    public var appearance: Appearance { didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) } }

    /// Whether to draw times as 24-hour, honouring the override and otherwise the region.
    public var usesTwentyFourHourClock: Bool {
        if let usesTwentyFourHourClockOverride { return usesTwentyFourHourClockOverride }
        return Self.regionPrefers24Hour()
    }

    /// Asks the locale rather than guessing from the language: en-GB is 24-hour, en-US is
    /// not, and both are "en".
    ///
    /// `nonisolated` because the widget extension calls it: it has no access to the app's
    /// `UserDefaults` and so has no `Preferences` instance, and its Live Activity views are
    /// not main-actor isolated.
    public nonisolated static func regionPrefers24Hour(locale: Locale = .autoupdatingCurrent) -> Bool {
        let format = Date.FormatStyle(date: .omitted, time: .shortened).locale(locale)
        return !Date(timeIntervalSince1970: 0).formatted(format).contains(where: { $0.isLetter })
            || locale.hourCycle == .zeroToTwentyThree || locale.hourCycle == .oneToTwentyFour
    }

    /// The bedtime that hits the sleep goal for a given wake time, so the reminder can say
    /// "sleep by 22:40 to get 8 h".
    public func suggestedBedtime(forWakeAt wake: Date, calendar: Calendar = .autoupdatingCurrent) -> Date? {
        calendar.date(byAdding: .minute, value: -Int(sleepGoalHours * 60), to: wake)
    }
}
