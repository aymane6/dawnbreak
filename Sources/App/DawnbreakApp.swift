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
                .preferredColorScheme(colorScheme)
                .task {
                    // Order matters. Restore first so a mission interrupted by the app being
                    // killed is back on screen before anything can re-arm the alarm, then
                    // reconcile so an alarm the system has forgotten is put back.
                    env.bridge.restorePendingMission()
                    // A screenshot run stops here. `reconcile` arms the seeded alarms, and
                    // arming the first one asks for permission to interrupt Focus, which puts a
                    // system alert over whatever was being photographed; StoreKit is skipped for
                    // the same reason, its entitlement having been pinned at launch.
                    guard !CaptureMode.isActive else { return }
                    await env.bridge.reconcile()
                    await env.subscription.start()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            // Coming back to the foreground is the moment a mission left pending by a
            // lock-screen intent becomes visible, and the moment to notice that an alarm
            // was silenced while the app was away.
            guard phase == .active else { return }
            env.bridge.restorePendingMission()
        }
    }

    private var colorScheme: ColorScheme? {
        switch env.preferences.appearance {
        case .dark: .dark
        case .light: .light
        case .system: nil
        }
    }
}
