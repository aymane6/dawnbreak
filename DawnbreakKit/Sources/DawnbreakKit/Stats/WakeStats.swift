import Foundation

/// Everything the stats screen shows, computed from the wake log in one pass.
///
/// A struct rather than a set of methods on the store: the screen needs all of it at once,
/// and computing it together means the calendar is consulted once per record instead of
/// once per metric.
public struct WakeStats: Hashable, Sendable {
    public var totalWakes: Int
    public var wins: Int
    public var currentStreak: Int
    public var bestStreak: Int
    /// Seconds, averaged over records that were actually cleared.
    public var averageSecondsToDismiss: Double?
    /// The clock time a successful dismissal usually happens at, as minutes past midnight: the
    /// median of the cleared mornings, measured round the clock. The median, because most logs
    /// hold two kinds of morning: weekdays at 6:15 and weekends at 8:30 averaged to 6:55, a time
    /// that log never once got up at, under a label that says "usual". Round the clock, so 23:50
    /// and 00:10 are twenty minutes apart rather than most of a day.
    public var usualWakeMinuteOfDay: Double?
    public var totalSnoozes: Int
    public var totalDodges: Int
    public var byMission: [MissionKind: MissionTally]
    /// One entry per day in the requested window, oldest first, including days with no
    /// alarm so the chart has a continuous x-axis.
    public var daily: [DayPoint]

    public struct MissionTally: Hashable, Sendable {
        public var attempts: Int
        public var wins: Int
        public var averageSeconds: Double?
        public var successRate: Double { attempts == 0 ? 0 : Double(wins) / Double(attempts) }
    }

    public struct DayPoint: Hashable, Sendable, Identifiable {
        public var date: Date
        public var wins: Int
        public var losses: Int
        public var minuteOfDay: Double?
        public var id: Date { date }
        public var hasAlarm: Bool { wins + losses > 0 }
    }

    public var successRate: Double { totalWakes == 0 ? 0 : Double(wins) / Double(totalWakes) }

    public static let empty = WakeStats(
        totalWakes: 0, wins: 0, currentStreak: 0, bestStreak: 0,
        averageSecondsToDismiss: nil, usualWakeMinuteOfDay: nil,
        totalSnoozes: 0, totalDodges: 0, byMission: [:], daily: []
    )

