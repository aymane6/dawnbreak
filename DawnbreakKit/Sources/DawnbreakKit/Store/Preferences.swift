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
    }

    enum Key {
        static let onboarded = "pref.onboarded"
        static let clockOverride = "pref.clock24hOverride"
        static let haptics = "pref.haptics"
    }

    public var hasCompletedOnboarding: Bool { didSet { defaults.set(hasCompletedOnboarding, forKey: Key.onboarded) } }
    /// `nil` means follow the region. Some people want the 24h clock on an en-US phone.
    public var usesTwentyFourHourClockOverride: Bool? {
        didSet { defaults.set(usesTwentyFourHourClockOverride, forKey: Key.clockOverride) }
    }
    public var hapticsEnabled: Bool { didSet { defaults.set(hapticsEnabled, forKey: Key.haptics) } }

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
}
