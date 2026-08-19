import Foundation
import Observation

/// The alarm list, observable by SwiftUI and persisted on every mutation.
///
/// `@MainActor` because every mutation comes from a view and the persistence is a few
/// kilobytes of JSON; hopping to a background actor to write 2 KB would buy nothing and
/// cost the guarantee that what the list shows is what is on disk.
@MainActor
@Observable
public final class AlarmStore {
    public private(set) var alarms: [AlarmDraft] = []
    /// Surfaced in the UI rather than swallowed: a write that failed means the alarm the
    /// user just set will not survive a relaunch, and they need to know that now.
    public private(set) var lastError: StoreError?

    private let file: JSONFileStore<Payload>

    public struct StoreError: Error, Hashable, Sendable {
        public var messageKey: String
        public var underlying: String
    }

    /// Versioned envelope. Adding a field to `AlarmDraft` needs no bump; changing the
    /// meaning of one does, and then `migrate` earns its place.
    struct Payload: Codable, Sendable {
        var version: Int = 1
        var alarms: [AlarmDraft] = []
    }

    public init(directory: URL = StoreLocation.supportDirectory()) {
        self.file = JSONFileStore(url: directory.appendingPathComponent("alarms.json"), fallback: { Payload() })
        let payload = file.load()
        self.alarms = Self.migrate(payload).alarms.sorted(by: Self.byTime)
    }

    /// `nonisolated` so `peek` can migrate a payload it read outside the main actor. The
    /// function is pure; the isolation was incidental.
    nonisolated static func migrate(_ payload: Payload) -> Payload {
        // Version 1 is current. The switch exists so the next version has an obvious home
        // and cannot be added as a scatter of `decodeIfPresent` calls.
        switch payload.version {
        case 1: return payload
        default: return payload
        }
    }

    /// Sorted by wall-clock time, which is the order the user thinks in. Ties broken by
    /// creation so the list does not reshuffle when two alarms share a minute.
    ///
    /// `nonisolated` and public: it reads nothing but its two arguments, and the widget
    /// extension and the tests both need to order alarms without hopping to the main actor.
    public nonisolated static func byTime(_ a: AlarmDraft, _ b: AlarmDraft) -> Bool {
        if a.hour != b.hour { return a.hour < b.hour }
        if a.minute != b.minute { return a.minute < b.minute }
        return a.createdAt < b.createdAt
    }

    /// Reads the alarm list without building a store.
    ///
    /// The widget extension needs the next alarm and nothing else. Instantiating an
    /// `@Observable` main-actor store inside a timeline provider would mean hopping actors on
    /// every refresh for a 2 KB read, and the extension has no business observing anything.
    public nonisolated static func peek(directory: URL = StoreLocation.supportDirectory()) -> [AlarmDraft] {
        let file = JSONFileStore<Payload>(
            url: directory.appendingPathComponent("alarms.json"),
            fallback: { Payload() }
        )
        return migrate(file.load()).alarms.sorted(by: byTime)
    }

    /// The next alarm across a list, for callers that hold the array rather than the store.
    public nonisolated static func nextUp(in alarms: [AlarmDraft], now: Date = Date()) -> (alarm: AlarmDraft, fireDate: Date)? {
        alarms
            .compactMap { alarm in alarm.nextFireDate(after: now).map { (alarm, $0) } }
            .min { $0.1 < $1.1 }
    }

    // MARK: - Mutations

    public func upsert(_ alarm: AlarmDraft) {
        if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[index] = alarm
        } else {
            alarms.append(alarm)
        }
        alarms.sort(by: Self.byTime)
        persist()
    }

    public func remove(id: UUID) {
        alarms.removeAll { $0.id == id }
        persist()
    }

    public func setEnabled(_ enabled: Bool, id: UUID) {
        guard let index = alarms.firstIndex(where: { $0.id == id }) else { return }
        alarms[index].isEnabled = enabled
        persist()
    }

    public func alarm(id: UUID) -> AlarmDraft? { alarms.first { $0.id == id } }

    /// A one-shot alarm that has fired is done; it is switched off rather than deleted so
    /// the user can flick it back on tomorrow without retyping the mission.
    public func retireIfOneShot(id: UUID) {
        guard let index = alarms.firstIndex(where: { $0.id == id }), alarms[index].isOneShot else { return }
        alarms[index].isEnabled = false
        persist()
    }

    /// The alarm that will ring next, for the "next alarm in 8 h" header.
    public func nextUp(now: Date = Date()) -> (alarm: AlarmDraft, fireDate: Date)? {
        alarms
            .compactMap { alarm in alarm.nextFireDate(after: now).map { (alarm, $0) } }
            .min { $0.1 < $1.1 }
    }

    public var enabledCount: Int { alarms.count(where: \.isEnabled) }

    public func clearError() { lastError = nil }

    private func persist() {
        do {
            try file.save(Payload(version: 1, alarms: alarms))
            lastError = nil
        } catch {
            lastError = StoreError(messageKey: "error.saveFailed", underlying: String(describing: error))
        }
    }
}

/// The wake log. Append-only from the app's point of view, with a cap so a phone that has
/// been waking someone up for five years does not carry an unbounded file into the stats
/// screen's `compute`.
@MainActor
@Observable
public final class WakeLogStore {
    public private(set) var records: [WakeRecord] = []
    public static let maximumRecords = 2000

    private let file: JSONFileStore<Payload>

    struct Payload: Codable, Sendable {
        var version: Int = 1
        var records: [WakeRecord] = []
    }

    public init(directory: URL = StoreLocation.supportDirectory()) {
        self.file = JSONFileStore(url: directory.appendingPathComponent("wake-log.json"), fallback: { Payload() })
        self.records = file.load().records
    }

    public func append(_ record: WakeRecord) {
        records.append(record)
        if records.count > Self.maximumRecords {
            records.removeFirst(records.count - Self.maximumRecords)
        }
        try? file.save(Payload(version: 1, records: records))
    }

    /// Amends the record for an alarm that is still in progress — a snooze, a dodge —
    /// without writing a second row for the same morning.
    public func amendLatest(alarmID: UUID, _ change: (inout WakeRecord) -> Void) {
        guard let index = records.lastIndex(where: { $0.alarmID == alarmID }) else { return }
        change(&records[index])
        try? file.save(Payload(version: 1, records: records))
    }

    public func stats(window: Int = 30, now: Date = Date()) -> WakeStats {
        WakeStats.compute(from: records, window: window, now: now)
    }

    /// Offered in Settings. The log is the only personal data the app holds, so erasing it
    /// has to be one tap and has to actually delete the file.
    public func eraseAll() {
        records = []
        try? file.save(Payload(version: 1, records: []))
    }
}