    /// - Parameters:
    ///   - records: the whole log; order does not matter.
    ///   - window: how many days every figure covers, ending on `now`'s day. The streaks are
    ///     the exception and walk the whole log: a run that began before the window is still
    ///     the run, and a record is a record.
    ///   - now: injected so the tests do not depend on the machine clock.
    public static func compute(
        from records: [WakeRecord],
        window: Int = 30,
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> WakeStats {
        guard !records.isEmpty else { return withEmptyDays(window: window, now: now, calendar: calendar) }

        var stats = WakeStats.empty
        let today = calendar.startOfDay(for: now)
        let firstDay = calendar.date(byAdding: .day, value: 1 - max(1, window), to: today) ?? today

        var dismissDurations: [Double] = []
        var wakeMinutes: [Double] = []
        var tallies: [MissionKind: (attempts: Int, wins: Int, seconds: [Double])] = [:]
        /// Day-of-win set, keyed by the start of the local day, for the streak walk.
        var winDays = Set<Date>()
        var perDay: [Date: (wins: Int, losses: Int, minutes: [Double])] = [:]

        for record in records {
            let day = calendar.startOfDay(for: record.scheduledFor)
            if record.outcome.isWin { winDays.insert(day) }
            guard day >= firstDay else { continue }

            stats.totalWakes += 1
            var tally = tallies[record.mission] ?? (0, 0, [])
            tally.attempts += 1

            stats.totalSnoozes += record.snoozeCount
            stats.totalDodges += record.dodgeCount

            var bucket = perDay[day] ?? (0, 0, [])

            if record.outcome.isWin {
                stats.wins += 1
                tally.wins += 1
                bucket.wins += 1

                if let seconds = record.secondsToDismiss {
                    dismissDurations.append(seconds)
                    tally.seconds.append(seconds)
                }
                if let dismissedAt = record.dismissedAt {
                    let parts = calendar.dateComponents([.hour, .minute], from: dismissedAt)
                    let minuteOfDay = Double((parts.hour ?? 0) * 60 + (parts.minute ?? 0))
                    wakeMinutes.append(minuteOfDay)
                    bucket.minutes.append(minuteOfDay)
                }
            } else {
                bucket.losses += 1
            }

            perDay[day] = bucket
            tallies[record.mission] = tally
        }

        if !dismissDurations.isEmpty {
            stats.averageSecondsToDismiss = dismissDurations.reduce(0, +) / Double(dismissDurations.count)
        }
        stats.usualWakeMinuteOfDay = circularMedian(wakeMinutes)

        stats.byMission = tallies.mapValues { tally in
            MissionTally(
                attempts: tally.attempts,
                wins: tally.wins,
                averageSeconds: tally.seconds.isEmpty ? nil : tally.seconds.reduce(0, +) / Double(tally.seconds.count)
            )
        }

        stats.currentStreak = currentStreak(winDays: winDays, now: now, calendar: calendar)
        stats.bestStreak = bestStreak(winDays: winDays, calendar: calendar)
        stats.daily = dailySeries(perDay: perDay, window: window, now: now, calendar: calendar)
        return stats
    }

    // MARK: - Streaks

    /// Counts back from today. Today not yet being a win does not break the streak — the
    /// alarm may not have rung yet — so the walk starts at yesterday in that case.
    static func currentStreak(winDays: Set<Date>, now: Date, calendar: Calendar) -> Int {
        let today = calendar.startOfDay(for: now)
        var cursor = winDays.contains(today) ? today : calendar.date(byAdding: .day, value: -1, to: today)!
        var count = 0
        while winDays.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    static func bestStreak(winDays: Set<Date>, calendar: Calendar) -> Int {
        let sorted = winDays.sorted()
        var best = 0, run = 0
        var previous: Date?
        for day in sorted {
            if let previous, let next = calendar.date(byAdding: .day, value: 1, to: previous), calendar.isDate(next, inSameDayAs: day) {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = day
        }
        return best
    }

    // MARK: - Wake time

    /// The recorded time closest, round the clock, to all the others: a median on a circle,
    /// picked from the times themselves, so it is always a morning that happened. Quadratic, over
    /// at most a quarter of mornings. Sorted first, so a tie, which an even count can produce,
    /// goes to the earlier time on every run.
    static func circularMedian(_ minutes: [Double]) -> Double? {
        let sorted = minutes.sorted()
        let spread = sorted.map { candidate in
            (candidate, sorted.reduce(0) { total, other in total + clockDistance(candidate, other) })
        }
        return spread.min { $0.1 < $1.1 }?.0
    }

    /// Minutes between two times of day, the short way round.
    static func clockDistance(_ first: Double, _ second: Double) -> Double {
        let apart = abs(first - second).truncatingRemainder(dividingBy: 1440)
        return min(apart, 1440 - apart)
    }

    // MARK: - Series

    static func dailySeries(
        perDay: [Date: (wins: Int, losses: Int, minutes: [Double])],
        window: Int,
        now: Date,
        calendar: Calendar
    ) -> [DayPoint] {
        let today = calendar.startOfDay(for: now)
        return (0..<max(1, window)).reversed().compactMap { offset -> DayPoint? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let bucket = perDay[day]
            let minutes = bucket?.minutes ?? []
            return DayPoint(
                date: day,
                wins: bucket?.wins ?? 0,
                losses: bucket?.losses ?? 0,
                minuteOfDay: minutes.isEmpty ? nil : minutes.reduce(0, +) / Double(minutes.count)
            )
        }
    }

    static func withEmptyDays(window: Int, now: Date, calendar: Calendar) -> WakeStats {
        var stats = WakeStats.empty
        stats.daily = dailySeries(perDay: [:], window: window, now: now, calendar: calendar)
        return stats
    }
}
