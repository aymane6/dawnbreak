import DawnbreakKit
import SwiftUI
import UIKit

/// Settings, kept short on purpose.
///
/// Every row here is either something the user has a real reason to change (clock format,
/// haptics) or something the app owes them (permissions, data erasure). The way
/// out of a mission is not a setting: it is the X on every mission screen, always there.
/// Nothing is here for symmetry, and nothing is here that the app does not act on.
struct SettingsView: View {
    @Environment(\.app) private var app
    @State private var isConfirmingErase = false
    @State private var didErase = false

    var body: some View {
        NavigationStack {
            List {
                wakeSection
                permissionsSection
                dataSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .dawnCanvas()
            .navigationTitle(Text("tab.settings", bundle: .main))
            .confirmationDialog(
                Text("settings.erase.confirm", bundle: .main),
                isPresented: $isConfirmingErase,
                titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    app.log.eraseAll()
                    didErase = true
                } label: {
                    Text("settings.erase.action", bundle: .main)
                }
                Button(role: .cancel) {} label: { Text("action.cancel", bundle: .main) }
            } message: {
                Text("settings.erase.body", bundle: .main)
            }
            .alert(Text("settings.erase.done", bundle: .main), isPresented: $didErase) {
                Button { didErase = false } label: { Text("action.ok", bundle: .main) }
            }
        }
    }

    // MARK: - Sections

    private var wakeSection: some View {
        Section {
            Picker(selection: clockBinding) {
                Text("settings.clock.region", bundle: .main).tag(ClockChoice.region)
                Text("settings.clock.24", bundle: .main).tag(ClockChoice.twentyFour)
                Text("settings.clock.12", bundle: .main).tag(ClockChoice.twelve)
            } label: {
                Text("settings.clock", bundle: .main)
            }

            Toggle(isOn: hapticsBinding) {
                Text("settings.haptics", bundle: .main)
            }
        } header: {
            Text("settings.section.wake", bundle: .main)
        }
        .tint(Theme.accent)
        .listRowBackground(Theme.surface)
    }

    /// The alarm permission is the one thing without which nothing works, so its state is
    /// shown plainly with a route to the fix rather than buried.
    private var permissionsSection: some View {
        Section {
            HStack(spacing: 10) {
                Image(systemName: authorizationSymbol)
                    .foregroundStyle(app.bridge.authorization == .authorized ? Theme.success : Theme.warning)
                VStack(alignment: .leading, spacing: 2) {
                    Text("settings.permission.alarms", bundle: .main)
                    Text(key: authorizationKey)
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                // Only while iOS has never asked. After a refusal the system will not ask again,
                // so a button here would do nothing; the iOS Settings row below is the way back.
                if app.bridge.authorization == .notDetermined {
                    Button {
                        Task { await app.bridge.requestAuthorization() }
                    } label: {
                        Text("settings.permission.grant", bundle: .main)
                            .font(Theme.captionFont)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
                }
            }
            .accessibilityIdentifier(AccessibilityID.settingsPermissions)

            Button {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            } label: {
                Label {
                    Text("settings.openSystemSettings", bundle: .main)
                } icon: {
                    Image(systemName: "gearshape").foregroundStyle(Theme.accent)
                }
            }
        } header: {
            Text("settings.section.permissions", bundle: .main)
        }
        .listRowBackground(Theme.surface)
    }

    private var dataSection: some View {
        Section {
            HStack {
                Text("settings.recordCount", bundle: .main)
                Spacer()
                Text(app.log.records.count.formatted(.number))
                    .foregroundStyle(Theme.textSecondary)
                    .monospacedDigit()
            }
            Button(role: .destructive) {
                isConfirmingErase = true
            } label: {
                Text("settings.erase", bundle: .main)
            }
        } header: {
            Text("settings.section.data", bundle: .main)
        } footer: {
            Text("settings.section.data.footer", bundle: .main)
        }
        .listRowBackground(Theme.surface)
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("settings.version", bundle: .main)
                Spacer()
                Text(verbatim: versionText)
                    .foregroundStyle(Theme.textSecondary)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(AccessibilityID.settingsVersion)
            Link(destination: URL(string: "https://dawnbreak.app/privacy.html")!) {
                Text("legal.privacy", bundle: .main)
            }
            Link(destination: URL(string: "https://dawnbreak.app/terms.html")!) {
                Text("legal.terms", bundle: .main)
            }
            Link(destination: URL(string: "mailto:fastpapershot.supp@outlook.com?subject=Dawnbreak")!) {
                Text("settings.support", bundle: .main)
            }
            Button {
                app.preferences.hasCompletedOnboarding = false
            } label: {
                Text("settings.replayOnboarding", bundle: .main)
            }
        } header: {
            Text("settings.section.about", bundle: .main)
        }
        .listRowBackground(Theme.surface)
    }

    // MARK: - Bindings
    //
    // `Preferences` is `@Observable`, not `@AppStorage`, so each row needs a binding into it.
    // Written out rather than generated, because a keypath-based helper would lose the
    // `nil`-means-region case below.

    private enum ClockChoice: Hashable { case region, twentyFour, twelve }

    private var clockBinding: Binding<ClockChoice> {
        Binding(
            get: {
                switch app.preferences.usesTwentyFourHourClockOverride {
                case .none: .region
                case .some(true): .twentyFour
                case .some(false): .twelve
                }
            },
            set: { choice in
                app.preferences.usesTwentyFourHourClockOverride = switch choice {
                case .region: nil
                case .twentyFour: true
                case .twelve: false
                }
            }
        )
    }

    private var hapticsBinding: Binding<Bool> {
        Binding(get: { app.preferences.hapticsEnabled }, set: { app.preferences.hapticsEnabled = $0 })
    }

    // MARK: - Derived copy

    private var authorizationSymbol: String {
        app.bridge.authorization == .authorized ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    private var authorizationKey: String {
        switch app.bridge.authorization {
        case .authorized: "settings.permission.granted"
        case .denied: "settings.permission.denied"
        default: "settings.permission.notDetermined"
        }
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
