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

    @Test("Nothing in the screenshots is padlocked")
    func everythingSeededIsUnlocked() {
        // The capture run pins `.pro`, and these are the alarms it photographs. Four alarms is
        // already past the free limit of one, so a run that lost its pinned entitlement would
        // photograph a paywall instead of an alarm list.
        #expect(data.alarms.count > Entitlement.free.maximumAlarms)
        for alarm in data.alarms {
            #expect(Entitlement.pro.allows(alarm.mission.kind))
            #expect(Entitlement.pro.allows(alarm.mission.difficulty))
            #expect(alarm.mission.rounds <= Entitlement.pro.maximumRounds)
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
        // The record run sits at 33 to 22 mornings ago, outside the thirty-day chart, which is the
        // other thing these two numbers pin down: `window` scopes the bars, not the streaks.
        #expect(stats.currentStreak == 9)
        #expect(stats.bestStreak == 12)
        #expect(stats.wins == 41)
        #expect(stats.totalWakes == 45)
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

        let wake = try #require(stats.averageWakeMinuteOfDay)
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
        #expect(CaptureLaunch.Screen.alarms.fileStem == "01-alarms")
        #expect(CaptureLaunch.Screen.onboarding.fileStem == "06-onboarding")
        #expect(Set(CaptureLaunch.Screen.allCases.map(\.fileStem)).count == CaptureLaunch.Screen.allCases.count)
    }

    @Test("A capture run is off unless it is asked for")
    func captureIsOffByDefault() {
        // The test host is launched without the flag, which is the same state an installed app is
        // always in: it has no command line at all.
        #expect(!CaptureMode.isActive)
    }
}
