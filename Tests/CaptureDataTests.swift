import DawnbreakKit
import Foundation
import Testing
@testable import Dawnbreak

/// The App Store screenshots are a claim about the app, and the numbers in them are a claim about
/// the user in them. `CaptureMode` seeds a log; the stats screen computes what it computes; if the
/// two disagree, the listing shows a streak nobody in the data ever had.
///
/// So these assert the seeded log through the same `WakeStats.compute` the screen calls, rather
/// than trusting the arithmetic in `demoRecords`.
@Suite("Screenshot data")
struct CaptureDataTests {

    private var data: (alarms: [AlarmDraft], records: [WakeRecord]) { CaptureMode.demoData() }

    @Test("Four alarms, one of them switched off")
    func alarmsAreWhatTheScreenshotNeeds() {
        let alarms = data.alarms
        #expect(alarms.count == 4)
        #expect(Set(alarms.map(\.id)).count == 4, "duplicate ids would collapse rows in the list")
        #expect(alarms.count(where: { !$0.isEnabled }) == 1, "one row has to be off, or the toggle reads as decoration")
        // The list sorts by time, so the earliest alarm is the first card of the first screenshot,
        // and a card that is off is a grey one under a header naming another alarm.
        let earliest = alarms.min { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
        #expect(earliest?.isEnabled == true, "the list would open on the alarm that is off")
        #expect(alarms.allSatisfy { !$0.label.isEmpty })
        #expect(Set(alarms.map(\.mission.kind)).count > 1, "the mission chips would all say the same thing")
    }

    @Test("Every alarm label is translated, not left in English")
    func labelsAreLocalized() {
        // `localized(_:)` resolves against whatever language the test host is running in, so this
        // asserts the mechanism: a raw key would come back as itself. The twelve-language coverage
        // is `LocalizationTests`.
        for alarm in data.alarms {
            #expect(!alarm.label.hasPrefix("capture."), "\(alarm.label) is a raw key")
            #expect(!alarm.label.isEmpty)
        }
    }

    /// The listing's first screenshot is the alarm list, and one alarm on it sells nothing: the
    /// point of the shot is that a morning can be built out of several different demands.
    @Test("The photographed alarm list shows several alarms, and no two the same mission")
    func theSeededListLooksLived() {
        #expect(data.alarms.count >= 4)
        let kinds = data.alarms.map(\.mission.kind)
        #expect(Set(kinds).count == kinds.count, "a repeated mission wastes a row of the screenshot")
        for alarm in data.alarms {
            #expect(alarm.mission.rounds >= 1)
            #expect(alarm.mission.rounds <= MissionConfig.maxRounds)
        }
    }

    @Test("Forty-five mornings, four of them lost")
    func logIsTheRightSize() {
        let records = data.records
        #expect(records.count == 45)
        #expect(records.count(where: { $0.outcome.isWin }) == 41)
        let alarmIDs = Set(data.alarms.map(\.id))
        #expect(records.allSatisfy { alarmIDs.contains($0.alarmID) }, "a record pointing at no alarm draws no bar")
    }

    @Test("The streak the screenshot shows is the streak the data holds")
    func streaksMatchTheClaim() {
        let stats = WakeStats.compute(from: data.records, window: 30)
        // Nine now, against a record of twelve. A column of nothing but wins would be a nicer
        // number and would read as invented, which is worse than a smaller true one.
        //
        // The record run sits at 33 to 22 mornings ago, outside the thirty-day window, which is the
        // other thing these numbers pin down: `window` scopes the figures, not the streaks. Of
        // the thirty mornings it does hold, two are the misses nine and twenty-one days back.
        #expect(stats.currentStreak == 9)
        #expect(stats.bestStreak == 12)
        #expect(stats.wins == 28)
        #expect(stats.totalWakes == 30)
        #expect(stats.successRate > 0.9)
    }

    @Test("The stats screen has something in every card")
    func nothingOnTheStatsScreenIsEmpty() throws {
        let stats = WakeStats.compute(from: data.records, window: 30)
        #expect(stats.byMission.count >= 3, "the by-mission table needs more than one row to be worth a screenshot")
        #expect(stats.totalSnoozes > 0, "the honesty card reads as a placeholder at zero")
        #expect(stats.totalDodges > 0)

        let average = try #require(stats.averageSecondsToDismiss)
        #expect((45...180).contains(Int(average)), "\(Int(average))s is not a believable mission")

        let wake = try #require(stats.usualWakeMinuteOfDay)
        #expect((5 * 60...9 * 60).contains(Int(wake)), "the usual wake time landed at \(Int(wake)) minutes past midnight")
    }

    @Test("The daily chart has no gap in the last thirty days")
    func chartIsContinuous() {
        let stats = WakeStats.compute(from: data.records, window: 30)
        #expect(stats.daily.count == 30)
        // A hole in the middle of the bar chart is what a reader notices first, and it is what a
        // log seeded only on weekdays produces. Filtered rather than `allSatisfy`, so a failure
        // says how many days are missing instead of only that one is.
        let gaps = stats.daily.filter { !$0.hasAlarm }
        #expect(gaps.isEmpty, "\(gaps.count) of the thirty days have no alarm")
    }

    @Test("Two runs of the same build seed the same numbers")
    func seedingIsDeterministic() {
        // Photographed twice, the phone has to report the same averages. Anything random in here
        // means the twelve languages disagree with each other about the same user.
        let first = CaptureMode.demoData()
        let second = CaptureMode.demoData()
        #expect(first.alarms == second.alarms, "including createdAt, which decides the row order")
        #expect(first.records.map(\.id) == second.records.map(\.id))
        #expect(first.records.map(\.outcome) == second.records.map(\.outcome))
        #expect(first.records.map(\.secondsToDismiss) == second.records.map(\.secondsToDismiss))
        // The statistics rather than the raw records: `scheduledFor` is built from "now", and
        // comparing two instants taken microseconds apart would test the clock, not the seed.
        #expect(WakeStats.compute(from: first.records) == WakeStats.compute(from: second.records))
    }

    @Test("Every screen the listing needs has a launch argument")
    func everyScreenIsReachable() {
        // Six screens, six screenshots, and the file names come from this enum rather than from a
        // list in the test, so adding a screen cannot leave a gap in the numbering.
        #expect(CaptureLaunch.Screen.allCases.count == 6)
        #expect(CaptureLaunch.Screen.mission.fileStem == "01-mission")
        #expect(CaptureLaunch.Screen.settings.fileStem == "06-settings")
        // The three a search result shows, in the order `Screen` gives its reasons for.
        #expect(Array(CaptureLaunch.Screen.allCases.prefix(3)) == [.mission, .alarms, .onboarding])
        #expect(Set(CaptureLaunch.Screen.allCases.map(\.fileStem)).count == CaptureLaunch.Screen.allCases.count)
    }

    @Test("A capture run is off unless it is asked for")
    func captureIsOffByDefault() {
        // The test host is launched without the flag, which is the same state an installed app is
        // always in: it has no command line at all.
        #expect(!CaptureMode.isActive)
    }
}
