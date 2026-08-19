import DawnbreakKit
import SwiftUI

/// The three tabs, plus the two things that take over the whole screen: onboarding and a
/// ringing mission.
struct RootView: View {
    @Environment(\.app) private var app

    var body: some View {
        TabView(selection: tabSelection) {
            Tab(value: AppEnvironment.Tab.alarms) {
                AlarmListView()
            } label: {
                Label {
                    Text("tab.alarms", bundle: .main)
                } icon: {
                    Image(systemName: "alarm.fill")
                }
            }

            Tab(value: AppEnvironment.Tab.stats) {
                StatsView()
            } label: {
                Label {
                    Text("tab.stats", bundle: .main)
                } icon: {
                    Image(systemName: "chart.bar.xaxis")
                }
            }

            Tab(value: AppEnvironment.Tab.settings) {
                SettingsView()
            } label: {
                Label {
                    Text("tab.settings", bundle: .main)
                } icon: {
                    Image(systemName: "gearshape.fill")
                }
            }
        }
        .tint(Theme.accent)
        // The mission is a full-screen cover, not a sheet: a sheet can be swiped away, and
        // the whole promise of the app is that this screen does not go away on a swipe.
        .fullScreenCover(item: missionBinding) { pending in
            MissionRunnerView(pending: pending)
        }
        .fullScreenCover(isPresented: onboardingBinding) {
            OnboardingView()
        }
        .sheet(item: paywallBinding) { reason in
            PaywallView(reason: reason)
        }
    }

    private var tabSelection: Binding<AppEnvironment.Tab> {
        Binding(get: { app.selectedTab }, set: { app.selectedTab = $0 })
    }

    private var missionBinding: Binding<PendingMission?> {
        // Read-only from the view's side. Dismissal happens through the bridge, because
        // closing this screen has to also settle the alarm, and a `nil` written here would
        // close it without doing that.
        Binding(get: { app.bridge.activeMission }, set: { _ in })
    }

    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: { !app.preferences.hasCompletedOnboarding && app.bridge.activeMission == nil },
            set: { app.preferences.hasCompletedOnboarding = !$0 }
        )
    }

    private var paywallBinding: Binding<AppEnvironment.PaywallReason?> {
        Binding(get: { app.paywallReason }, set: { app.paywallReason = $0 })
    }
}

/// `fullScreenCover(item:)` and `sheet(item:)` want an `Identifiable` optional. `PendingMission`
/// is a value type keyed by its alarm id, and the reason for the wrapper is that presenting
/// on identity means a *different* alarm ringing replaces the screen rather than being
/// silently ignored.
extension PendingMission: Identifiable {
    var id: UUID { alarmID }
}

private extension View {
    /// A thin alias so the call sites above read as `item:` rather than the stock
    /// `isPresented:`/`item:` mix. Kept private to this file.
    func fullScreenCover<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        fullScreenCover(isPresented: Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } })) {
            if let value = item.wrappedValue {
                content(value)
            }
        }
    }

    func sheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        sheet(isPresented: Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } })) {
            if let value = item.wrappedValue {
                content(value)
            }
        }
    }
}
