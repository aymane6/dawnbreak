import DawnbreakKit
import Foundation
import Testing
@testable import Dawnbreak

/// The bug this suite was written for, in the words of the person who found it: "je l'ai arrêté,
/// y a rien qui s'est passé, ça s'est arrêté, j'ai rien vu, j'ai pas vu de challenge, et ça n'a
/// pas resonné."
///
/// The alarm rang, stop was pressed, and the app did nothing at all: no mission screen, and no
/// second ring. A stop button that stops the alarm makes every mission in the app decorative.
///
/// Three separate faults could each produce that on their own, so all three are held down here:
/// the re-arm ran after the mission was opened and was skipped whenever opening it failed; the
/// re-arm needed the store to answer for the id, which an alarm deleted or a cold-launched intent
/// cannot promise; and nothing at all noticed the mission screen going away with the mission
/// still owed.
/// `.serialized` because `PendingMissionStore` is a single file in the shared container and is
/// deliberately not injectable: it is read by an App Intent, by the app and potentially by the
/// widget, and none of them should own an instance the others cannot see. Two of these tests
/// running at once would be two of them writing that file.
@MainActor
@Suite("Mission handoff", .serialized)
struct MissionHandoffTests {

    /// A bridge with a store of its own, in a directory of its own.
    ///
    /// `PendingMissionStore` is deliberately not injectable — it is read by an App Intent, by the
    /// app and potentially by the widget, and none of them should own an instance the others
    /// cannot see — so it is the one piece of shared state here, and every test starts by
    /// clearing it.
    private static func bridge(
        with alarm: AlarmDraft?,
        system: FakeAlarmSystem = FakeAlarmSystem(),
        in directory: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("handoff-\(UUID().uuidString)", isDirectory: true)
    ) -> (AlarmBridge, AlarmStore) {
        PendingMissionStore.clear()
        let store = AlarmStore(directory: directory)
        if let alarm { store.upsert(alarm) }
        let bridge = AlarmBridge(system: system)
        bridge.attach(alarms: store, log: WakeLogStore(directory: directory))
        return (bridge, store)
    }

    private static func draft(relentless: Bool = true, repeatDays: Set<Weekday> = []) -> AlarmDraft {
        AlarmDraft(hour: 6, minute: 30, repeatDays: repeatDays, mission: .default, relentless: relentless)
    }

    // MARK: - Stop

    @Test("Pressing stop opens the mission and brings the alarm back")
    func stopOpensTheMissionAndRearms() async {
        let alarm = Self.draft()
        let system = FakeAlarmSystem()
        let (bridge, _) = Self.bridge(with: alarm, system: system)

        await bridge.handleStopPressed(alarmID: alarm.id)

        #expect(bridge.activeMission?.alarmID == alarm.id, "no mission was opened")
        #expect(system.calls == [.cancel(alarm.id), .followUp(alarm.id)], "the alarm was not re-armed")
        #expect(system.lastFollowUpDelay == AlarmBridge.relentlessDelay)
    }

    @Test("The alarm comes back even when the alarm itself has been deleted")
    func stopRearmsWithoutAStoreEntry() async {
        // The alarm rang, then was deleted from the list while it was ringing — or the intent
        // cold-launched the app and the store answered before it had finished loading. Either
        // way the handoff on disk holds everything the follow-up needs, and used to be ignored:
        // the re-arm looked the alarm up in the store, found nothing, and returned.
        let alarm = Self.draft()
        let system = FakeAlarmSystem()
        let (bridge, store) = Self.bridge(with: alarm, system: system)
        await bridge.handleMissionRequested(alarmID: alarm.id)
        store.remove(id: alarm.id)

        await bridge.handleStopPressed(alarmID: alarm.id)

        #expect(bridge.activeMission?.alarmID == alarm.id)
        #expect(system.calls.contains(.followUp(alarm.id)))
        #expect(system.lastFollowUpDelay == AlarmBridge.relentlessDelay)
    }

    @Test("Stopping twice keeps re-arming, and counts both dodges")
    func repeatedDodgesKeepRearming() async {
        let alarm = Self.draft()
        let system = FakeAlarmSystem()
        let (bridge, _) = Self.bridge(with: alarm, system: system)

        await bridge.handleStopPressed(alarmID: alarm.id)
        await bridge.handleStopPressed(alarmID: alarm.id)

        #expect(system.calls.filter { $0 == .followUp(alarm.id) }.count == 2)
        #expect(bridge.activeMission?.dodgeCount == 2)
        #expect(bridge.armedIDs == [alarm.id], "the second dodge left nothing armed")
    }

