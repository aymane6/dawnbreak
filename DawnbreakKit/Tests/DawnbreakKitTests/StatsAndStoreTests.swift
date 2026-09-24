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

    /// The reason `usualWakeMinuteOfDay` is measured round the clock: 23:50, 00:05 and 00:10 are
    /// three mornings within twenty minutes, and the middle one is 00:05. Taken as plain numbers
    /// they are 5, 10 and 1430, whose median is 00:10 and whose mean is eight in the morning.
    @Test("Wake times either side of midnight have their middle at midnight")
    func circularMedianAcrossMidnight() throws {
        let records = [
            record("2026-03-08 23:50", dismissed: "2026-03-08 23:50"),
            record("2026-03-09 00:05", dismissed: "2026-03-09 00:05"),
            record("2026-03-10 00:10", dismissed: "2026-03-10 00:10")
        ]
        let stats = WakeStats.compute(from: records, window: 7, now: day("2026-03-10 09:00"), calendar: utcCalendar)
        #expect(try #require(stats.usualWakeMinuteOfDay) == 5)
    }

    @Test("A normal spread of morning wake times has its middle in the middle")
    func circularMedianMornings() throws {
        let records = [
            record("2026-03-08 06:30", dismissed: "2026-03-08 06:30"),
            record("2026-03-09 07:00", dismissed: "2026-03-09 07:00"),
            record("2026-03-10 07:30", dismissed: "2026-03-10 07:30")
        ]
        let stats = WakeStats.compute(from: records, window: 7, now: day("2026-03-10 09:00"), calendar: utcCalendar)
        #expect(try #require(stats.usualWakeMinuteOfDay) == 420)   // 07:00
    }

    /// Why it is a median at all. Five weekdays at 6:15 and a weekend at 8:30 have a mean of
    /// 6:54, which is not a time that week ever got up at.
    @Test("A week of early weekdays and a late weekend usually gets up early")
    func usualWakeIsNotTheMean() throws {
        let weekdays = ["03", "04", "05", "06", "09"].map { record("2026-03-\($0) 06:15") }
        let weekend = ["07", "08"].map { record("2026-03-\($0) 08:30") }
        let stats = WakeStats.compute(from: weekdays + weekend, window: 7, now: day("2026-03-09 09:00"), calendar: utcCalendar)
        #expect(try #require(stats.usualWakeMinuteOfDay) == 375)   // 06:15
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

    /// The period is the whole screen's, not the chart's. When the totals spanned the log, "7
    /// days" redrew the chart under a success rate that did not move, which reads as a picker
    /// that does nothing.
    @Test("The window scopes every figure")
    func windowScopesTheFigures() {
        let records = [
            record("2026-02-01 07:00", outcome: .bailedOut, mission: .squats, snoozes: 2, dodges: 1),
            record("2026-03-08 07:00"), record("2026-03-09 07:00"), record("2026-03-10 07:00"),
        ]
        let stats = WakeStats.compute(from: records, window: 7, now: day("2026-03-10 09:00"), calendar: utcCalendar)
        #expect(stats.totalWakes == 3)
        #expect(stats.successRate == 1)
        #expect(stats.totalSnoozes == 0)
        #expect(stats.totalDodges == 0)
        #expect(stats.byMission[.squats] == nil)
        #expect(stats.daily.count == 7)
    }

    /// The window's first day is inside it: seven days ending today is today and the six before.
    @Test("The window's edges are the days it names")
    func windowEdges() {
        let records = [record("2026-03-03 23:59", outcome: .bailedOut), record("2026-03-04 00:00")]
        let stats = WakeStats.compute(from: records, window: 7, now: day("2026-03-10 09:00"), calendar: utcCalendar)
        #expect(stats.totalWakes == 1)
        #expect(stats.wins == 1)
    }

    @Test("A streak that began before the window is counted whole")
    func streakOutlivesTheWindow() {
        let records = (1...10).map { record(String(format: "2026-03-%02d 07:00", $0)) }
        let stats = WakeStats.compute(from: records, window: 7, now: day("2026-03-10 09:00"), calendar: utcCalendar)
        #expect(stats.totalWakes == 7)
        #expect(stats.currentStreak == 10)
        #expect(stats.bestStreak == 10)
    }

    @Test("A log with nothing in the window reads as an empty window, not an empty log")
    func emptyWindow() {
        let stats = WakeStats.compute(from: [record("2026-01-10 07:00")], window: 7, now: day("2026-03-10 09:00"), calendar: utcCalendar)
        #expect(stats.totalWakes == 0)
        #expect(stats.daily.count == 7)
        #expect(stats.daily.allSatisfy { !$0.hasAlarm })
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

    /// Stands in for the data-protection class, which keeps the files closed after a
    /// restart until the phone is first unlocked. Mode 000 fails the read the same way and
    /// still lets the directory be renamed into, so a write that should not happen would.
    private func makeUnreadable(_ url: URL) throws {
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: url.path)
    }

    private func makeReadable(_ url: URL) throws {
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
    }

    @Test("A file that cannot be read yet is left in place, not quarantined")
    func unreadableFileLeftInPlace() throws {
        let directory = temporaryDirectory()
        let url = directory.appendingPathComponent("box.json")
        let store = JSONFileStore(url: url, fallback: { Box(value: "fallback") })
        try store.save(Box(value: "kept"))
        try makeUnreadable(url)
        defer { try? makeReadable(url) }

        #expect(store.loadIfReadable() == nil)
        #expect(store.load() == Box(value: "fallback"))
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["box.json"])

        try makeReadable(url)
        #expect(store.loadIfReadable() == Box(value: "kept"))
    }

    /// The morning this protects: the phone restarted for an update at 03:00, the alarm
    /// rings at 06:00 and its Stop button launches the app before anyone has unlocked it.
    @MainActor
    @Test("An alarm list that cannot be read yet is never written over, and loads once it can be")
    func unreadableAlarmListSurvives() throws {
        let directory = temporaryDirectory()
        let url = directory.appendingPathComponent("alarms.json")
        AlarmStore(directory: directory).upsert(AlarmDraft(hour: 6, minute: 30, label: "kept"))
        try makeUnreadable(url)
        defer { try? makeReadable(url) }

        let early = AlarmStore(directory: directory)
        #expect(early.isUnread)
        #expect(early.alarms.isEmpty)
        early.upsert(AlarmDraft(hour: 9, minute: 0, label: "written blind"))
        #expect(early.lastError?.messageKey == "error.saveFailed")

        try makeReadable(url)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["alarms.json"])
        #expect(AlarmStore(directory: directory).alarms.map(\.label) == ["kept"])

        early.reloadIfUnread()
        #expect(!early.isUnread)
        #expect(early.alarms.map(\.label) == ["kept"])
    }

    @MainActor
    @Test("A wake log that cannot be read yet keeps its history and the morning logged meanwhile")
    func unreadableWakeLogMerges() throws {
        let directory = temporaryDirectory()
        let url = directory.appendingPathComponent("wake-log.json")
        let older = WakeRecord(alarmID: UUID(), scheduledFor: Date(timeIntervalSince1970: 1), outcome: .completed, mission: .math, difficulty: .easy)
        WakeLogStore(directory: directory).append(older)
        try makeUnreadable(url)
        defer { try? makeReadable(url) }

        let early = WakeLogStore(directory: directory)
        #expect(early.isUnread)
        let meanwhile = WakeRecord(alarmID: UUID(), scheduledFor: Date(timeIntervalSince1970: 2), outcome: .completed, mission: .math, difficulty: .easy)
        early.append(meanwhile)

        try makeReadable(url)
        #expect(WakeLogStore(directory: directory).records.map(\.id) == [older.id])

        early.reloadIfUnread()
        #expect(!early.isUnread)
        #expect(early.records.map(\.id) == [older.id, meanwhile.id])
        #expect(WakeLogStore(directory: directory).records.map(\.id) == [older.id, meanwhile.id])
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
        #expect(alarm.followOns.isEmpty)              // pre-chain stores carry no follow-ons
    }

    @Test("A follow-on chain survives the round trip, and its delay is clamped on the way in")
    func followOnsRoundTripAndClamp() throws {
        let original = AlarmDraft(
            hour: 6, minute: 0,
            mission: MissionConfig(kind: .math, difficulty: .hard),
            followOns: [
                FollowOnMission(mission: MissionConfig(kind: .shake, difficulty: .hard), minutesAfter: 10),
                FollowOnMission(mission: MissionConfig(kind: .steps, difficulty: .hard), minutesAfter: 999),
            ]
        )
        #expect(original.followOns[1].minutesAfter == FollowOnMission.maximumMinutes,
                "an out-of-range delay was stored as typed")

        let data = try JSONFileStore<AlarmDraft>.encoder.encode(original)
        let restored = try JSONFileStore<AlarmDraft>.decoder.decode(AlarmDraft.self, from: data)
        #expect(restored.followOns == original.followOns)
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
