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
        // A full-screen cover, not a sheet: a sheet can be swiped away, and the whole promise
        // of the app is that the mission screen does not go away on a swipe.
        .fullScreenCover(item: takeoverBinding) { takeover in
            switch takeover {
            case .mission(let pending):
                MissionRunnerView(pending: pending)
            case .onboarding:
                OnboardingView()
            }
        }
        .sheet(item: paywallBinding) { reason in
            PaywallView(reason: reason)
        }
    }

    /// The two things that take the whole screen, as one value.
    ///
    /// One cover rather than two, and this is a bug fix rather than tidying. A view has a
    /// single full-screen-cover slot: attach two modifiers to the same view and only one of
    /// them ever presents, whichever SwiftUI resolves last, and the other is silently dropped.
    /// The alarm rang, the stop button was pressed, the mission was armed and waiting — and no
    /// mission screen appeared, because the onboarding cover underneath it owned the slot.
    /// Expressing the two as one enum makes that unrepresentable, and puts the precedence in
    /// writing: a ringing alarm outranks onboarding.
    private enum Takeover: Identifiable {
        case mission(PendingMission)
        case onboarding

        /// Keyed by the alarm, so a *different* alarm ringing replaces the screen rather than
        /// being silently ignored.
        var id: String {
            switch self {
            case .mission(let pending): pending.alarmID.uuidString
            case .onboarding: "onboarding"
            }
        }
    }

    private var takeover: Takeover? {
        if let pending = app.bridge.activeMission { return .mission(pending) }
        if !app.preferences.hasCompletedOnboarding { return .onboarding }
        return nil
    }

    /// Read-only from the view's side. Both screens dismiss themselves by changing the state
    /// this reads — the mission through the bridge, because closing it has to also settle the
    /// alarm, and onboarding by recording that it is done. A `nil` written here would close
    /// either one without doing that.
    private var takeoverBinding: Binding<Takeover?> {
        Binding(get: { takeover }, set: { _ in })
    }

    private var tabSelection: Binding<AppEnvironment.Tab> {
        Binding(get: { app.selectedTab }, set: { app.selectedTab = $0 })
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