    @Test("A stop for an id nothing knows about clears the handoff instead of arming a stray alarm")
    func stopForAnUnknownAlarmDoesNothing() async {
        let system = FakeAlarmSystem()
        let (bridge, _) = Self.bridge(with: nil, system: system)

        await bridge.handleStopPressed(alarmID: UUID())

        #expect(bridge.activeMission == nil)
        #expect(system.calls.isEmpty)
        #expect(PendingMissionStore.load() == nil)
    }

    @Test("An alarm the user asked not to be insistent is not brought back")
    func stopHonoursTheRelentlessSetting() async {
        let alarm = Self.draft(relentless: false)
        let system = FakeAlarmSystem()
        let (bridge, _) = Self.bridge(with: alarm, system: system)

        await bridge.handleStopPressed(alarmID: alarm.id)

        // The mission still opens: the setting is about the alarm coming back, not about
        // whether there is anything to do.
        #expect(bridge.activeMission?.alarmID == alarm.id)
        #expect(system.calls.isEmpty)
    }

    /// The other half of that setting, and it was missing.
    ///
    /// `handleStopPressed` honoured `relentless`, and then the mission screen undid it: opening
    /// the screen pushes the follow-up out and leaving it brings the alarm straight back, and
    /// neither asked whether this alarm was allowed to come back at all. A user who switched
    /// insistence off got a ring three minutes later anyway, and another five seconds after the
    /// screen was dismissed. The setting held only while the app never came forward.
    @Test("A non-insistent alarm is not re-armed by the mission screen either")
    func theMissionScreenHonoursTheRelentlessSetting() async {
        let alarm = Self.draft(relentless: false)
        let system = FakeAlarmSystem()
        let (bridge, _) = Self.bridge(with: alarm, system: system)
        await bridge.handleStopPressed(alarmID: alarm.id)

        await bridge.missionInProgress()
        await bridge.missionLeftUnfinished()

        #expect(system.followUpDates.isEmpty, "an alarm told not to insist came back anyway")
        #expect(system.calls.isEmpty)
        // And the mission is still owed: not coming back is not the same as never having asked.
        #expect(PendingMissionStore.loadIfFresh()?.alarmID == alarm.id)
    }

    /// Snooze from the mission screen. The screen has to come down, and it has to stay down for
    /// the length of the snooze: `activeMission` stayed set, so the cover stayed up with the
    /// audio stopped — nothing appeared to happen — and the runner holds `isIdleTimerDisabled`,
    /// so the display stayed lit the whole time.
    @Test("Snoozing puts the mission away until the alarm comes back")
    func snoozeClosesTheMissionUntilItRings() async {
        var alarm = Self.draft()
        alarm.snooze = AlarmDraft.SnoozePolicy(isAllowed: true, minutes: 9, maxCount: nil)
        alarm.label = "Run"
        let system = FakeAlarmSystem()
        let (bridge, _) = Self.bridge(with: alarm, system: system)
        await bridge.handleStopPressed(alarmID: alarm.id)

        await bridge.handleSnoozePressed(alarmID: alarm.id)

        #expect(bridge.activeMission == nil, "the mission cover would have stayed on screen")
        // Within a second: the fire date is built from `Date()` inside the bridge and read back
        // here, so the interval drifts by however long the test took to get to this line.
        let armedIn = system.lastFollowUpDelay ?? 0
        #expect(abs(armedIn - TimeInterval(9 * 60)) <= 1, "the snooze armed \(armedIn)s out")
        // Still owed, and still armed: the morning is postponed, not over.
        #expect(PendingMissionStore.load()?.snoozeCount == 1)
        #expect(PendingMissionStore.loadIfFresh() == nil, "it must not reopen during the snooze")
        #expect(PendingMissionStore.loadUpcoming()?.alarmID == alarm.id, "reconcile must not touch it")
        #expect(bridge.armedIDs == [alarm.id])
        // A snooze was allowed and asked for, so the alarm comes back as itself, not as the
        // "Mission not done" a dodge earns.
        #expect(system.followUpTitleKeys.last == .some("Run"))
    }

    // MARK: - Walking away

