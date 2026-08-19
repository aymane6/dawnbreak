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
    /// Average clock time of a successful dismissal, as minutes past midnight. Averaging
    /// clock times naively is wrong across midnight, so this uses the circular mean.
    public var averageWakeMinuteOfDay: Double?
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
        averageSecondsToDismiss: nil, averageWakeMinuteOfDay: nil,
        totalSnoozes: 0, totalDodges: 0, byMission: [:], daily: []
    )

    /// - Parameters:
    ///   - records: the whole log; order does not matter.
    ///   - window: how many days the daily series covers, ending on `now`'s day.
    ///   - now: injected so the tests do not depend on the machine clock.
    public static func compute(
        from records: [WakeRecord],
        window: Int = 30,
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> WakeStats {
        guard !records.isEmpty else { return withEmptyDays(window: window, now: now, calendar: calendar) }

        var stats = WakeStats.empty
        stats.totalWakes = records.count

        var dismissDurations: [Double] = []
        // Circular mean: each wake time becomes a unit vector on the 24h circle and the
        // vectors are summed. This is what makes 23:50 and 00:10 average to midnight
        // rather than to noon.
        var sinSum = 0.0, cosSum = 0.0, angleCount = 0
        var tallies: [MissionKind: (attempts: Int, wins: Int, seconds: [Double])] = [:]
        /// Day-of-win set, keyed by the start of the local day, for the streak walk.
        var winDays = Set<Date>()
        var perDay: [Date: (wins: Int, losses: Int, minutes: [Double])] = [:]

        for record in records {
            let day = calendar.startOfDay(for: record.scheduledFor)
            var tally = tallies[record.mission] ?? (0, 0, [])
            tally.attempts += 1

            stats.totalSnoozes += record.snoozeCount
            stats.totalDodges += record.dodgeCount

            var bucket = perDay[day] ?? (0, 0, [])

            if record.outcome.isWin {
                stats.wins += 1
                tally.wins += 1
                winDays.insert(day)
                bucket.wins += 1

                if let seconds = record.secondsToDismiss {
                    dismissDurations.append(seconds)
                    tally.seconds.append(seconds)
                }
                if let dismissedAt = record.dismissedAt {
                    let parts = calendar.dateComponents([.hour, .minute], from: dismissedAt)
                    let minuteOfDay = Double((parts.hour ?? 0) * 60 + (parts.minute ?? 0))
                    let angle = minuteOfDay / 1440 * 2 * .pi
                    sinSum += sin(angle); cosSum += cos(angle); angleCount += 1
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
        if angleCount > 0 {
            // atan2 handles the quadrant; the modulo brings a negative angle back onto 0…2π.
            var mean = atan2(sinSum / Double(angleCount), cosSum / Double(angleCount))
            if mean < 0 { mean += 2 * .pi }
            stats.averageWakeMinuteOfDay = mean / (2 * .pi) * 1440
        }

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
