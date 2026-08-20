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
