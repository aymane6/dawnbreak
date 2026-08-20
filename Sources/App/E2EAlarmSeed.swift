#if DEBUG
import DawnbreakKit
import Foundation

/// Arms one real alarm a few seconds out, so a UI test can watch it actually ring.
///
/// This exists because the one behaviour the app cannot afford to get wrong — the ringing
/// alert handing over to the mission screen — is also the one behaviour no unit test can
/// reach: the alert is drawn by the system, its buttons are pressed on the system's surface,
/// and whether the tap launches the app at all is the system's decision. The fake scheduler
/// proves the bridge does the right thing when called; only a real ring proves it gets called.
///
/// Debug-only, unlike `CaptureMode`, and for the opposite reason: capture must run on the
/// shipped binary because the screenshots are claims about it, while this must not ship
/// because it deletes every alarm on the device by design. The launch argument's string
/// constant lives in `CaptureLaunch` so the UI test target can spell it identically.
@MainActor
enum E2EAlarmSeed {

    /// The seconds after launch the seeded alarm should ring, or nil on an ordinary launch.
    static var secondsFromLaunch: Int? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: CaptureLaunch.e2eAlarmArgument),
              arguments.indices.contains(flag + 1),
              let seconds = Int(arguments[flag + 1]) else { return nil }
        return seconds
    }

    /// Whether this launch should begin with a mission already owed, the state a lock-screen
    /// intent leaves behind.
    static var wantsOwedMission: Bool {
        ProcessInfo.processInfo.arguments.contains(CaptureLaunch.e2eMissionArgument)
    }

    /// Once per process. SwiftUI restarts a `.task` whenever the view's identity changes, and
    /// a second pass here would wipe the very alarm the first pass armed: the test would then
    /// be watching an id that no longer exists.
    private static var hasRun = false

    /// Clears whatever the previous run left, then arms one math alarm through the real bridge.
    ///
    /// The wipe comes first so the test is deterministic: a follow-up still armed from the last
    /// run would ring in the middle of this one and be indistinguishable from the ring under
    /// test. The alarm's schedule is minute-based, so the ring lands on the first minute
    /// boundary at or before `seconds` from now — the test polls, it does not count.
    static func armIfRequested(on env: AppEnvironment) async {
        guard !hasRun, secondsFromLaunch != nil || wantsOwedMission else { return }
        hasRun = true

        for alarm in env.alarms.alarms {
            env.bridge.cancel(alarm.id)
            env.alarms.remove(id: alarm.id)
        }
        PendingMissionStore.clear()
        env.preferences.hasCompletedOnboarding = true

        if wantsOwedMission {
            // Authorization up front, not as a side effect. Restoring the mission arms a
            // follow-up through the real daemon, and on a simulator that has never answered
            // the AlarmKit prompt that would pop the permission alert mid-test, over whatever
            // the test is asserting about. Asking here puts the alert where the test's launch
            // helper is already waiting for it.
            _ = await env.bridge.requestAuthorization()
            // The state a lock-screen press leaves behind, written the way the intent writes
            // it: the alarm in the store, the handoff in the shared container. The launch that
            // follows has to put the mission on the glass — over an editor, a paywall, or a
            // failure dialog, which is exactly the collision this exists to catch.
            let alarm = AlarmDraft(
                hour: Calendar.current.component(.hour, from: Date()),
                minute: Calendar.current.component(.minute, from: Date()),
                label: "E2E",
                mission: MissionConfig(kind: .math, difficulty: .easy, rounds: 1),
                relentless: true
            )
            env.alarms.upsert(alarm)
            var pending = PendingMission(alarm: alarm, scheduledFor: Date())
            pending.volume = 0
            pending.vibrate = false
            PendingMissionStore.save(pending)
            return
        }

        guard let seconds = secondsFromLaunch else { return }
        let target = Date().addingTimeInterval(TimeInterval(seconds))
        let alarm = AlarmDraft(
            hour: Calendar.current.component(.hour, from: target),
            minute: Calendar.current.component(.minute, from: target),
            label: "E2E",
            mission: MissionConfig(kind: .math, difficulty: .easy, rounds: 1),
            relentless: true
        )
        env.alarms.upsert(alarm)
        await env.bridge.schedule(alarm)
    }
}
#endif
