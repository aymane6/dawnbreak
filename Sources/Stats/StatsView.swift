import Charts
import DawnbreakKit
import SwiftUI

/// What the log says about the last month of mornings.
///
/// Framed as evidence, not as a scoreboard: the numbers that matter are "did you get up" and
/// "how long did it take", because those are the two the app is trying to move.
struct StatsView: View {
    @Environment(\.app) private var app
    @State private var window: Window = .month

    /// Both charts, at one height so they read as a pair. 140 rather than 150: Arabic and Hindi
    /// lines stand taller, and at 150 the second chart's dates sat under the tab bar in the first
    /// screenful of a 6.9-inch phone.
    private static let chartHeight: CGFloat = 140

    enum Window: Int, CaseIterable, Identifiable {
        case week = 7
        case month = 30
        case quarter = 90

        var id: Int { rawValue }
        var titleKey: String { "stats.window.\(rawValue)" }
    }

    private var stats: WakeStats {
        app.log.stats(window: window.rawValue)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                let stats = stats
                VStack(spacing: 16) {
                    if app.log.records.isEmpty {
                        EmptyStatsCard(titleKey: "stats.empty.title", bodyKey: "stats.empty.body")
                            .padding(.top, 40)
                    } else {
                        windowPicker
                        if stats.totalWakes == 0 {
                            // Mornings exist, only not in this period. The first-morning card
                            // would tell someone back from a fortnight away to go and wake up.
                            EmptyStatsCard(titleKey: "stats.emptyWindow.title", bodyKey: "stats.emptyWindow.body")
                        } else {
                            headline(stats)
                            streakCard(stats)
                            outcomeChart(stats)
                            wakeTimeChart(stats)
                            missionTable(stats)
                            honestyCard(stats)
                        }
                    }
                }
                .padding(.horizontal, Theme.Metric.gutter)
                .padding(.bottom, 28)
            }
            .scrollBounceBehavior(.basedOnSize)
            .dawnCanvas()
            .navigationTitle(Text("tab.stats", bundle: .main))
        }
    }

    /// On the screen rather than as a menu in the corner, because it scopes every figure under
    /// it, and a row of three segments says so where a "30 days" in the toolbar did not.
    private var windowPicker: some View {
        Picker(selection: $window) {
            ForEach(Window.allCases) { option in
                Text(key: option.titleKey).tag(option)
            }
        } label: {
            Text("stats.window", bundle: .main)
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier(AccessibilityID.statsWindow)
    }

    // MARK: - Cards

    private func headline(_ stats: WakeStats) -> some View {
        HStack(spacing: 12) {
            MetricTile(
                value: stats.successRate.formatted(.percent.precision(.fractionLength(0))),
                labelKey: "stats.successRate",
                tint: stats.successRate >= 0.8 ? Theme.success : Theme.warning
            )
            MetricTile(
                value: stats.averageSecondsToDismiss.map { DurationCopy.spent($0) } ?? "—",
                labelKey: "stats.averageTime",
                tint: Theme.accent
            )
            MetricTile(
                value: usualWakeText(stats),
                labelKey: "stats.averageWake",
                tint: Theme.dusk
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func streakCard(_ stats: WakeStats) -> some View {
        Card {
            HStack(spacing: 16) {
                ZStack {
                    ProgressRing(fraction: streakFraction(stats), lineWidth: 8)
                        .frame(width: 74, height: 74)
                    VStack(spacing: -2) {
                        Text(stats.currentStreak.formatted(.number.grouping(.never)))
                            .font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(Theme.textPrimary)
                        // The count is passed even though the word does not print it: it is
                        // what picks "день" over "дней" under the same ring.
                        Text(localized("stats.streak.unit", stats.currentStreak))
                            .font(.caption2)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("stats.streak.title", bundle: .main)
                        .font(Theme.headlineFont)
                        .foregroundStyle(Theme.textPrimary)
                    Text(localized("stats.streak.best", stats.bestStreak))
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textSecondary)
                    Text(localized("stats.streak.wins", stats.wins, stats.totalWakes))
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func outcomeChart(_ stats: WakeStats) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(titleKey: "stats.chart.outcomes")
                Chart(stats.daily) { point in
                    BarMark(
                        x: .value(localized("stats.axis.day"), point.date, unit: .day),
                        y: .value(localized("stats.axis.wins"), point.wins)
                    )
                    .foregroundStyle(Theme.success)
                    .cornerRadius(3)
                    // A day without an alarm is not a data point. Left in, VoiceOver read out
                    // thirty zeros to find three mornings.
                    .accessibilityHidden(point.wins == 0)

                    BarMark(
                        x: .value(localized("stats.axis.day"), point.date, unit: .day),
                        y: .value(localized("stats.axis.misses"), -point.losses)
                    )
                    .foregroundStyle(Theme.danger.opacity(0.85))
                    .cornerRadius(3)
                    // Drawn below the axis, spoken as the count it is rather than "minus two".
                    .accessibilityValue(Text(point.losses.formatted(.number.grouping(.never))))
                    .accessibilityHidden(point.losses == 0)
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine().foregroundStyle(Theme.hairline)
                        AxisValueLabel {
                            if let count = value.as(Int.self) {
                                Text(abs(count).formatted(.number.grouping(.never)))
                            }
                        }
                    }
                }
                .chartXScale(domain: periodDomain(stats))
                .chartXAxis { dayAxis }
                .frame(height: Self.chartHeight)
                .accessibilityLabel(Text("stats.chart.outcomes", bundle: .main))

                HStack(spacing: 14) {
                    LegendDot(color: Theme.success, titleKey: "stats.axis.wins")
                    LegendDot(color: Theme.danger, titleKey: "stats.axis.misses")
                }
            }
        }
    }

    @ViewBuilder private func wakeTimeChart(_ stats: WakeStats) -> some View {
        let points = stats.daily.filter { $0.minuteOfDay != nil }
        if points.count > 1 {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(titleKey: "stats.chart.wakeTime")
                    Chart(points) { point in
                        LineMark(
                            x: .value(localized("stats.axis.day"), point.date, unit: .day),
                            y: .value(localized("stats.axis.time"), point.minuteOfDay ?? 0)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(Theme.dawnGradient)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

                        PointMark(
                            x: .value(localized("stats.axis.day"), point.date, unit: .day),
                            y: .value(localized("stats.axis.time"), point.minuteOfDay ?? 0)
                        )
                        .foregroundStyle(Theme.dawnStart)
                        .symbolSize(28)
                    }
                    // Not from zero. Mornings sit within an hour or two of each other, and an
                    // axis that starts at midnight pressed them into one flat line at the top.
                    .chartYScale(domain: wakeDomain(points))
                    .chartYAxis {
                        AxisMarks(values: wakeMarks(points)) { value in
                            AxisGridLine().foregroundStyle(Theme.hairline)
                            AxisValueLabel {
                                if let minutes = value.as(Double.self) {
                                    Text(clock.digits(hour: Int(minutes) / 60 % 24, minute: Int(minutes) % 60))
                                }
                            }
                        }
                    }
                    // The whole period, like the chart above, so a day sits under its own bar.
                    // Left to fit its points, this one started on the first morning in the log
                    // and, at ninety days, drew a month where the chart above drew a quarter.
                    .chartXScale(domain: periodDomain(stats))
                    .chartXAxis { dayAxis }
                    .frame(height: Self.chartHeight)
                    .accessibilityLabel(Text("stats.chart.wakeTime", bundle: .main))
                }
            }
        }
    }

    private func missionTable(_ stats: WakeStats) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(titleKey: "stats.byMission")
                // Ranked by attempts: the mission someone actually uses is the interesting
                // row, not the one they tried once.
                ForEach(stats.byMission.sorted { $0.value.attempts > $1.value.attempts }, id: \.key) { kind, tally in
                    HStack(spacing: 12) {
                        Image(systemName: kind.systemImage)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(key: kind.titleKey)
                                .font(Theme.captionFont)
                                .foregroundStyle(Theme.textPrimary)
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Theme.surfaceRaised)
                                    Capsule()
                                        .fill(tally.successRate >= 0.8 ? AnyShapeStyle(Theme.success) : AnyShapeStyle(Theme.dawnGradient))
                                        .frame(width: proxy.size.width * tally.successRate)
                                }
                            }
                            .frame(height: 6)
                        }

                        Text(localized("stats.mission.tally", tally.wins, tally.attempts))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    /// Snoozes and dodges, shown without euphemism. Hiding them would make the success rate
    /// above look better than the mornings actually were.
    private func honestyCard(_ stats: WakeStats) -> some View {
        Card {
            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text(stats.totalSnoozes.formatted(.number.grouping(.never)))
                        .font(Theme.clock(22))
                        .foregroundStyle(Theme.warning)
                    Text("stats.snoozes", bundle: .main)
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                }
                .frame(maxWidth: .infinity)

                Rectangle().fill(Theme.hairline).frame(width: 1, height: 34)

                VStack(spacing: 2) {
                    Text(stats.totalDodges.formatted(.number.grouping(.never)))
                        .font(Theme.clock(22))
                        .foregroundStyle(Theme.danger)
                    Text("stats.dodges", bundle: .main)
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                }
                .frame(maxWidth: .infinity)
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Helpers

    /// The date axis both charts share, marked for the period. A week names its days, a month
    /// dates its weeks, a quarter names its months. One format for all three either overlapped
    /// itself at ninety days or, as a narrow month, read "S 24" at seven.
    private var dayAxis: some AxisContent {
        AxisMarks(values: dayAxisValues) { _ in
            AxisGridLine().foregroundStyle(Theme.hairline.opacity(0.5))
            // Centred under the day or the month it names. A month's labels stay on their tick,
            // because they date a single day.
            AxisValueLabel(format: dayAxisFormat, centered: window != .month)
        }
    }

    private var dayAxisValues: AxisMarkValues {
        switch window {
        case .week: .stride(by: .day)
        case .month: .stride(by: .day, count: 7)
        case .quarter: .stride(by: .month)
        }
    }

    private var dayAxisFormat: Date.FormatStyle {
        switch window {
        case .week: .dateTime.weekday(.abbreviated)
        case .month: .dateTime.day().month(.abbreviated)
        case .quarter: .dateTime.month(.abbreviated)
        }
    }

    /// From the first day of the period to the end of its last, which is where a bar of the last
    /// day stops.
    private func periodDomain(_ stats: WakeStats) -> ClosedRange<Date> {
        let first = stats.daily.first?.date ?? .now
        let last = stats.daily.last?.date ?? first
        return first...(Calendar.autoupdatingCurrent.date(byAdding: .day, value: 1, to: last) ?? last)
    }

    /// From the hour before the earliest morning to the hour after the latest. Left to itself,
    /// the scale counted in hundreds of minutes and marked the axis 05:00, 06:40, 08:20.
    private func wakeDomain(_ points: [WakeStats.DayPoint]) -> ClosedRange<Double> {
        let minutes = points.compactMap(\.minuteOfDay)
        let low = ((minutes.min() ?? 0) / 60).rounded(.down) * 60
        let high = ((minutes.max() ?? 0) / 60).rounded(.up) * 60
        return low...max(high, low + 60)
    }

    /// On the hour, or every other hour when the mornings spread wider than five.
    private func wakeMarks(_ points: [WakeStats.DayPoint]) -> [Double] {
        let domain = wakeDomain(points)
        let step: Double = domain.upperBound - domain.lowerBound > 300 ? 120 : 60
        return Array(stride(from: domain.lowerBound, through: domain.upperBound, by: step))
    }

    private var clock: ClockFormatter {
        ClockFormatter(uses24Hour: app.preferences.usesTwentyFourHourClock)
    }

    private func usualWakeText(_ stats: WakeStats) -> String {
        guard let minutes = stats.usualWakeMinuteOfDay else { return "—" }
        let total = Int(minutes.rounded())
        return clock.full(hour: total / 60 % 24, minute: total % 60)
    }

    /// A week is the ring's full circle. Beyond that the ring stays full rather than
    /// resetting, because a 30-day streak showing an empty ring would be absurd.
    private func streakFraction(_ stats: WakeStats) -> Double {
        min(1, Double(stats.currentStreak) / 7)
    }
}

private struct MetricTile: View {
    let value: String
    let labelKey: String
    let tint: Color

    var body: some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(tint)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(key: labelKey)
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.Metric.controlRadius))
        .accessibilityElement(children: .combine)
    }
}

private struct LegendDot: View {
    let color: Color
    let titleKey: String

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(key: titleKey)
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
        }
    }
}

private struct EmptyStatsCard: View {
    let titleKey: String
    let bodyKey: String

    var body: some View {
        Card {
            VStack(spacing: 10) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 34))
                    .foregroundStyle(Theme.dawnGradient)
                Text(key: titleKey)
                    .font(Theme.headlineFont)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text(key: bodyKey)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        }
    }
}
