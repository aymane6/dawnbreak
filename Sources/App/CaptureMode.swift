import DawnbreakKit
import Foundation

/// Puts the app into the state the App Store screenshots are taken from.
///
/// The screenshots have to be localized: the store shows a per-language set, and a Japanese
/// listing with English screenshots reads as a machine translation of an app nobody localized.
/// Twelve languages × six screens is seventy-two photographs, so they are taken by a UI test,
/// and a UI test needs three things the app does not normally provide: data on screen worth
/// looking at, no system permission alert appearing mid-shot, and a way to say which screen to
/// open without tapping through a tab bar whose order flips in Arabic.
///
/// Compiled into the shipping binary, deliberately, with no `#if DEBUG`. A Debug-only capture
/// path means the screenshots come from a build that is not the one being submitted, and the
/// layout in the screenshots is a claim about the submitted build. Nothing here runs unless
/// `-dawnbreak-capture` is on the command line, and an installed app has no command line.
enum CaptureMode {
    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains(CaptureLaunch.argument)
    }

    /// The screen the run wants up when launching finishes; the alarm list when nothing said.
    static var screen: CaptureLaunch.Screen {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: CaptureLaunch.screenArgument),
              arguments.indices.contains(flag + 1),
              let screen = CaptureLaunch.Screen(rawValue: arguments[flag + 1]) else { return .alarms }
        return screen
    }

    /// Whether this run wants the free tier. Only the paywall is worth seeing behind one.
    static var isFree: Bool {
        ProcessInfo.processInfo.arguments.contains(CaptureLaunch.freeArgument)
    }

    // MARK: - Environment

    /// The environment the app root runs on: the real one, or a seeded throwaway.
    @MainActor
    static func makeEnvironment() -> AppEnvironment {
        guard isActive else { return AppEnvironment() }

        // Under caches rather than the support directory: the run must not touch alarms that
        // are already on the device, and must not inherit the previous run's data either, which
        // is why the directory is removed rather than reused.
        let directory = URL.cachesDirectory.appending(path: "Capture", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: directory)

        // Removed before the suite is opened, because `Preferences` reads every value in its
        // initialiser: clearing afterwards would leave the instance holding the old ones.
        UserDefaults.standard.removePersistentDomain(forName: CaptureLaunch.defaultsSuite)
        let defaults = UserDefaults(suiteName: CaptureLaunch.defaultsSuite) ?? .standard

        // Pinned either way, so no run of this depends on a StoreKit transaction being present:
        // `.pro` unlocks every screen the listing shows, `.free` is what the paywall needs behind
        // it. Prices are not pinned and cannot be: `PaywallView` asks StoreKit for them when it
        // opens, which is why the one screenshot that needs them is taken from inside the app by
        // `ReviewShotTests` rather than from out here.
        let entitlement: Entitlement = isFree ? .free : .pro
        let environment = AppEnvironment(directory: directory, defaults: defaults, entitlement: entitlement)
        seed(environment)
        return environment
    }

    @MainActor
    private static func seed(_ environment: AppEnvironment) {
        let (alarms, records) = demoData()
        for alarm in alarms {
            environment.alarms.upsert(alarm)
        }
        for record in records {
            environment.log.append(record)
        }

        environment.preferences.hasCompletedOnboarding = screen != .onboarding
        // Otherwise the paywall could open itself over a screenshot of something else.
        environment.preferences.hasSeenPaywall = true
        environment.selectedTab = tab

        // The pending mission lives in the shared container, outside the scratch directory,
        // because an App Intent in another process has to be able to write it. Cleared on every
        // capture launch so a run that wanted the mission screen cannot leave it up for the run
        // after it.
        PendingMissionStore.clear()
        if screen == .mission {
            PendingMissionStore.save(ringingMission(for: alarms[0]))
        }
    }

    private static var tab: AppEnvironment.Tab {
        switch screen {
        case .stats: .stats
        case .settings: .settings
        case .alarms, .editor, .mission, .onboarding: .alarms
        }
    }

    /// The alarm that is ringing on the mission screenshot, silenced.
    ///
    /// `MissionRunnerView` starts the tone and the haptics on appear, and it is right to: the
    /// alarm is ringing. A capture run has no user to wake, so the copy it photographs is muted
    /// rather than the audio being made conditional on a launch argument.
    private static func ringingMission(for alarm: AlarmDraft) -> PendingMission {
        var silent = alarm
        silent.volume = 0
        silent.vibrate = false
        let calendar = Calendar.autoupdatingCurrent
        let scheduled = calendar.date(bySettingHour: silent.hour, minute: silent.minute, second: 0, of: Date()) ?? Date()
        return PendingMission(alarm: silent, scheduledFor: scheduled)
    }

    // MARK: - Demo data

    /// Everything a capture run puts on screen.
    ///
    /// Not private, and assembled here rather than in `seed`, because `DawnbreakTests` checks it:
    /// a listing whose screenshot claims a nine-morning streak under a record of eleven has to be
    /// photographed from a log that genuinely computes to those two numbers. Which alarm the
    /// weekday records belong to is decided once, here, instead of in both places.
    static func demoData() -> (alarms: [AlarmDraft], records: [WakeRecord]) {
        let alarms = demoAlarms()
        return (alarms, demoRecords(weekday: alarms[0], weekend: alarms[2]))
    }

    /// Fixed ids so a rerun writes the same file, and so a failing screenshot can be traced to
    /// the alarm it was taken from.
    private enum ID {
        static let run = UUID(uuidString: "DA000001-0000-4000-A000-000000000001")!
        static let work = UUID(uuidString: "DA000002-0000-4000-A000-000000000002")!
        static let walk = UUID(uuidString: "DA000003-0000-4000-A000-000000000003")!
        static let flight = UUID(uuidString: "DA000004-0000-4000-A000-000000000004")!
    }

    /// A fixed creation date per alarm, an hour apart, rather than `Date()`.
    ///
    /// `AlarmStore.byTime` breaks a tie on `createdAt`, so four alarms stamped inside the same
    /// millisecond are four alarms in an order that depends on how fast the phone is. These four
    /// have distinct times and would not tie, but the value is also written into the store's JSON,
    /// and a capture run that writes a different file every time is a capture run whose output
    /// cannot be compared with the last one's.
    private static func created(_ index: Int) -> Date {
        Date(timeIntervalSince1970: 1_735_689_600 + Double(index) * 3600)
    }

    /// One id per morning, derived from how long ago it was, for the same reason.
    private static func recordID(_ daysAgo: Int) -> UUID {
        UUID(uuidString: String(format: "DA00%04X-0000-4000-A000-%012X", daysAgo, daysAgo)) ?? UUID()
    }

    /// Four alarms: two on the weekday schedule, one for the weekend, and one switched off.
    ///
    /// The labels are localized, which is the whole point of a localized screenshot. A French
    /// listing whose alarm still says "Morning run" tells the reader the app was translated by
    /// a script, and they are not wrong to think so.
    private static func demoAlarms() -> [AlarmDraft] {
        [
            AlarmDraft(
                id: ID.run,
                hour: 6, minute: 15,
                label: localized("capture.label.run"),
                repeatDays: .weekdays,
                mission: MissionConfig(kind: .math, difficulty: .medium, rounds: 3),
                soundName: AlarmSound.sunrise.rawValue,
                gentleWakeSeconds: 45,
                createdAt: created(0)
            ),
            AlarmDraft(
                id: ID.work,
                hour: 7, minute: 0,
                label: localized("capture.label.work"),
                repeatDays: .weekdays,
                mission: MissionConfig(kind: .typing, difficulty: .hard, rounds: 1),
                soundName: AlarmSound.radar.rawValue,
                createdAt: created(1)
            ),
            AlarmDraft(
                id: ID.walk,
                hour: 8, minute: 30,
                label: localized("capture.label.walk"),
                repeatDays: .weekend,
                mission: MissionConfig(kind: .steps, difficulty: .medium, rounds: 1),
                soundName: AlarmSound.birdsong.rawValue,
                gentleWakeSeconds: 90,
                createdAt: created(2)
            ),
            AlarmDraft(
                id: ID.flight,
                hour: 5, minute: 40,
                label: localized("capture.label.flight"),
                isEnabled: false,
                mission: MissionConfig(kind: .shake, difficulty: .hard, rounds: 2),
                soundName: AlarmSound.klaxon.rawValue,
                snooze: .off,
                createdAt: created(3)
            ),
        ]
    }

    /// Forty-five mornings, one per day, oldest first.
    ///
    /// Enough that the 30-day chart is full and the 90-day one is not empty. The four misses are
    /// placed by hand rather than sprinkled: the nearest one is nine days back, and there is an
    /// eleven-day run behind it, so the screenshot shows a streak of nine under a record of
    /// eleven. A column of nothing but wins would be a nicer number and would read as invented.
    private static func demoRecords(weekday: AlarmDraft, weekend: AlarmDraft) -> [WakeRecord] {
        let calendar = Calendar.autoupdatingCurrent
        let misses: Set<Int> = [9, 21, 34, 41]
        /// What the user was doing on a weekday, cycled. Rotating the mission is what gives the
        /// "by mission" section on the stats screen more than one row to draw.
        let weekdayMissions: [(kind: MissionKind, difficulty: Difficulty)] = [
            (.math, .medium), (.math, .medium), (.typing, .hard),
            (.math, .medium), (.breathe, .easy), (.math, .hard), (.typing, .medium),
        ]

        return (0...44).reversed().compactMap { daysAgo -> WakeRecord? in
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) else { return nil }
            let isWeekend = calendar.isDateInWeekend(day)
            let alarm = isWeekend ? weekend : weekday
            let mission = isWeekend
                ? (kind: MissionKind.steps, difficulty: Difficulty.medium)
                : weekdayMissions[daysAgo % weekdayMissions.count]
            guard let scheduled = calendar.date(bySettingHour: alarm.hour, minute: alarm.minute, second: 0, of: day) else {
                return nil
            }

            let snoozes = daysAgo.isMultiple(of: 6) && daysAgo > 0 ? 1 : 0
            let dodges = daysAgo % 11 == 4 ? 1 : 0
            // Deterministic rather than random: the same phone, photographed twice, should not
            // report two different averages.
            let seconds = TimeInterval(38 + (daysAgo * 17) % 88)
            let snoozeDelay = TimeInterval(snoozes * alarm.snooze.minutes * 60)

            if misses.contains(daysAgo) {
                return WakeRecord(
                    id: recordID(daysAgo),
                    alarmID: alarm.id,
                    scheduledFor: scheduled,
                    dismissedAt: scheduled.addingTimeInterval(240),
                    outcome: .bailedOut,
                    mission: mission.kind,
                    difficulty: mission.difficulty,
                    dodgeCount: dodges
                )
            }

            return WakeRecord(
                id: recordID(daysAgo),
                alarmID: alarm.id,
                scheduledFor: scheduled,
                dismissedAt: scheduled.addingTimeInterval(snoozeDelay + seconds),
                outcome: snoozes > 0 ? .completedAfterSnoozes : .completed,
                mission: mission.kind,
                difficulty: mission.difficulty,
                secondsToDismiss: seconds,
                snoozeCount: snoozes,
                dodgeCount: dodges
            )
        }
    }
}