    /// The race both reviewers of this fix landed on, and the only one of them that inverts the
    /// product's promise rather than weakening it: the alarm ringing at somebody who is finished.
    ///
    /// `armFollowUp` suspends across the daemon round trip. If the mission is settled during that
    /// suspension, the arm lands on a morning that is over: the record is gone, the alarm has been
    /// put back on its own schedule, and a one-off follow-up is now sitting on top of it.
    @Test("A follow-up that lands after the mission was settled does not stay armed")
    func aStaleFollowUpStandsItselfDown() async {
        let alarm = Self.draft(repeatDays: [.monday, .wednesday])
        // Settled from underneath, in the middle of the arm.
        let system = FakeAlarmSystem(duringFollowUp: { PendingMissionStore.clear() })
        let (bridge, _) = Self.bridge(with: alarm, system: system)
        // A mission owed on disk with nothing active in this process: the shape of a relaunch
        // that found the screen gone, which is the caller that arms the shortest follow-up.
        PendingMissionStore.save(PendingMission(alarm: alarm, scheduledFor: Date()))

        await bridge.missionLeftUnfinished()

        // Armed, but on its own schedule rather than five seconds out.
        #expect(bridge.armedIDs == [alarm.id])
        #expect(system.calls.last == .schedule(alarm.id), "the alarm was left on the stale follow-up")
        #expect(system.calls.contains(.followUp(alarm.id)), "the follow-up was never armed at all")
    }

    /// The other side of that guard, and the reason it is written as narrowly as it is: an ordinary
    /// dodge must keep its follow-up. The mission is on disk when the arm returns, so nothing is
    /// stood down.
    @Test("An ordinary follow-up is left alone")
    func aLiveFollowUpSurvives() async {
        let alarm = Self.draft()
        let system = FakeAlarmSystem()
        let (bridge, _) = Self.bridge(with: alarm, system: system)

        await bridge.handleStopPressed(alarmID: alarm.id)

        #expect(system.calls.last == .followUp(alarm.id))
        #expect(system.lastFollowUpDelay == AlarmBridge.relentlessDelay)
        #expect(bridge.armedIDs == [alarm.id])
    }
    @Test("Leaving the mission screen with the mission owed brings the alarm back at once")
    func leavingTheMissionRearmsImmediately() async {
        let alarm = Self.draft()
        let system = FakeAlarmSystem()
        let (bridge, _) = Self.bridge(with: alarm, system: system)
        await bridge.handleStopPressed(alarmID: alarm.id)

        await bridge.missionLeftUnfinished()

        #expect(system.lastFollowUpDelay == AlarmBridge.immediateDelay)
        #expect(bridge.armedIDs == [alarm.id])
    }

    @Test("A mission being worked on pushes the alarm out instead of losing it")
    func progressPushesTheFollowUpOut() async {
        let alarm = Self.draft()
        let system = FakeAlarmSystem()
        let (bridge, _) = Self.bridge(with: alarm, system: system)
        await bridge.handleStopPressed(alarmID: alarm.id)
        #expect(system.lastFollowUpDelay == AlarmBridge.relentlessDelay)

        await bridge.missionInProgress()

        #expect(system.lastFollowUpDelay == AlarmBridge.missionEngagedDelay)
        // The part that matters more than the number: something is armed the whole time. A
        // mission screen with no alarm behind it can be escaped by killing the app.
        #expect(bridge.armedIDs == [alarm.id])
    }

    @Test("A relaunch that finds a mission still owed reports it, so the alarm can be brought back")
    func aKilledAppResumesTheMission() async {
        let alarm = Self.draft()
        let system = FakeAlarmSystem()
        let (bridge, _) = Self.bridge(with: alarm, system: system)
        await bridge.handleStopPressed(alarmID: alarm.id)

        // A new process, reading the same handoff off disk.
        let relaunched = AlarmBridge(system: system)
        #expect(relaunched.restorePendingMission() == true, "the mission was not resumed")
        #expect(relaunched.activeMission?.alarmID == alarm.id)

        // And the second call, which is every return to the foreground, is not a new sighting:
        // glancing at Control Center mid-mission is not an escape and must not re-arm.
        #expect(relaunched.restorePendingMission() == false)
    }

    @Test("Nothing is owed once the mission is cleared")
    func completingTheMissionSettlesEverything() async {
        let alarm = Self.draft(repeatDays: [.monday, .tuesday])
        let system = FakeAlarmSystem()
        let (bridge, _) = Self.bridge(with: alarm, system: system)
        await bridge.handleStopPressed(alarmID: alarm.id)
        guard let pending = bridge.activeMission else {
            Issue.record("the mission never opened")
            return
        }

        await bridge.missionCompleted(pending)

        #expect(bridge.activeMission == nil)
        #expect(PendingMissionStore.load() == nil, "a cleared mission left on disk reopens tomorrow")
        // The follow-up is gone and the recurring alarm is back on its own schedule.
        #expect(system.calls.last == .schedule(alarm.id))
        #expect(bridge.armedIDs == [alarm.id])

        // And a relaunch after that has nothing to resume, so nothing rings again.
        #expect(AlarmBridge(system: system).restorePendingMission() == false)
    }

