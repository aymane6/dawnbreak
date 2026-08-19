import DawnbreakKit
import StoreKit
import SwiftUI

/// The upgrade screen.
///
/// The headline changes with the reason the user got here, because "unlock more alarms" and
/// "unlock the push-up mission" are different promises and a generic "Go Pro" answers neither.
struct PaywallView: View {
    @Environment(\.app) private var app
    @Environment(\.dismiss) private var dismiss
    let reason: AppEnvironment.PaywallReason

    @State private var selection: SubscriptionStore.Product = .yearly

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    hero
                    features
                    plans
                    purchaseButton
                    legal
                }
                .padding(.horizontal, Theme.Metric.gutter)
                .padding(.bottom, 28)
            }
            .scrollBounceBehavior(.basedOnSize)
            .dawnCanvas()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        app.preferences.hasSeenPaywall = true
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: Theme.Metric.minimumTarget, height: Theme.Metric.minimumTarget)
                    }
                    .accessibilityLabel(Text("action.close", bundle: .main))
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task { await app.subscription.restore() }
                    } label: {
                        Text("paywall.restore", bundle: .main)
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .task {
                if app.subscription.products.isEmpty { await app.subscription.loadProducts() }
                app.preferences.hasSeenPaywall = true
            }
            .onChange(of: app.subscription.didJustUpgrade) { _, upgraded in
                guard upgraded else { return }
                app.subscription.acknowledgeUpgrade()
                dismiss()
            }
            .alert(
                Text("paywall.error.title", bundle: .main),
                isPresented: Binding(
                    get: { app.subscription.lastError != nil },
                    set: { if !$0 { app.subscription.clearError() } }
                )
            ) {
                Button { app.subscription.clearError() } label: { Text("action.ok", bundle: .main) }
            } message: {
                Text(app.subscription.lastError ?? "")
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.dawnGradient)
                    .frame(width: 84, height: 84)
                    .blur(radius: 22)
                    .opacity(0.7)
                Image(systemName: "sunrise.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(Theme.dawnGradient)
            }
            .padding(.top, 8)

            Text(key: reason.headlineKey)
                .font(Theme.titleFont)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("paywall.subhead", bundle: .main)
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var features: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                FeatureRow(systemImage: "figure.strengthtraining.traditional", titleKey: "paywall.feature.missions", bodyKey: "paywall.feature.missions.body")
                FeatureRow(systemImage: "alarm.waves.left.and.right.fill", titleKey: "paywall.feature.alarms", bodyKey: "paywall.feature.alarms.body")
                FeatureRow(systemImage: "flame.fill", titleKey: "paywall.feature.difficulty", bodyKey: "paywall.feature.difficulty.body")
                FeatureRow(systemImage: "chart.line.uptrend.xyaxis", titleKey: "paywall.feature.stats", bodyKey: "paywall.feature.stats.body")
            }
        }
    }

    @ViewBuilder private var plans: some View {
        if app.subscription.products.isEmpty {
            HStack(spacing: 8) {
                if app.subscription.isLoading { ProgressView().tint(Theme.accent) }
                Text("paywall.plansUnavailable", bundle: .main)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        } else {
            VStack(spacing: 10) {
                ForEach(SubscriptionStore.Product.allCases) { plan in
                    if app.subscription.displayPrice(for: plan) != nil {
                        PlanRow(
                            plan: plan,
                            price: app.subscription.displayPrice(for: plan) ?? "",
                            periodKey: app.subscription.periodKey(for: plan),
                            savingPercent: plan == .yearly ? app.subscription.yearlySavingPercent : nil,
                            trialDays: app.subscription.trialDays(for: plan),
                            isSelected: selection == plan
                        ) {
                            selection = plan
                        }
                    }
                }
            }
        }
    }

    private var purchaseButton: some View {
        VStack(spacing: 8) {
            Button {
                Task { await app.subscription.purchase(selection) }
            } label: {
                if app.subscription.purchaseInFlight == selection {
                    ProgressView().tint(.white)
                } else if let days = app.subscription.trialDays(for: selection) {
                    Text(localized("paywall.cta.trial", days))
                } else {
                    Text("paywall.cta", bundle: .main)
                }
            }
            .buttonStyle(DawnButtonStyle(isEnabled: app.subscription.displayPrice(for: selection) != nil))
            .disabled(app.subscription.displayPrice(for: selection) == nil || app.subscription.purchaseInFlight != nil)
            // How a test knows it is looking at this screen and not at the settings row that opens
            // it. Enabled only once a price has arrived, so it also says the prices loaded.
            .accessibilityIdentifier(AccessibilityID.paywallPurchase)

            Text("paywall.cta.note", bundle: .main)
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
        }
    }

    private var legal: some View {
        VStack(spacing: 6) {
            Text("paywall.legal", bundle: .main)
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                Link(destination: URL(string: "https://aymbam.github.io/dawnbreak/terms")!) {
                    Text("legal.terms", bundle: .main)
                }
                Link(destination: URL(string: "https://aymbam.github.io/dawnbreak/privacy")!) {
                    Text("legal.privacy", bundle: .main)
                }
            }
            .font(.caption2)
            .foregroundStyle(Theme.textSecondary)
        }
    }
}

private struct FeatureRow: View {
    let systemImage: String
    let titleKey: String
    let bodyKey: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(key: titleKey)
                    .font(Theme.headlineFont)
                    .foregroundStyle(Theme.textPrimary)
                Text(key: bodyKey)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PlanRow: View {
    let plan: SubscriptionStore.Product
    let price: String
    let periodKey: String
    let savingPercent: Int?
    let trialDays: Int?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Theme.accent : Theme.textTertiary)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(key: plan.titleKey)
                            .font(Theme.headlineFont)
                            .foregroundStyle(Theme.textPrimary)
                        if let savingPercent {
                            Text(localized("paywall.saving", savingPercent))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Theme.success, in: .capsule)
                        }
                    }
                    if let trialDays {
                        Text(localized("paywall.trial", trialDays))
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.success)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 0) {
                    Text(price)
                        .font(Theme.headlineFont)
                        .foregroundStyle(Theme.textPrimary)
                    Text(key: periodKey)
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .padding(14)
            .background(isSelected ? Theme.surfaceRaised : Theme.surface, in: .rect(cornerRadius: Theme.Metric.controlRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Metric.controlRadius)
                    .stroke(isSelected ? Theme.accent : Theme.hairline, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
