import DawnbreakKit
import Foundation
import Testing
@testable import Dawnbreak

/// The paywall makes six countable promises, and every one of them is a number that lives in code.
///
/// "All twelve missions" is not a slogan, it is `MissionKind.allCases.count`. Raise the free
/// allowance to two alarms and "Free gives you one" becomes a false statement on a screen that
/// takes money, which is both a review rejection and the kind of thing that gets an app called a
/// scam in a one-star review. This suite reads the shipped English copy and checks each claim
/// against the code that enforces it.
///
/// English only, deliberately. The other eleven translate this copy; if a number changes, the
/// English row is the one that has to change first, and `make_strings.py` will not let the rest
/// drift out of shape.
@Suite("Paywall copy")
struct PaywallCopyTests {

    private var english: [String: String] { Catalog.strings(Catalog.developmentLanguage) }

    /// A number the copy spells out, and the code that has to keep it true.
    struct Claim: Sendable, CustomTestStringConvertible {
        let key: String
        let word: String
        let actual: Int

        var testDescription: String { "\(key) says \(word)" }
    }

    private static let claims: [Claim] = [
        Claim(key: "paywall.feature.missions", word: "twelve", actual: MissionKind.allCases.count),
        Claim(key: "paywall.feature.missions.body", word: "three", actual: Entitlement.free.availableMissions.count),
        Claim(key: "paywall.feature.alarms", word: "twenty-five", actual: Entitlement.pro.maximumAlarms),
        Claim(key: "paywall.feature.alarms.body", word: "one", actual: Entitlement.free.maximumAlarms),
        Claim(key: "paywall.feature.difficulty.body", word: "ten", actual: MissionConfig.maxRounds),
        Claim(key: "paywall.subhead", word: "twelve", actual: MissionKind.allCases.count),
        Claim(key: "paywall.subhead", word: "twenty-five", actual: Entitlement.pro.maximumAlarms),
    ]

    /// The number each word spells, so the copy can be read back as an integer.
    private static let numbers: [String: Int] = [
        "one": 1, "three": 3, "ten": 10, "twelve": 12, "twenty-five": 25,
    ]

    @Test("Every number the paywall spells out is the number the code enforces", arguments: claims)
    func copyMatchesTheEntitlement(claim: Claim) throws {
        let copy = try #require(english[claim.key], "\(claim.key) is not in the catalog")
        #expect(copy.localizedCaseInsensitiveContains(claim.word), "\(claim.key) no longer says \(claim.word): \(copy)")
        #expect(Self.numbers[claim.word] == claim.actual, "\(claim.key) promises \(claim.word), the code allows \(claim.actual)")
    }

    @Test("The stats promise matches the longest window the screen offers, and only Pro gets it")
    func statsWindowClaimIsTrue() throws {
        let copy = try #require(english["paywall.feature.stats"])
        #expect(copy.localizedCaseInsensitiveContains("ninety"))
        let longest = StatsView.Window.allCases.map(\.rawValue).max()
        #expect(longest == 90)
        // Three separate places said "ninety days" while the picker was ungated, which made the
        // paywall advertise something the free tier already had. The window the screen offers, the
        // number Pro is granted and the number free is refused all have to line up.
        #expect(Entitlement.pro.maximumHistoryDays == longest)
        #expect(Entitlement.free.maximumHistoryDays < Entitlement.pro.maximumHistoryDays)
    }

    @Test("The free tier is what the paywall says it withholds")
    func freeTierIsWhatItClaims() {
        // Three missions, and specifically these three. Shake needs the accelerometer, which every
        // iPhone has; what the free tier must never require is the camera, because a free tier
        // gated on a permission the user can refuse is a free tier that can end up unusable.
        #expect(Set(Entitlement.free.availableMissions) == [.math, .shake, .breathe])
        #expect(Entitlement.free.availableMissions.allSatisfy { $0.requiredCapability != .camera })
        #expect(Entitlement.free.availableMissions.allSatisfy { !$0.needsEnrollment })
        #expect(Entitlement.free.maximumAlarms == 1)
        #expect(Entitlement.free.maximumRounds == 1)
        #expect(!Entitlement.free.allows(Difficulty.hard))
        #expect(!Entitlement.free.allows(Difficulty.brutal))
        #expect(Entitlement.free.allows(Difficulty.medium))
    }

    @Test("Pro withholds nothing")
    func proUnlocksEverything() {
        #expect(Entitlement.pro.availableMissions.count == MissionKind.allCases.count)
        #expect(Difficulty.allCases.allSatisfy(Entitlement.pro.allows))
        #expect(Entitlement.pro.maximumRounds == MissionConfig.maxRounds)
    }

    @Test("The legal copy the App Store requires is present")
    func legalCopyIsPresent() throws {
        // Review rejects a subscription paywall without these two, and the restore affordance.
        // Checked here rather than trusted to a screenshot, because the copy is one string away
        // from disappearing.
        for key in ["paywall.legal", "paywall.cta.note", "paywall.restore"] {
            let copy = try #require(english[key], "\(key) is missing")
            #expect(!copy.isEmpty)
        }
        #expect(english["paywall.legal"]?.localizedCaseInsensitiveContains("cancel") == true)
    }

    @Test("Every plan the store sells has a name on the paywall", arguments: SubscriptionStore.Product.allCases)
    func everyPlanIsNamed(plan: SubscriptionStore.Product) {
        #expect(english[plan.titleKey]?.isEmpty == false, "\(plan.titleKey) has no name")
        // The product identifier is what App Store Connect has to be configured with, so a typo
        // here sells nothing at all.
        #expect(plan.rawValue.hasPrefix("com.aymbam.dawnbreak.pro."))
    }

    @Test("Exactly one plan is recommended")
    func oneRecommendation() {
        #expect(SubscriptionStore.Product.allCases.count(where: \.isRecommended) == 1)
    }
}