    @Test("A one-shot alarm is retired by finishing its mission, not re-armed")
    func completingAOneShotRetiresIt() async {
        let alarm = Self.draft()
        let system = FakeAlarmSystem()
        let (bridge, store) = Self.bridge(with: alarm, system: system)
        await bridge.handleStopPressed(alarmID: alarm.id)
        guard let pending = bridge.activeMission else {
            Issue.record("the mission never opened")
            return
        }

        await bridge.missionCompleted(pending)

        #expect(store.alarm(id: alarm.id)?.isEnabled == false)
        #expect(bridge.armedIDs.isEmpty)
    }

    @Test("The escape hatch stands the alarm down rather than bringing it back")
    func abandoningStandsTheAlarmDown() async {
        let alarm = Self.draft()
        let system = FakeAlarmSystem()
        let (bridge, _) = Self.bridge(with: alarm, system: system)
        await bridge.handleStopPressed(alarmID: alarm.id)
        guard let pending = bridge.activeMission else {
            Issue.record("the mission never opened")
            return
        }

        await bridge.missionAbandoned(pending)

        #expect(bridge.activeMission == nil)
        #expect(PendingMissionStore.load() == nil)
        #expect(bridge.armedIDs.isEmpty)
    }

    // MARK: - The id that does not survive the trip

    // AppIntents was seen handing `perform()` its parameter as nil on a cold launch — "Failed
    // to fetch metadata for StopAlarmIntent", "Prepared alarmID to String(nil)" — and the old
    // guard turned that into the reported bug in its entirety: button pressed, nothing at all.
    // These hold the fallbacks that stand behind the parameter.

    @Test("A stop whose id did not survive still finds the alarm the system says is ringing")
    func aGarbageHintFallsBackToTheAlertingAlarm() async {
        let alarm = Self.draft()
        let system = FakeAlarmSystem()
        let (bridge, _) = Self.bridge(with: alarm, system: system)
        await bridge.schedule(alarm)
        system.startAlerting(alarm.id)

        await bridge.handleStopPressed(hint: "")

        #expect(bridge.activeMission?.alarmID == alarm.id, "the ringing alarm was not resolved")
        #expect(system.calls.contains(.followUp(alarm.id)), "the resolved alarm was not re-armed")
    }

    @Test("With nothing alerting, the owed mission on disk answers for the id")
    func aGarbageHintFallsBackToTheOwedMission() async {
        let alarm = Self.draft()
        let system = FakeAlarmSystem()
        let (bridge, _) = Self.bridge(with: alarm, system: system)
        await bridge.handleStopPressed(alarmID: alarm.id)

        // A cold relaunch: fresh process, nothing in memory, the handoff still on disk. The
        // follow-up is armed but not alerting yet, so the disk is the only thing that answers.
        let relaunched = AlarmBridge(system: system)
        await relaunched.handleMissionRequested(hint: "not-a-uuid")

        #expect(relaunched.activeMission?.alarmID == alarm.id)
    }

    @Test("With nothing alerting and nothing owed, the one alarm recently due answers")
    func aGarbageHintFallsBackToTheOneRecentlyDueAlarm() async {
        // An alarm whose time was ten minutes ago: due within the window, and the only one.
        let justRang = Date().addingTimeInterval(-600)
        let alarm = AlarmDraft(
            hour: Calendar.current.component(.hour, from: justRang),
            minute: Calendar.current.component(.minute, from: justRang),
            mission: .default
        )
        let system = FakeAlarmSystem()
        let (bridge, _) = Self.bridge(with: alarm, system: system)

        await bridge.handleStopPressed(hint: "")

        #expect(bridge.activeMission?.alarmID == alarm.id, "the recently due alarm was not resolved")
        #expect(system.calls.contains(.followUp(alarm.id)))
    }

    @Test("An unresolvable press does nothing rather than guessing among several alarms")
    func anUnresolvableHintStaysQuiet() async {
        // An alarm half a day away, whichever half of the day the test runs in: not alerting,
        // not owed, and outside the recently-due window, so nothing answers for the hint.
        let farAway = Date().addingTimeInterval(12 * 3600)
        let alarm = AlarmDraft(
            hour: Calendar.current.component(.hour, from: farAway),
            minute: Calendar.current.component(.minute, from: farAway),
            mission: .default
        )
        let (bridge, _) = Self.bridge(with: alarm, system: FakeAlarmSystem())

        await bridge.handleStopPressed(hint: "")

        #expect(bridge.activeMission == nil)
    }

