import DawnbreakKit
import SwiftUI

@main
@MainActor
struct DawnbreakApp: App {
    @State private var env = CaptureMode.makeEnvironment()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.app, env)
                // Dark only. Every colour in `Theme` is drawn for a dark bedroom at 06:00, and a
                // light scheme put the system's black text on those dark surfaces.
                .preferredColorScheme(.dark)
                .task {
                    #if DEBUG
                    // Before the restore: the seed clears the pending mission store, and the
                    // ring test needs the launch to start from silence.
                    await E2EAlarmSeed.armIfRequested(on: env)
                    #endif
                    // Order matters. Restore first so a mission interrupted by the app being
                    // killed is back on screen before anything can re-arm the alarm, then
                    // reconcile so an alarm the system has forgotten is put back.
                    let resumed = env.bridge.restorePendingMission()
                    // A screenshot run stops here. `reconcile` arms the seeded alarms, and
                    // arming the first one asks for permission to interrupt Focus, which puts a
                    // system alert over whatever was being photographed.
                    guard !CaptureMode.isActive else { return }
                    // A mission was already owed when the app launched, which means the app was
                    // killed with the mission screen up — the one escape the screen cannot see
                    // for itself, and the obvious way to try to defeat it. The alarm comes
                    // straight back rather than in a minute.
                    if resumed { await env.bridge.missionLeftUnfinished() }
                    await env.bridge.reconcile()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            // A success page is read once. Left up, it greeted the next unlock hours later.
            if phase == .background { env.bridge.dismissCelebration() }
            // Coming back to the foreground is the moment a mission left pending by a
            // lock-screen intent becomes visible, and the moment to notice that an alarm
            // was silenced while the app was away.
            guard phase == .active else { return }
            // A process launched by a lock-screen button before the first unlock after a
            // restart could not read its files. The phone is unlocked by now.
            env.alarms.reloadIfUnread()
            env.log.reloadIfUnread()
            let resumed = env.bridge.restorePendingMission()
            guard resumed, !CaptureMode.isActive else { return }
            Task { await env.bridge.missionLeftUnfinished() }
        }
    }
}
