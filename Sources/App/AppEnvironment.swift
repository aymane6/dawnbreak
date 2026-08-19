import DawnbreakKit
import Foundation
import Observation
import SwiftUI

/// The object graph, assembled once.
///
/// One container rather than five separate `@Environment` values: the stores have to agree
/// on which directory they read, and the bridge needs a reference to two of them. Wiring
/// that in the view layer would mean every preview and every test rebuilding it by hand.
@MainActor
@Observable
final class AppEnvironment {
    let alarms: AlarmStore
    let log: WakeLogStore
    let preferences: Preferences
    let subscription: SubscriptionStore
    let bridge: AlarmBridge

    /// Which tab is showing. Held here rather than in the view so a deep link, or the
    /// paywall dismissing, can move the user without passing bindings down.
    var selectedTab: Tab = .alarms
    /// Set when a screen wants the paywall. Nil-ing it out dismisses.
    var paywallReason: PaywallReason?

    enum Tab: Hashable { case alarms, stats, settings }

    enum PaywallReason: String, Identifiable, Hashable, CaseIterable {
        case alarmLimit, premiumMission, difficultyLocked, roundsLocked, historyLocked, manual
        var id: String { rawValue }

        var headlineKey: String {
            switch self {
            case .alarmLimit: "paywall.reason.alarmLimit"
            case .premiumMission: "paywall.reason.premiumMission"
            case .difficultyLocked: "paywall.reason.difficulty"
            case .roundsLocked: "paywall.reason.rounds"
            case .historyLocked: "paywall.reason.history"
            case .manual: "paywall.reason.manual"
            }
        }
    }

    /// - Parameter entitlement: pins what the user is treated as having paid for, bypassing
    ///   StoreKit. Only the screenshot run passes it, so that a premium mission can be
    ///   photographed unlocked without a sandbox purchase; `nil` everywhere else, and then the
    ///   receipt is the only answer.
    init(
        directory: URL = StoreLocation.supportDirectory(),
        defaults: UserDefaults = .standard,
        entitlement: Entitlement? = nil
    ) {
        alarms = AlarmStore(directory: directory)
        log = WakeLogStore(directory: directory)
        preferences = Preferences(defaults: defaults)
        subscription = SubscriptionStore(pinnedEntitlement: entitlement)
        bridge = AlarmBridge.shared
        bridge.attach(alarms: alarms, log: log)
    }

    var entitlement: Entitlement { subscription.entitlement }

    /// The single gate every "can I do this" question goes through, so the free tier's
    /// limits are defined in one place instead of being re-derived in each view.
    func check(_ request: Request) -> PaywallReason? {
        switch request {
        case .addAlarm:
            alarms.alarms.count >= entitlement.maximumAlarms ? .alarmLimit : nil
        case .mission(let kind):
            entitlement.allows(kind) ? nil : .premiumMission
        case .difficulty(let level):
            entitlement.allows(level) ? nil : .difficultyLocked
        case .rounds(let count):
            count > entitlement.maximumRounds ? .roundsLocked : nil
        case .history(let days):
            days > entitlement.maximumHistoryDays ? .historyLocked : nil
        }
    }

    enum Request {
        case addAlarm
        case mission(MissionKind)
        case difficulty(Difficulty)
        case rounds(Int)
        case history(Int)
    }

    /// Returns true when the action is allowed; otherwise raises the paywall and returns
    /// false, so a call site reads `guard env.allow(.addAlarm) else { return }`.
    @discardableResult
    func allow(_ request: Request) -> Bool {
        guard let reason = check(request) else { return true }
        paywallReason = reason
        return false
    }
}

/// Read by every screen. The default value exists so SwiftUI previews compile; the real
/// app injects its own instance at the root.
extension EnvironmentValues {
    /// `assumeIsolated`, because `@Entry` generates a `nonisolated static var defaultValue` and
    /// `AppEnvironment` is `@MainActor`. The assumption holds: an environment default is only
    /// read while a view's body is being evaluated, which SwiftUI does on the main actor, and in
    /// the shipping app it is never read at all because `DawnbreakApp` injects its own instance
    /// at the root. What is left is previews. The alternative, an optional environment value,
    /// would put an unwrap in every one of the twenty views that reads it.
    @Entry var app: AppEnvironment = MainActor.assumeIsolated {
        AppEnvironment(directory: FileManager.default.temporaryDirectory)
    }
}