    // MARK: - The daemon refusing or vanishing

    @Test("A follow-up refused once is retried rather than abandoned")
    func aRefusedFollowUpIsRetried() async {
        struct StaleDate: Error {}
        let alarm = Self.draft()
        let system = FakeAlarmSystem(refusal: StaleDate(), refusalLimit: 1)
        let (bridge, _) = Self.bridge(with: alarm, system: system)

        await bridge.handleStopPressed(alarmID: alarm.id)

        #expect(system.calls.filter { $0 == .followUp(alarm.id) }.count == 2, "no second attempt was made")
        #expect(bridge.armedIDs == [alarm.id], "the retry did not leave the alarm armed")
        #expect(bridge.lastFailure == nil, "a survived refusal is not a failure to report")
    }

    @Test("A follow-up refused twice is reported, because nothing will ring on its own")
    func aTwiceRefusedFollowUpIsReported() async {
        struct Broken: Error {}
        let alarm = Self.draft()
        let system = FakeAlarmSystem(refusal: Broken(), refusalLimit: .max)
        let (bridge, _) = Self.bridge(with: alarm, system: system)

        await bridge.handleStopPressed(alarmID: alarm.id)

        #expect(bridge.lastFailure?.detail.contains("follow-up") == true)
    }

    // MARK: - Reconciliation

    @Test("Re-arming everything at launch does not cancel the follow-up a dodge just armed")
    func reconcileLeavesAnOwedMissionAlone() async {
        let alarm = Self.draft(repeatDays: [.monday])
        let system = FakeAlarmSystem()
        let (bridge, _) = Self.bridge(with: alarm, system: system)
        await bridge.handleStopPressed(alarmID: alarm.id)

        await bridge.reconcile()

        // Still the one-off follow-up, not tomorrow's 06:30. Putting the recurrence back here
        // would replace the ring that was going to get the user up with one 24 hours away.
        #expect(system.calls.last == .followUp(alarm.id))
        #expect(bridge.armedIDs == [alarm.id])
    }

    @Test("Reconciliation does nothing at all when the daemon cannot be asked")
    func reconcileDoesNothingOnAFailedRead() async {
        // The bug this holds down, from the daemon's own log: "Scheduled alarm", then 200ms
        // later "Cancelling alarm". A stale read answered "nothing armed", reconciliation
        // believed it, and cancel-then-reschedule destroyed the alarm it was protecting. No
        // answer licenses nothing.
        let alarm = Self.draft()
        let system = FakeAlarmSystem()
        let (bridge, _) = Self.bridge(with: alarm, system: system)
        await bridge.schedule(alarm)
        let armedBefore = system.calls.count
        system.becomeUnreachable()

        await bridge.reconcile()

        #expect(system.calls.count == armedBefore, "reconcile acted on a read that never happened")
    }

