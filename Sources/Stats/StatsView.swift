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

    enum Window: Int, CaseIterable, Identifiable {
        case week = 7
        case month = 30
        case quarter = 90

        var id: Int { rawValue }
        var titleKey: String { "stats.window.\(rawValue)" }
    }

    /// The window actually charted, which is not always the one selected: a subscription that
    /// lapses while ninety days are on screen has to fall back rather than keep showing them.
    /// Computed instead of clamped on appear so there is no moment where it is stale.
    private var effectiveWindow: Window {
        window.rawValue <= app.entitlement.maximumHistoryDays ? window : .week
    }

    private var stats: WakeStats {
        app.log.stats(window: effectiveWindow.rawValue)
    }

    /// Selecting a locked window raises the paywall and leaves the selection alone, which is the
    /// same gate the alarm limit and the harder difficulties go through.
    private var selection: Binding<Window> {
        Binding(
            get: { effectiveWindow },
            set: { option in
                guard app.allow(.history(option.rawValue)) else { return }
                window = option
            }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                let stats = stats
                VStack(spacing: 16) {
                    if stats.totalWakes == 0 {
                        EmptyStatsCard()
                    } else {
                        headline(stats)
                        streakCard(stats)
                        outcomeChart(stats)
                        wakeTimeChart(stats)
                        missionTable(stats)
                        honestyCard(stats)
                    }
                }
                .padding(.horizontal, Theme.Metric.gutter)
                .padding(.bottom, 28)
            }
            .scrollBounceBehavior(.basedOnSize)
            .dawnCanvas()
            .navigationTitle(Text("tab.stats", bundle: .main))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Picker(selection: selection) {
                        ForEach(Window.allCases) { option in
                            // The lock is on the option rather than hiding it, so a free user can
                            // see that ninety days exist. Hidden options sell nothing.
                            if option.rawValue <= app.entitlement.maximumHistoryDays {
                                Text(key: option.titleKey).tag(option)
                            } else {
                                Label {
                                    Text(key: option.titleKey)
                                } icon: {
                                    Image(systemName: "lock.fill")
                                }
                                .tag(option)
                            }
                        }
                    } label: {
                        Text("stats.window", bundle: .main)
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.accent)
                    .accessibilityIdentifier(AccessibilityID.statsWindow)
                }
            }
        }
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
                value: averageWakeText(stats),
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

                    BarMark(
                        x: .value(localized("stats.axis.day"), point.date, unit: .day),
                        y: .value(localized("stats.axis.misses"), -point.losses)
                    )
                    .foregroundStyle(Theme.danger.opacity(0.85))
                    .cornerRadius(3)
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
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: effectiveWindow == .week ? 1 : 7)) { _ in
                        AxisGridLine().foregroundStyle(Theme.hairline.opacity(0.5))
                        // `.narrow` so a 90-day window does not overlap its own labels in
                        // languages with long month names.
                        AxisValueLabel(format: .dateTime.day().month(.narrow))
                    }
                }
                .frame(height: 150)
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
                    .chartYAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { value in
                            AxisGridLine().foregroundStyle(Theme.hairline)
                            AxisValueLabel {
                                if let minutes = value.as(Double.self) {
                                    Text(clock.digits(hour: Int(minutes) / 60 % 24, minute: Int(minutes) % 60))
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: effectiveWindow == .week ? 1 : 7)) { _ in
                            AxisGridLine().foregroundStyle(Theme.hairline.opacity(0.5))
                            AxisValueLabel(format: .dateTime.day().month(.narrow))
                        }
                    }
                    .frame(height: 150)
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

    private var clock: ClockFormatter {
        ClockFormatter(uses24Hour: app.preferences.usesTwentyFourHourClock)
    }

    private func averageWakeText(_ stats: WakeStats) -> String {
        guard let minutes = stats.averageWakeMinuteOfDay else { return "—" }
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
    var body: some View {
        Card {
            VStack(spacing: 10) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 34))
                    .foregroundStyle(Theme.dawnGradient)
                Text("stats.empty.title", bundle: .main)
                    .font(Theme.headlineFont)
                    .foregroundStyle(Theme.textPrimary)
                Text("stats.empty.body", bundle: .main)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        }
        .padding(.top, 40)
    }
}
