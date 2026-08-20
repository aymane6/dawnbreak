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
        system: FakeAlarmSystem = FakeAlarmSystem()
    ) -> (AlarmBridge, AlarmStore) {
        PendingMissionStore.clear()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("handoff-\(UUID().uuidString)", isDirectory: true)
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

    // MARK: - Walking away

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

    // MARK: - The shared bridge's stores

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