    @Test("Reconciliation never cancels an alarm that is ringing this instant")
    func reconcileSparesAnAlertingAlarm() async {
        // The app can be launched in the background by the ringing alert's own buttons, and
        // reconcile runs at every launch. The alarm was deleted from the store while it rang,
        // so the stray-cancelling loop would see an id the store cannot vouch for — attached
        // to the very ring the user is answering.
        let alarm = Self.draft()
        let system = FakeAlarmSystem()
        let (bridge, store) = Self.bridge(with: alarm, system: system)
        await bridge.schedule(alarm)
        system.startAlerting(alarm.id)
        store.remove(id: alarm.id)
        let cancelsBefore = system.calls.filter { $0 == .cancel(alarm.id) }.count

        await bridge.reconcile()

        #expect(system.calls.filter { $0 == .cancel(alarm.id) }.count == cancelsBefore,
                "reconcile cancelled the ringing alarm")
        #expect(bridge.armedIDs == [alarm.id])
    }

    /// The phone restarted overnight, the alarm rang before anyone unlocked it, and its Stop
    /// button launched the app with the alarm list still closed by data protection. An empty
    /// list that only means "not read yet" made every armed alarm look like a stray.
    @Test("Reconciliation does nothing while the alarm list cannot be read yet")
    func reconcileWaitsForTheList() async throws {
        let alarm = Self.draft(repeatDays: [.monday])
        let system = FakeAlarmSystem()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("handoff-\(UUID().uuidString)", isDirectory: true)
        let (bridge, _) = Self.bridge(with: alarm, system: system, in: directory)
        await bridge.schedule(alarm)
        let file = directory.appendingPathComponent("alarms.json")
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: file.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path) }

        // A new process, launched before the first unlock.
        let early = AlarmStore(directory: directory)
        #expect(early.isUnread)
        let relaunched = AlarmBridge(system: system)
        relaunched.attach(alarms: early, log: WakeLogStore(directory: directory))
        let callsBefore = system.calls.count

        await relaunched.reconcile()

        #expect(system.calls.count == callsBefore, "reconcile cancelled an alarm it could not see")
        #expect(system.snapshot()?.scheduled == [alarm.id])
    }

    // MARK: - A morning in progress

    /// Between two stages the only thing standing between the user and a lie-in is the
    /// one-off ring that continues the morning. An edit re-armed the alarm on its normal
    /// schedule over it, and a delete or a switch-off cancelled it outright.
    @Test("Editing, switching off or deleting an alarm mid-morning leaves the ring that continues it")
    func aMorningInProgressSurvivesTheList() async {
        let alarm = AlarmDraft(
            hour: 6, minute: 30, repeatDays: [.monday],
            mission: MissionConfig(kind: .math, difficulty: .easy, rounds: 1),
            followOns: [FollowOnMission(mission: MissionConfig(kind: .shake, difficulty: .easy), minutesAfter: 10)]
        )
        let system = FakeAlarmSystem()
        let (bridge, store) = Self.bridge(with: alarm, system: system)
        await bridge.handleStopPressed(alarmID: alarm.id)
        guard let stage1 = bridge.activeMission else { Issue.record("no mission opened"); return }
        await bridge.missionCompleted(stage1)
        let callsBefore = system.calls.count

        var edited = alarm
        edited.minute = 45
        store.upsert(edited)
        await bridge.schedule(edited)
        edited.isEnabled = false
        store.upsert(edited)
        await bridge.schedule(edited)
        bridge.cancel(alarm.id)

        #expect(system.calls.count == callsBefore, "the list touched the ring that continues the morning")
        #expect(bridge.armedIDs == [alarm.id])
        #expect(PendingMissionStore.loadUpcoming()?.stage == 1)
    }

    @Test("A change made mid-morning applies once the morning is settled")
    func aChangeMadeMidMorningAppliesAfterwards() async {
        let alarm = Self.draft(repeatDays: [.monday])
        let system = FakeAlarmSystem()
        let (bridge, store) = Self.bridge(with: alarm, system: system)
        await bridge.handleStopPressed(alarmID: alarm.id)
        guard let pending = bridge.activeMission else { Issue.record("no mission opened"); return }
        var switchedOff = alarm
        switchedOff.isEnabled = false
        store.upsert(switchedOff)
        await bridge.schedule(switchedOff)
        #expect(system.calls.last == .followUp(alarm.id), "switching it off ended the morning")

        await bridge.missionCompleted(pending)

        #expect(bridge.armedIDs.isEmpty, "the alarm switched off mid-morning was put back on its schedule")
        #expect(system.snapshot()?.scheduled.isEmpty == true)
    }

    // MARK: - Chained missions

    @Test("Clearing a stage with a follow-on arms the next ring instead of ending the morning")
    func clearingAStageArmsTheNextOne() async {
        let alarm = AlarmDraft(
            hour: 6, minute: 30,
            mission: MissionConfig(kind: .math, difficulty: .easy, rounds: 1),
            followOns: [FollowOnMission(mission: MissionConfig(kind: .shake, difficulty: .easy), minutesAfter: 10)]
        )
        let system = FakeAlarmSystem()
        let (bridge, store) = Self.bridge(with: alarm, system: system)
        await bridge.handleStopPressed(alarmID: alarm.id)
        guard let stage1 = bridge.activeMission else { Issue.record("no mission opened"); return }
        #expect(stage1.totalStages == 2)

        await bridge.missionCompleted(stage1)

        // The screen comes down, but the morning is not over: the alarm is armed ten
        // minutes out, and the record on disk already names the next mission.
        #expect(bridge.activeMission == nil)
        #expect(system.lastFollowUpDelay == 600)
        #expect(bridge.armedIDs == [alarm.id])
        let waiting = PendingMissionStore.loadUpcoming()
        #expect(waiting?.stage == 1)
        #expect(waiting?.mission.kind == .shake)
        // Scheduled is not owed: nothing may open the mission screen during the wait.
        #expect(PendingMissionStore.loadIfFresh() == nil)
        // And the alarm still stands in the store: the morning is not settled.
        #expect(store.alarm(id: alarm.id)?.isEnabled == true)
    }

    @Test("The waiting stage does not re-arm as 'left unfinished' when the app comes forward")
    func aWaitingStageIsNotAnEscape() async {
        let alarm = AlarmDraft(
            hour: 6, minute: 30,
            mission: MissionConfig(kind: .math, difficulty: .easy, rounds: 1),
            followOns: [FollowOnMission(mission: MissionConfig(kind: .steps, difficulty: .easy), minutesAfter: 10)]
        )
        let system = FakeAlarmSystem()
        let (bridge, _) = Self.bridge(with: alarm, system: system)
        await bridge.handleStopPressed(alarmID: alarm.id)
        guard let stage1 = bridge.activeMission else { Issue.record("no mission opened"); return }
        await bridge.missionCompleted(stage1)
        let armedForStage2 = system.lastFollowUpDelay

        // What the app does on every return to the foreground during the wait.
        #expect(bridge.restorePendingMission() == false)
        await bridge.missionLeftUnfinished()

        // Still the ten-minute ring, not an "immediate" one: waiting is not walking away.
        #expect(system.lastFollowUpDelay == armedForStage2)
    }

    @Test("The next ring opens the next mission, and dodging it keeps it armed")
    func theNextRingCarriesTheNextMission() async {
        // One minute after, the floor, so the stage is already due and the ring can be
        // played without moving the clock.
        let alarm = AlarmDraft(
            hour: 6, minute: 30,
            mission: MissionConfig(kind: .math, difficulty: .easy, rounds: 1),
            followOns: [FollowOnMission(mission: MissionConfig(kind: .shake, difficulty: .easy), minutesAfter: 1)]
        )
        let system = FakeAlarmSystem()
        let (bridge, _) = Self.bridge(with: alarm, system: system)
        await bridge.handleStopPressed(alarmID: alarm.id)
        guard let stage1 = bridge.activeMission else { Issue.record("no mission opened"); return }
        await bridge.missionCompleted(stage1)

        // The second ring's stop press, in whichever process it lands.
        let relaunched = AlarmBridge(system: system)
        await relaunched.handleStopPressed(alarmID: alarm.id)

        #expect(relaunched.activeMission?.mission.kind == .shake, "the second ring did not carry the second mission")
        #expect(relaunched.activeMission?.stage == 1)
        #expect(system.lastFollowUpDelay == AlarmBridge.relentlessDelay, "dodging stage two did not re-arm it")
    }

    @Test("Clearing the last stage settles the whole morning")
    func clearingTheLastStageSettlesTheMorning() async {
        let alarm = AlarmDraft(
            hour: 6, minute: 30,
            mission: MissionConfig(kind: .math, difficulty: .easy, rounds: 1),
            followOns: [FollowOnMission(mission: MissionConfig(kind: .shake, difficulty: .easy), minutesAfter: 1)]
        )
        let system = FakeAlarmSystem()
        let (bridge, store) = Self.bridge(with: alarm, system: system)
        await bridge.handleStopPressed(alarmID: alarm.id)
        guard let stage1 = bridge.activeMission else { Issue.record("no mission opened"); return }
        await bridge.missionCompleted(stage1)
        await bridge.handleMissionRequested(alarmID: alarm.id)
        guard let stage2 = bridge.activeMission, stage2.stage == 1 else {
            Issue.record("stage two never opened"); return
        }

        await bridge.missionCompleted(stage2)

        #expect(bridge.activeMission == nil)
        #expect(PendingMissionStore.load() == nil)
        // A one-shot is retired only once the whole chain is done.
        #expect(store.alarm(id: alarm.id)?.isEnabled == false)
        #expect(bridge.armedIDs.isEmpty)
    }

    @Test("Reconciliation leaves the ring between two stages alone")
    func reconcileLeavesAWaitingStageAlone() async {
        let alarm = AlarmDraft(
            hour: 6, minute: 30, repeatDays: [.monday],
            mission: MissionConfig(kind: .math, difficulty: .easy, rounds: 1),
            followOns: [FollowOnMission(mission: MissionConfig(kind: .shake, difficulty: .easy), minutesAfter: 10)]
        )
        let system = FakeAlarmSystem()
        let (bridge, _) = Self.bridge(with: alarm, system: system)
        await bridge.handleStopPressed(alarmID: alarm.id)
        guard let stage1 = bridge.activeMission else { Issue.record("no mission opened"); return }
        await bridge.missionCompleted(stage1)

        await bridge.reconcile()

        // Still the one-off that continues the morning, not Monday's recurrence.
        #expect(system.calls.last == .followUp(alarm.id))
    }

    @Test("The escape hatch abandons the whole chain, not one stage of it")
    func abandoningAbandonsTheChain() async {
        let alarm = AlarmDraft(
            hour: 6, minute: 30,
            mission: MissionConfig(kind: .math, difficulty: .easy, rounds: 1),
            followOns: [FollowOnMission(mission: MissionConfig(kind: .shake, difficulty: .easy), minutesAfter: 1)]
        )
        let system = FakeAlarmSystem()
        let (bridge, _) = Self.bridge(with: alarm, system: system)
        await bridge.handleStopPressed(alarmID: alarm.id)
        guard let stage1 = bridge.activeMission else { Issue.record("no mission opened"); return }

        await bridge.missionAbandoned(stage1)

        #expect(PendingMissionStore.load() == nil, "a follow-on outlived the emergency exit")
        #expect(bridge.armedIDs.isEmpty)
    }

    // MARK: - The shared bridge's stores

    /// The one test in this file that talks to the real AlarmKit daemon, because the object under
    /// test *is* the singleton the lock-screen intents hold, and a double would be testing
    /// something else.
    ///
    /// What that costs, written down because it cost an hour on 2026-09-03: on a simulator that has
    /// never answered "Allow Dawnbreak to schedule alarms and timers?", `handleMissionRequested`
    /// arms a follow-up, `AlarmBridge.schedule` asks for authorization first, and the await never
    /// returns. The whole unit bundle then sits at zero output forever with no failure and no
    /// timeout, which reads as a hung machine rather than an unanswered prompt. There is no
    /// `simctl privacy` service for alarms, so the alert cannot be pre-granted; what answers it is
    /// `UITestCase.allowAlarmsIfAsked`, so run the UI bundle once on a fresh device before this
    /// one. Erasing the simulator is what makes a device that used to be authorized stop being it.
    @Test("Building a throwaway environment does not steal the shared bridge's stores")
    func aThrowawayEnvironmentLeavesTheSharedBridgeAlone() async {
        // The worst bug this app has had, as a regression test. SwiftUI's environment default
        // built an `AppEnvironment` on a temporary directory, and building one used to attach
        // its stores to `AlarmBridge.shared` — the object the lock-screen intents talk to.
        // From that moment every button on the ringing alert was answered out of an empty
        // store: no mission, no re-arm, no second ring. "Nothing happened."
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("throwaway-\(UUID().uuidString)", isDirectory: true)

        let alarm = Self.draft()
        let real = AlarmStore(directory: directory)
        real.upsert(alarm)
        AlarmBridge.shared.attach(alarms: real, log: WakeLogStore(directory: directory))
        defer {
            // The singleton outlives the test and talks to the process's real AlarmKit, so
            // everything it was made to do here is undone: the follow-up it armed, the
            // handoff on disk, and the store it was attached to.
            AlarmBridge.shared.cancel(alarm.id)
            PendingMissionStore.clear()
            AlarmBridge.shared.restorePendingMission()
            AlarmBridge.shared.attach(
                alarms: AlarmStore(directory: directory),
                log: WakeLogStore(directory: directory)
            )
        }

        // What the environment default does, spelled out: a scratch environment with a bridge
        // of its own. The assertion is that this line has no effect on `.shared`.
        _ = AppEnvironment(directory: FileManager.default.temporaryDirectory, bridge: AlarmBridge(system: FakeAlarmSystem()))

        PendingMissionStore.clear()
        await AlarmBridge.shared.handleMissionRequested(alarmID: alarm.id)
        #expect(AlarmBridge.shared.activeMission?.alarmID == alarm.id,
                "the shared bridge lost its store to a throwaway environment")
    }

    // MARK: - The follow-up's contents

    @Test("The follow-up alarm carries the same mission, sound and label as the alarm that rang")
    func theFollowUpIsTheSameAlarm() async {
        let alarm = AlarmDraft(
            hour: 5,
            minute: 45,
            label: "Gym",
            mission: MissionConfig(kind: .math, difficulty: .hard, rounds: 3),
            soundName: AlarmSound.klaxon.rawValue,
            volume: 0.7,
            vibrate: false
        )
        let (bridge, _) = Self.bridge(with: alarm)
        await bridge.handleStopPressed(alarmID: alarm.id)
        guard let pending = bridge.activeMission else {
            Issue.record("the mission never opened")
            return
        }

        let followUp = pending.followUpDraft()

        #expect(followUp.id == alarm.id, "a new id per dodge would leak alarms into the system")
        #expect(followUp.label == "Gym")
        #expect(followUp.mission == alarm.mission)
        #expect(followUp.soundName == AlarmSound.klaxon.rawValue)
        #expect(followUp.volume == 0.7)
        #expect(followUp.vibrate == false)
    }
}
