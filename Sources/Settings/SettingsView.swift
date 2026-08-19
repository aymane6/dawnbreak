import DawnbreakKit
import SwiftUI
import UIKit

/// Settings, kept short on purpose.
///
/// Every row here is either something the user has a real reason to change (clock format,
/// appearance, bedtime) or something the app owes them (permissions, data erasure, the
/// escape hatch). Nothing is here for symmetry.
struct SettingsView: View {
    @Environment(\.app) private var app
    @State private var isConfirmingErase = false
    @State private var didErase = false

    var body: some View {
        NavigationStack {
            List {
                subscriptionSection
                wakeSection
                bedtimeSection
                appearanceSection
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

    @ViewBuilder private var subscriptionSection: some View {
        Section {
            if app.entitlement == .pro {
                HStack {
                    Label {
                        Text("settings.pro.active", bundle: .main)
                    } icon: {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.success)
                    }
                    Spacer()
                }
                Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                    Label {
                        Text("settings.manageSubscription", bundle: .main)
                    } icon: {
                        Image(systemName: "creditcard").foregroundStyle(Theme.accent)
                    }
                }
            } else {
                Button {
                    app.paywallReason = .manual
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "sunrise.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.dawnGradient)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("settings.upgrade.title", bundle: .main)
                                .font(Theme.headlineFont)
                                .foregroundStyle(Theme.textPrimary)
                            Text("settings.upgrade.body", bundle: .main)
                                .font(Theme.captionFont)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.textTertiary)
                    }
                }
                Button {
                    Task { await app.subscription.restore() }
                } label: {
                    Text("paywall.restore", bundle: .main)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .listRowBackground(Theme.surface)
    }

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

            Toggle(isOn: escapeBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("settings.escapeHatch", bundle: .main)
                    Text("settings.escapeHatch.body", bundle: .main)
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        } header: {
            Text("settings.section.wake", bundle: .main)
        }
        .tint(Theme.accent)
        .listRowBackground(Theme.surface)
    }

    private var bedtimeSection: some View {
        Section {
            Toggle(isOn: bedtimeBinding) {
                Text("settings.bedtimeReminder", bundle: .main)
            }
            if app.preferences.bedtimeReminderEnabled {
                HStack {
                    Text("settings.bedtime", bundle: .main)
                    Spacer()
                    Text(clock.full(hour: app.preferences.bedtimeHour, minute: app.preferences.bedtimeMinute))
                        .font(Theme.bodyFont.monospacedDigit())
                        .foregroundStyle(Theme.accent)
                }
                Stepper(value: bedtimeHourBinding, in: 18...29) {
                    Text("settings.bedtime.hour", bundle: .main)
                        .font(Theme.captionFont)
                }
                Stepper(value: bedtimeMinuteBinding, in: 0...55, step: 5) {
                    Text("settings.bedtime.minute", bundle: .main)
                        .font(Theme.captionFont)
                }
            }
            HStack {
                Text("settings.sleepGoal", bundle: .main)
                Spacer()
                // Preformatted rather than handed to `%.1f`: the number style drops the
                // trailing ".0" on a whole number and picks the region's decimal separator,
                // so a French user sees "7 h" and "7,5 h" instead of "7.0 h".
                Text(localized("settings.sleepGoal.value", app.preferences.sleepGoalHours
                    .formatted(.number.precision(.fractionLength(0...1)))))
                    .foregroundStyle(Theme.accent)
                    .font(Theme.bodyFont.monospacedDigit())
            }
            Slider(value: sleepGoalBinding, in: 5...10, step: 0.5) {
                Text("settings.sleepGoal", bundle: .main)
            }
            .tint(Theme.accent)
        } header: {
            Text("settings.section.sleep", bundle: .main)
        } footer: {
            Text("settings.section.sleep.footer", bundle: .main)
        }
        .tint(Theme.accent)
        .listRowBackground(Theme.surface)
    }

    private var appearanceSection: some View {
        Section {
            Picker(selection: appearanceBinding) {
                ForEach(Preferences.Appearance.allCases) { option in
                    Text(key: option.titleKey).tag(option)
                }
            } label: {
                Text("settings.appearance", bundle: .main)
            }
            .accessibilityIdentifier(AccessibilityID.settingsAppearance)
        } header: {
            Text("settings.section.appearance", bundle: .main)
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
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
                if app.bridge.authorization != .authorized {
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

            Button {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            } label: {
                Label {
                    Text("settings.openSystemSettings", bundle: .main)
                } icon: {
                    Image(systemName: "gear").foregroundStyle(Theme.accent)
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
            Link(destination: URL(string: "https://aymbam.github.io/dawnbreak/privacy")!) {
                Text("legal.privacy", bundle: .main)
            }
            Link(destination: URL(string: "https://aymbam.github.io/dawnbreak/terms")!) {
                Text("legal.terms", bundle: .main)
            }
            Link(destination: URL(string: "mailto:support@aymbam.com?subject=Dawnbreak")!) {
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

    private var escapeBinding: Binding<Bool> {
        Binding(get: { app.preferences.emergencyExitEnabled }, set: { app.preferences.emergencyExitEnabled = $0 })
    }

    private var bedtimeBinding: Binding<Bool> {
        Binding(get: { app.preferences.bedtimeReminderEnabled }, set: { app.preferences.bedtimeReminderEnabled = $0 })
    }

    /// Allowed up to 29 so "01:30" can be expressed as a bedtime that belongs to the previous
    /// evening; the modulo keeps it a valid hour of day.
    private var bedtimeHourBinding: Binding<Int> {
        Binding(
            get: { app.preferences.bedtimeHour < 12 ? app.preferences.bedtimeHour + 24 : app.preferences.bedtimeHour },
            set: { app.preferences.bedtimeHour = $0 % 24 }
        )
    }

    private var bedtimeMinuteBinding: Binding<Int> {
        Binding(get: { app.preferences.bedtimeMinute }, set: { app.preferences.bedtimeMinute = $0 })
    }

    private var sleepGoalBinding: Binding<Double> {
        Binding(get: { app.preferences.sleepGoalHours }, set: { app.preferences.sleepGoalHours = $0 })
    }

    private var appearanceBinding: Binding<Preferences.Appearance> {
        Binding(get: { app.preferences.appearance }, set: { app.preferences.appearance = $0 })
    }

    // MARK: - Derived copy

    private var clock: ClockFormatter {
        ClockFormatter(uses24Hour: app.preferences.usesTwentyFourHourClock)
    }

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
