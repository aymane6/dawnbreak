import Foundation

/// The app's own alarm record.
///
/// AlarmKit owns the *scheduling*; this owns everything AlarmKit has no field for — the
/// mission, the label, the snooze policy, the sound choice — and it is the copy that
/// survives a reinstall of the alarm in the system. The `id` is shared with
/// `AlarmKit.Alarm.ID` so the two can be joined without a side table.
public struct AlarmDraft: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    /// Local wall-clock hour and minute. Never a `Date`: an alarm is "07:00 wherever I
    /// wake up", so storing an instant would move it when the user crosses a timezone.
    public var hour: Int
    public var minute: Int
    public var label: String
    public var repeatDays: Set<Weekday>
    public var isEnabled: Bool
    public var mission: MissionConfig
    public var soundName: String
    /// 0…1, applied to our own player. AlarmKit's own alert respects the system volume,
    /// which is the point of it: this only scales the in-app mission-screen audio.
    public var volume: Double
    public var vibrate: Bool
    /// Ramp the in-app volume from silence to `volume` over this many seconds. 0 = off.
    public var gentleWakeSeconds: Int
    public var snooze: SnoozePolicy
    /// Re-arm the alarm this many minutes later if the mission screen is abandoned. This
    /// is the "it rings again if you dodge the mission" behaviour.
    public var relentless: Bool
    public var createdAt: Date

    public struct SnoozePolicy: Codable, Hashable, Sendable {
        public var isAllowed: Bool
        public var minutes: Int
        /// After this many snoozes the button disappears. `nil` = unlimited.
        public var maxCount: Int?

        public init(isAllowed: Bool = true, minutes: Int = 9, maxCount: Int? = 3) {
            self.isAllowed = isAllowed
            self.minutes = max(1, min(minutes, 30))
            self.maxCount = maxCount.map { max(1, $0) }
        }

        public static let off = SnoozePolicy(isAllowed: false, minutes: 9, maxCount: nil)
    }

    public init(
        id: UUID = UUID(),
        hour: Int = 7,
        minute: Int = 0,
        label: String = "",
        repeatDays: Set<Weekday> = [],
        isEnabled: Bool = true,
        mission: MissionConfig = .default,
        soundName: String = AlarmSound.default.rawValue,
        volume: Double = 0.9,
        vibrate: Bool = true,
        gentleWakeSeconds: Int = 0,
        snooze: SnoozePolicy = SnoozePolicy(),
        relentless: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
        self.label = label
        self.repeatDays = repeatDays
        self.isEnabled = isEnabled
        self.mission = mission
        self.soundName = soundName
        self.volume = min(max(volume, 0), 1)
        self.vibrate = vibrate
        self.gentleWakeSeconds = max(0, min(gentleWakeSeconds, 300))
        self.snooze = snooze
        self.relentless = relentless
        self.createdAt = createdAt
    }

    /// Decoding is written by hand for the fields added after 1.0 so an old store on disk
    /// still opens. A `Codable` synthesised init throws on any missing key, which would
    /// mean an update that silently loses every alarm the user set.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        hour = try c.decode(Int.self, forKey: .hour)
        minute = try c.decode(Int.self, forKey: .minute)
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        repeatDays = try c.decodeIfPresent(Set<Weekday>.self, forKey: .repeatDays) ?? []
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        mission = try c.decodeIfPresent(MissionConfig.self, forKey: .mission) ?? .default
        soundName = try c.decodeIfPresent(String.self, forKey: .soundName) ?? AlarmSound.default.rawValue
        volume = try c.decodeIfPresent(Double.self, forKey: .volume) ?? 0.9
        vibrate = try c.decodeIfPresent(Bool.self, forKey: .vibrate) ?? true
        gentleWakeSeconds = try c.decodeIfPresent(Int.self, forKey: .gentleWakeSeconds) ?? 0
        snooze = try c.decodeIfPresent(SnoozePolicy.self, forKey: .snooze) ?? SnoozePolicy()
        relentless = try c.decodeIfPresent(Bool.self, forKey: .relentless) ?? true
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    // MARK: - Derived

    /// The next time this alarm should fire, or `nil` if it is off.
    ///
    /// Uses `Calendar.nextDate` rather than day arithmetic so the DST transitions are the
    /// calendar's problem: on the spring-forward morning a 02:30 alarm has no valid
    /// instant, and `nextDate` skips to the next day that does.
    public func nextFireDate(after now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> Date? {
        guard isEnabled else { return nil }
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        components.second = 0

        if repeatDays.isEmpty {
            return calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime)
        }
        return repeatDays
            .compactMap { day -> Date? in
                var c = components
                c.weekday = day.calendarWeekday
                return calendar.nextDate(after: now, matching: c, matchingPolicy: .nextTime)
            }
            .min()
    }

    /// "in 8 h 25 min" copy for the row under the time.
    public func timeUntilNextFire(from now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> DateComponents? {
        guard let next = nextFireDate(after: now, calendar: calendar) else { return nil }
        return calendar.dateComponents([.day, .hour, .minute], from: now, to: next)
    }

    public var isOneShot: Bool { repeatDays.isEmpty }
}

/// The bundled alarm tones. Raw values are the filenames without extension, and are the
/// same strings passed to AlarmKit's `AlertConfiguration.AlertSound.named(_:)`.
public enum AlarmSound: String, Codable, CaseIterable, Sendable, Identifiable {
    case sunrise, radar, klaxon, marimba, cascade, bellhop, siren, birdsong

    public var id: String { rawValue }
    public static let `default` = AlarmSound.sunrise
    public var titleKey: String { "sound.\(rawValue)" }
    /// Two are deliberately gentle; the editor sorts them first for people who want to be
    /// woken rather than startled.
    public var isGentle: Bool { self == .sunrise || self == .birdsong || self == .marimba }
}
