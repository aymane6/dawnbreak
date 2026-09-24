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
    /// The file was there but could not be read, which is what a launch before the first
    /// unlock after a restart looks like. The list is empty only because it is unknown, so
    /// nothing is written and nothing may be reconciled against it until `reloadIfUnread`
    /// gets through.
    public private(set) var isUnread = false

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
        guard let payload = file.loadIfReadable() else {
            isUnread = true
            return
        }
        self.alarms = Self.migrate(payload).alarms.sorted(by: Self.byTime)
    }

    /// Tries again to read a list that could not be read at launch. Cheap when there is
    /// nothing to do, so it is called on every return to the foreground and before every
    /// mutation.
    public func reloadIfUnread() {
        guard isUnread, let payload = file.loadIfReadable() else { return }
        alarms = Self.migrate(payload).alarms.sorted(by: Self.byTime)
        isUnread = false
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
        reloadIfUnread()
        if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[index] = alarm
        } else {
            alarms.append(alarm)
        }
        alarms.sort(by: Self.byTime)
        persist()
    }

    public func remove(id: UUID) {
        reloadIfUnread()
        alarms.removeAll { $0.id == id }
        persist()
    }

    public func setEnabled(_ enabled: Bool, id: UUID) {
        reloadIfUnread()
        guard let index = alarms.firstIndex(where: { $0.id == id }) else { return }
        alarms[index].isEnabled = enabled
        persist()
    }

    public func alarm(id: UUID) -> AlarmDraft? { alarms.first { $0.id == id } }

    /// A one-shot alarm that has fired is done; it is switched off rather than deleted so
    /// the user can flick it back on tomorrow without retyping the mission.
    public func retireIfOneShot(id: UUID) {
        reloadIfUnread()
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
        // Writing now would put a list built without the one on disk in its place.
        guard !isUnread else {
            lastError = StoreError(messageKey: "error.saveFailed", underlying: "the saved alarm list could not be read yet")
            return
        }
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
    /// As on `AlarmStore`: the file could not be read at launch, so `records` holds only
    /// what this process logged since, and writing it would erase the history.
    public private(set) var isUnread = false

    private let file: JSONFileStore<Payload>

    struct Payload: Codable, Sendable {
        var version: Int = 1
        var records: [WakeRecord] = []
    }

    public init(directory: URL = StoreLocation.supportDirectory()) {
        self.file = JSONFileStore(url: directory.appendingPathComponent("wake-log.json"), fallback: { Payload() })
        guard let payload = file.loadIfReadable() else {
            isUnread = true
            return
        }
        self.records = payload.records
    }

    /// Tries again to read a log that could not be read at launch. A morning logged in the
    /// meantime is kept, after the history it belongs at the end of.
    public func reloadIfUnread() {
        guard isUnread, let payload = file.loadIfReadable() else { return }
        let known = Set(payload.records.map(\.id))
        records = payload.records + records.filter { !known.contains($0.id) }
        trimToCap()
        isUnread = false
        save()
    }

    public func append(_ record: WakeRecord) {
        reloadIfUnread()
        records.append(record)
        trimToCap()
        save()
    }

    /// Amends the record for an alarm that is still in progress — a snooze, a dodge —
    /// without writing a second row for the same morning.
    public func amendLatest(alarmID: UUID, _ change: (inout WakeRecord) -> Void) {
        reloadIfUnread()
        guard let index = records.lastIndex(where: { $0.alarmID == alarmID }) else { return }
        change(&records[index])
        save()
    }

    public func stats(window: Int = 30, now: Date = Date()) -> WakeStats {
        WakeStats.compute(from: records, window: window, now: now)
    }

    /// Offered in Settings. The log is the only personal data the app holds, so erasing it
    /// has to be one tap and has to actually delete the file.
    public func eraseAll() {
        records = []
        // Erasing is the one write that needs no history to be right.
        isUnread = false
        save()
    }

    private func trimToCap() {
        guard records.count > Self.maximumRecords else { return }
        records.removeFirst(records.count - Self.maximumRecords)
    }

    private func save() {
        guard !isUnread else {
            NSLog("[Dawnbreak] wake log not written: the saved log could not be read yet")
            return
        }
        try? file.save(Payload(version: 1, records: records))
    }
}
