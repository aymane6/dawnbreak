import Foundation
import Testing
@testable import DawnbreakKit

private var utcCalendar: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}

private func day(_ string: String) -> Date {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    formatter.timeZone = TimeZone(identifier: "UTC")!
    return formatter.date(from: string)!
}

private func record(
    _ scheduled: String,
    dismissed: String? = nil,
    outcome: WakeRecord.Outcome = .completed,
    mission: MissionKind = .math,
    seconds: TimeInterval? = 40,
    snoozes: Int = 0,
    dodges: Int = 0
) -> WakeRecord {
    WakeRecord(
        alarmID: UUID(),
        scheduledFor: day(scheduled),
        dismissedAt: dismissed.map(day) ?? (outcome.isWin ? day(scheduled) : nil),
        outcome: outcome,
        mission: mission,
        difficulty: .medium,
        secondsToDismiss: outcome.isWin ? seconds : nil,
        snoozeCount: snoozes,
        dodgeCount: dodges
    )
}

@Suite("Wake statistics")
struct WakeStatsTests {

    @Test("An empty log still produces a full daily series for the chart")
    func emptyLog() {
        let stats = WakeStats.compute(from: [], window: 30, now: day("2026-03-10 09:00"), calendar: utcCalendar)
        #expect(stats.totalWakes == 0)
        #expect(stats.successRate == 0)
        #expect(stats.daily.count == 30)
        #expect(stats.daily.allSatisfy { !$0.hasAlarm })
        // Oldest first, so the chart's x-axis reads left to right.
        #expect(stats.daily.first!.date < stats.daily.last!.date)
    }

    @Test("Success rate counts wins over attempts")
    func successRate() {
        let records = [
            record("2026-03-08 07:00"),
            record("2026-03-09 07:00", outcome: .bailedOut),
            record("2026-03-10 07:00", outcome: .completedAfterSnoozes, snoozes: 2)
        ]
        let stats = WakeStats.compute(from: records, window: 7, now: day("2026-03-10 09:00"), calendar: utcCalendar)
        #expect(stats.totalWakes == 3)
        #expect(stats.wins == 2)
        #expect(abs(stats.successRate - 2.0 / 3.0) < 0.0001)
        #expect(stats.totalSnoozes == 2)
    }

    @Test("A streak counts consecutive winning days")
    func streak() {
        let records = (8...10).map { record("2026-03-0\($0) 07:00") }
        let stats = WakeStats.compute(from: records, window: 30, now: day("2026-03-10 09:00"), calendar: utcCalendar)
        #expect(stats.currentStreak == 3)
        #expect(stats.bestStreak == 3)
    }

    /// The alarm has not rung yet today. Yesterday's streak must still show, otherwise the
    /// number a user built over three weeks reads as zero every morning until they wake up.
    @Test("Today having no alarm yet does not reset the streak")
    func streakSurvivesUnrungToday() {
        let records = [record("2026-03-08 07:00"), record("2026-03-09 07:00")]
        let stats = WakeStats.compute(from: records, window: 30, now: day("2026-03-10 03:00"), calendar: utcCalendar)
        #expect(stats.currentStreak == 2)
    }

    @Test("A missed day breaks the current streak but not the best one")
    func brokenStreak() {
        let records = [
            record("2026-03-01 07:00"), record("2026-03-02 07:00"), record("2026-03-03 07:00"),
            // 03-04 missed
            record("2026-03-09 07:00"), record("2026-03-10 07:00")
        ]
        let stats = WakeStats.compute(from: records, window: 30, now: day("2026-03-10 09:00"), calendar: utcCalendar)
        #expect(stats.currentStreak == 2)
        #expect(stats.bestStreak == 3)
    }

    @Test("A losing day does not count towards the streak")
    func lossBreaksStreak() {
        let records = [
            record("2026-03-08 07:00"),
            record("2026-03-09 07:00", outcome: .interrupted),
            record("2026-03-10 07:00")
        ]
        let stats = WakeStats.compute(from: records, window: 30, now: day("2026-03-10 09:00"), calendar: utcCalendar)
        #expect(stats.currentStreak == 1)
        #expect(stats.bestStreak == 1)
    }

    /// The reason `averageWakeMinuteOfDay` is a circular mean: 23:50 and 00:10 average to
    /// midnight, not to 12:00. A naive arithmetic mean gets this exactly 12 hours wrong,
    /// and "your average wake time is 12:00" on a 6am alarm is a visible, embarrassing bug.
    @Test("Wake times either side of midnight average to midnight")
    func circularMeanAcrossMidnight() throws {
        let records = [
            record("2026-03-09 23:50", dismissed: "2026-03-09 23:50"),
            record("2026-03-10 00:10", dismissed: "2026-03-10 00:10")
        ]
        let stats = WakeStats.compute(from: records, window: 7, now: day("2026-03-10 09:00"), calendar: utcCalendar)
        let average = try #require(stats.averageWakeMinuteOfDay)
        // Within a minute of midnight, from either side.
        #expect(min(average, 1440 - average) < 1.0)
    }

