import DawnbreakKit
import Foundation
import Observation
import StoreKit

/// Owns the StoreKit 2 side of Pro.
///
/// `Transaction.currentEntitlements` is the only source of truth here. Nothing is cached in
/// `UserDefaults`: a cached "pro" flag survives a refund, and a cached "free" flag locks a
/// paying user out on a fresh install before the receipt is read.
@MainActor
@Observable
final class SubscriptionStore {
    enum Product: String, CaseIterable, Identifiable {
        case monthly = "com.aymbam.dawnbreak.pro.monthly"
        case yearly = "com.aymbam.dawnbreak.pro.yearly"
        case lifetime = "com.aymbam.dawnbreak.pro.lifetime"

        var id: String { rawValue }

        /// Yearly is preselected. It is the honest recommendation for an app you use every
        /// morning, and it is also the one with a trial.
        var isRecommended: Bool { self == .yearly }

        var titleKey: String {
            switch self {
            case .monthly: "paywall.plan.monthly"
            case .yearly: "paywall.plan.yearly"
            case .lifetime: "paywall.plan.lifetime"
            }
        }
    }

    private(set) var entitlement: Entitlement = .free
    private(set) var products: [StoreKit.Product] = []
    private(set) var isLoading = false
    private(set) var purchaseInFlight: Product?
    private(set) var lastError: String?
    /// Set when a purchase succeeds, so the paywall can show a thank-you and dismiss itself.
    private(set) var didJustUpgrade = false

    private var updatesTask: Task<Void, Never>?

    /// Set only by the screenshot run. See `refreshEntitlement`.
    private let pinnedEntitlement: Entitlement?

    init(pinnedEntitlement: Entitlement? = nil) {
        self.pinnedEntitlement = pinnedEntitlement
        if let pinnedEntitlement {
            entitlement = pinnedEntitlement
        }
    }

    /// Starts the store: loads products, reads current entitlements, then keeps listening.
    ///
    /// The listener is the part people forget. Without it an Ask-to-Buy approval, a family
    /// sharing change, or a renewal that happens while the app is open never reaches the UI.
    func start() async {
        await refreshEntitlement()
        await loadProducts()
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in StoreKit.Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self.refreshEntitlement()
            }
        }
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await StoreKit.Product.products(for: Product.allCases.map(\.rawValue))
            // Sorted by our own enum order, not StoreKit's: the paywall's layout depends on
            // monthly, yearly, lifetime being in that order.
            products = Product.allCases.compactMap { plan in loaded.first { $0.id == plan.rawValue } }
        } catch {
            // Not surfaced as an error: an offline user seeing "something went wrong" on a
            // paywall they did not ask for is worse than seeing the feature list alone.
            products = []
        }
    }

    func purchase(_ plan: Product) async {
        guard let product = products.first(where: { $0.id == plan.rawValue }) else {
            lastError = localized("paywall.error.unavailable")
            return
        }
        purchaseInFlight = plan
        defer { purchaseInFlight = nil }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    lastError = localized("paywall.error.unverified")
                    return
                }
                await transaction.finish()
                await refreshEntitlement()
                didJustUpgrade = entitlement == .pro
            case .pending:
                // Ask-to-Buy. The listener will pick it up when a parent approves.
                lastError = localized("paywall.error.pending")
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// The App Store requires a restore affordance, and it is genuinely needed on a new device
    /// before the app has ever talked to StoreKit.
    func restore() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            if entitlement == .free { lastError = localized("paywall.error.nothingToRestore") }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshEntitlement() async {
        // A pinned entitlement outranks the receipt. Without this, a capture run would be pulled
        // back to free the moment anything called through here, and the screenshot of the
        // mission list would show half of it padlocked.
        if let pinnedEntitlement {
            entitlement = pinnedEntitlement
            return
        }

        var isPro = false
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard Product(rawValue: transaction.productID) != nil else { continue }
            // A revoked transaction is still in `currentEntitlements` on some paths; a
            // refunded purchase must not keep Pro alive.
            if transaction.revocationDate == nil {
                isPro = true
            }
        }
        entitlement = isPro ? .pro : .free
    }

    func clearError() { lastError = nil }
    func acknowledgeUpgrade() { didJustUpgrade = false }

    /// The price string for a plan, already localized and currency-correct by StoreKit.
    func displayPrice(for plan: Product) -> String? {
        products.first { $0.id == plan.rawValue }?.displayPrice
    }

    /// "per month" / "per year" / "one time", derived from the product rather than hardcoded,
    /// so a change of period in App Store Connect does not make the paywall lie.
    func periodKey(for plan: Product) -> String {
        guard let product = products.first(where: { $0.id == plan.rawValue }),
              let period = product.subscription?.subscriptionPeriod else { return "paywall.period.once" }
        switch period.unit {
        case .day: return period.value >= 7 ? "paywall.period.week" : "paywall.period.day"
        case .week: return "paywall.period.week"
        case .month: return period.value >= 12 ? "paywall.period.year" : "paywall.period.month"
        case .year: return "paywall.period.year"
        @unknown default: return "paywall.period.once"
        }
    }

    /// Whether the plan offers an introductory free trial, so the button can say so honestly
    /// instead of promising a trial that does not exist.
    func hasFreeTrial(for plan: Product) -> Bool {
        guard let product = products.first(where: { $0.id == plan.rawValue }),
              let offer = product.subscription?.introductoryOffer else { return false }
        return offer.paymentMode == .freeTrial
    }

    func trialDays(for plan: Product) -> Int? {
        guard let product = products.first(where: { $0.id == plan.rawValue }),
              let offer = product.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        switch offer.period.unit {
        case .day: return offer.period.value
        case .week: return offer.period.value * 7
        case .month: return offer.period.value * 30
        case .year: return offer.period.value * 365
        @unknown default: return nil
        }
    }

    /// The saving of yearly over twelve months, as a whole percentage. Nil when either price
    /// is missing, because a made-up discount badge is a store violation.
    var yearlySavingPercent: Int? {
        guard let monthly = products.first(where: { $0.id == Product.monthly.rawValue }),
              let yearly = products.first(where: { $0.id == Product.yearly.rawValue }) else { return nil }
        let twelveMonths = monthly.price * 12
        guard twelveMonths > 0, yearly.price < twelveMonths else { return nil }
        // Through `Double` deliberately. `Product.price` is a `Decimal` because money is, and
        // `Decimal` has no `rounded()`; the percentage is not money, it is a label on a badge.
        let ratio = NSDecimalNumber(decimal: (twelveMonths - yearly.price) / twelveMonths).doubleValue
        // Rounded down, not to nearest: 32.6% shown as "33%" is a discount the customer does not
        // get, which is the kind of claim App Review reads as a misleading price.
        return Int((ratio * 100).rounded(.down))
    }
}