    @Test("A normal spread of morning wake times averages sensibly")
    func circularMeanMornings() throws {
        let records = [
            record("2026-03-08 06:30", dismissed: "2026-03-08 06:30"),
            record("2026-03-09 07:00", dismissed: "2026-03-09 07:00"),
            record("2026-03-10 07:30", dismissed: "2026-03-10 07:30")
        ]
        let stats = WakeStats.compute(from: records, window: 7, now: day("2026-03-10 09:00"), calendar: utcCalendar)
        let average = try #require(stats.averageWakeMinuteOfDay)
        #expect(abs(average - 420) < 1.0)   // 07:00
    }

    @Test("Average time-to-dismiss ignores the mornings that were never cleared")
    func averageDismissIgnoresLosses() throws {
        let records = [
            record("2026-03-09 07:00", seconds: 30),
            record("2026-03-10 07:00", seconds: 90),
            record("2026-03-10 08:00", outcome: .bailedOut)
        ]
        let stats = WakeStats.compute(from: records, window: 7, now: day("2026-03-10 09:00"), calendar: utcCalendar)
        #expect(try #require(stats.averageSecondsToDismiss) == 60)
    }

    @Test("Per-mission tallies carry their own success rate")
    func perMission() throws {
        let records = [
            record("2026-03-09 07:00", mission: .math),
            record("2026-03-10 07:00", outcome: .bailedOut, mission: .math),
            record("2026-03-10 08:00", mission: .squats)
        ]
        let stats = WakeStats.compute(from: records, window: 7, now: day("2026-03-10 09:00"), calendar: utcCalendar)
        let maths = try #require(stats.byMission[.math])
        #expect(maths.attempts == 2)
        #expect(maths.wins == 1)
        #expect(maths.successRate == 0.5)
        #expect(try #require(stats.byMission[.squats]).successRate == 1)
        #expect(stats.byMission[.flap] == nil)
    }

    @Test("Dodges are counted so the app can say the alarm came back")
    func dodges() {
        let stats = WakeStats.compute(
            from: [record("2026-03-10 07:00", dodges: 3)],
            window: 7, now: day("2026-03-10 09:00"), calendar: utcCalendar
        )
        #expect(stats.totalDodges == 3)
    }

    @Test("The daily series has one entry per day in the window, gaps included")
    func dailySeries() throws {
        let records = [record("2026-03-10 07:00"), record("2026-03-04 07:00", outcome: .bailedOut)]
        let stats = WakeStats.compute(from: records, window: 10, now: day("2026-03-10 09:00"), calendar: utcCalendar)
        #expect(stats.daily.count == 10)
        #expect(stats.daily.filter(\.hasAlarm).count == 2)
        #expect(try #require(stats.daily.last).wins == 1)
        #expect(try #require(stats.daily.first(where: { $0.losses > 0 })).losses == 1)
    }

    @Test("Records older than the window are still counted in the totals")
    func windowDoesNotTruncateTotals() {
        let records = [record("2025-01-01 07:00"), record("2026-03-10 07:00")]
        let stats = WakeStats.compute(from: records, window: 7, now: day("2026-03-10 09:00"), calendar: utcCalendar)
        #expect(stats.totalWakes == 2)      // totals span the whole log
        #expect(stats.daily.count == 7)     // the chart does not
    }

    @Test("Outcomes agree about what counts as a win")
    func outcomeSemantics() {
        #expect(WakeRecord.Outcome.completed.isWin)
        #expect(WakeRecord.Outcome.completedAfterSnoozes.isWin)
        #expect(!WakeRecord.Outcome.bailedOut.isWin)
        #expect(!WakeRecord.Outcome.interrupted.isWin)
    }
}

@Suite("Persistence", .serialized)
struct StoreTests {

    /// Each test gets its own directory so a leftover file cannot make the next one pass.
    private func temporaryDirectory() -> URL {
        let url = URL.temporaryDirectory.appendingPathComponent("dawnbreak-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    struct Box: Codable, Sendable, Equatable { var value: String }

    @Test("A missing file reads as the fallback rather than throwing")
    func missingFile() {
        let store = JSONFileStore(url: temporaryDirectory().appendingPathComponent("none.json"), fallback: { Box(value: "default") })
        #expect(store.load() == Box(value: "default"))
    }

    @Test("A saved value round-trips")
    func roundTrip() throws {
        let store = JSONFileStore(url: temporaryDirectory().appendingPathComponent("box.json"), fallback: { Box(value: "") })
        try store.save(Box(value: "hello"))
        #expect(store.load() == Box(value: "hello"))
    }

    /// The behaviour that matters at 06:00: a truncated file must not crash the app or
    /// throw on launch. It is moved aside and the app opens with defaults.
    @Test("A corrupt file is quarantined and the fallback is returned")
    func corruptFileQuarantined() throws {
        let directory = temporaryDirectory()
        let url = directory.appendingPathComponent("box.json")
        try Data("{ this is not json".utf8).write(to: url)

        let store = JSONFileStore(url: url, fallback: { Box(value: "recovered") })
        #expect(store.load() == Box(value: "recovered"))

        let quarantined = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.contains("corrupt") }
        #expect(quarantined.count == 1)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test("Saving creates the directory if it does not exist")
    func createsDirectory() throws {
        let nested = temporaryDirectory().appendingPathComponent("a/b/c")
        let store = JSONFileStore(url: nested.appendingPathComponent("box.json"), fallback: { Box(value: "") })
        try store.save(Box(value: "deep"))
        #expect(store.load() == Box(value: "deep"))
    }

    @Test("No temporary files are left behind after a save")
    func noTemporaryLeftovers() throws {
        let directory = temporaryDirectory()
        let store = JSONFileStore(url: directory.appendingPathComponent("box.json"), fallback: { Box(value: "") })
        for i in 0..<5 { try store.save(Box(value: "v\(i)")) }
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(files == ["box.json"])
    }

    @MainActor
    @Test("The alarm store sorts by wall-clock time and survives a reopen")
    func alarmStoreRoundTrip() {
        let directory = temporaryDirectory()
        let store = AlarmStore(directory: directory)
        store.upsert(AlarmDraft(hour: 9, minute: 0, label: "late"))
        store.upsert(AlarmDraft(hour: 6, minute: 30, label: "early"))
        store.upsert(AlarmDraft(hour: 6, minute: 15, label: "earliest"))
        #expect(store.alarms.map(\.label) == ["earliest", "early", "late"])
        #expect(store.lastError == nil)

        let reopened = AlarmStore(directory: directory)
        #expect(reopened.alarms.map(\.label) == ["earliest", "early", "late"])
    }

    @MainActor
    @Test("Upserting an existing alarm replaces it instead of duplicating")
    func upsertReplaces() {
        let store = AlarmStore(directory: temporaryDirectory())
        var alarm = AlarmDraft(hour: 7, minute: 0, label: "first")
        store.upsert(alarm)
        alarm.label = "renamed"
        alarm.hour = 8
        store.upsert(alarm)
        #expect(store.alarms.count == 1)
        #expect(store.alarms.first?.label == "renamed")
        #expect(store.alarms.first?.hour == 8)
    }

    @MainActor
    @Test("A fired one-shot alarm is switched off, not deleted")
    func retireOneShot() {
        let store = AlarmStore(directory: temporaryDirectory())
        let oneShot = AlarmDraft(hour: 7, minute: 0)
        let repeating = AlarmDraft(hour: 8, minute: 0, repeatDays: .weekdays)
        store.upsert(oneShot)
        store.upsert(repeating)

        store.retireIfOneShot(id: oneShot.id)
        store.retireIfOneShot(id: repeating.id)

        #expect(store.alarm(id: oneShot.id)?.isEnabled == false)
        #expect(store.alarm(id: repeating.id)?.isEnabled == true)
        #expect(store.alarms.count == 2)
    }

    @MainActor
    @Test("Next-up reports the soonest enabled alarm")
    func nextUp() throws {
        let store = AlarmStore(directory: temporaryDirectory())
        store.upsert(AlarmDraft(hour: 6, minute: 0, label: "six", repeatDays: .everyDay))
        store.upsert(AlarmDraft(hour: 7, minute: 0, label: "seven", repeatDays: .everyDay))
        store.upsert(AlarmDraft(hour: 5, minute: 0, label: "off", repeatDays: .everyDay, isEnabled: false))

        let next = try #require(store.nextUp(now: day("2026-03-10 04:00")))
        #expect(next.alarm.label == "six")
        #expect(store.enabledCount == 2)
    }

    @MainActor
    @Test("The wake log caps itself and keeps the newest records")
    func wakeLogCap() {
        let store = WakeLogStore(directory: temporaryDirectory())
        for i in 0..<(WakeLogStore.maximumRecords + 10) {
            store.append(WakeRecord(alarmID: UUID(), scheduledFor: Date(timeIntervalSince1970: Double(i)), outcome: .completed, mission: .math, difficulty: .easy))
        }
        #expect(store.records.count == WakeLogStore.maximumRecords)
        // The oldest ten were dropped, not the newest.
        #expect(store.records.first?.scheduledFor == Date(timeIntervalSince1970: 10))
    }

    @MainActor
    @Test("Erasing the log empties it on disk too")
    func eraseLog() {
        let directory = temporaryDirectory()
        let store = WakeLogStore(directory: directory)
        store.append(WakeRecord(alarmID: UUID(), scheduledFor: Date(), outcome: .completed, mission: .math, difficulty: .easy))
        store.eraseAll()
        #expect(store.records.isEmpty)
        #expect(WakeLogStore(directory: directory).records.isEmpty)
    }

    @MainActor
    @Test("Amending the latest record for an alarm does not add a row")
    func amendLatest() {
        let store = WakeLogStore(directory: temporaryDirectory())
        let alarmID = UUID()
        store.append(WakeRecord(alarmID: alarmID, scheduledFor: Date(), outcome: .interrupted, mission: .math, difficulty: .easy))
        store.amendLatest(alarmID: alarmID) { $0.snoozeCount += 1; $0.outcome = .completed }
        #expect(store.records.count == 1)
        #expect(store.records.first?.snoozeCount == 1)
        #expect(store.records.first?.outcome == .completed)
    }
}

@Suite("Backwards compatibility")
struct DecodingTests {

    /// A store written by 1.0, opened by a build that has added fields. Every added field
    /// must have a default or the update loses every alarm the user set — which is the
    /// worst possible failure for an alarm app, and silent.
    @Test("An alarm written by an older version still decodes")
    func decodesMinimalPayload() throws {
        let json = """
        { "id": "3B2E1B0C-0000-4000-8000-000000000001", "hour": 7, "minute": 15 }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let alarm = try decoder.decode(AlarmDraft.self, from: Data(json.utf8))
        #expect(alarm.hour == 7)
        #expect(alarm.minute == 15)
        #expect(alarm.isEnabled)                      // defaults, not throws
        #expect(alarm.mission.kind == .math)
        #expect(alarm.snooze.isAllowed)
        #expect(alarm.soundName == AlarmSound.default.rawValue)
    }

    /// Every field survives the round trip. `createdAt` is checked to the millisecond
    /// rather than bit-exactly: the store writes ISO-8601 text so the file can be read by
    /// hand, and no text format carries a `Double`'s full precision. A millisecond is
    /// several orders of magnitude finer than the only thing the field is used for, which
    /// is breaking a sort tie between two alarms set to the same minute.
    @Test("A fully specified alarm round-trips through JSON unchanged")
    func fullRoundTrip() throws {
        let original = AlarmDraft(
            hour: 6, minute: 5, label: "Gym", repeatDays: [.monday, .wednesday, .friday],
            mission: MissionConfig(kind: .barcode, difficulty: .hard, rounds: 2,
                                   enrollment: .init(reference: "5410228142805", displayName: "Cereal box")),
            soundName: AlarmSound.klaxon.rawValue, volume: 0.6, vibrate: false,
            gentleWakeSeconds: 45, snooze: .off, relentless: false
        )
        let data = try JSONFileStore<AlarmDraft>.encoder.encode(original)
        let restored = try JSONFileStore<AlarmDraft>.decoder.decode(AlarmDraft.self, from: data)

        #expect(abs(restored.createdAt.timeIntervalSince(original.createdAt)) < 0.001)

        var normalised = restored
        normalised.createdAt = original.createdAt
        #expect(normalised == original)
    }

    /// Sub-second ordering has to survive a reload, because the alarm list breaks ties on
    /// it. Plain `.iso8601` truncates to the second and would collapse these two.
    @Test("Two alarms created milliseconds apart keep their order after a reload")
    func subSecondOrderSurvives() throws {
        let earlier = AlarmDraft(hour: 7, minute: 0, label: "a", createdAt: Date(timeIntervalSince1970: 1_700_000_000.100))
        let later = AlarmDraft(hour: 7, minute: 0, label: "b", createdAt: Date(timeIntervalSince1970: 1_700_000_000.900))

        let data = try JSONFileStore<[AlarmDraft]>.encoder.encode([later, earlier])
        let restored = try JSONFileStore<[AlarmDraft]>.decoder.decode([AlarmDraft].self, from: data)

        #expect(restored.sorted(by: AlarmStore.byTime).map(\.label) == ["a", "b"])
    }
}
