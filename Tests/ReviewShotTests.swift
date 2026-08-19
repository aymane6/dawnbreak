import DawnbreakKit
import StoreKit
import StoreKitTest
import SwiftUI
import Testing
import UIKit
@testable import Dawnbreak

/// Where the picture goes, and whether anybody asked for one.
///
/// Empty on every ⌘U and every `release.sh` run, which is what keeps a screenshot out of an
/// ordinary test run; `scripts/shots.sh --review` passes it as
/// `TEST_RUNNER_DAWNBREAK_REVIEW_SHOT`, which is how xcodebuild forwards a variable into the
/// process the tests run in.
private let destination = ProcessInfo.processInfo.environment["DAWNBREAK_REVIEW_SHOT"] ?? ""

/// Used only for the bundle it belongs to.
private final class TestBundleMarker {}

/// The one screenshot Apple asks for that no customer ever sees: the purchase screen.
///
/// Every subscription and every in-app purchase is submitted with a picture of where it is sold,
/// and it is not one of the store screenshots. Those are framed, captioned, twelve languages of
/// marketing; this is evidence, in English, for one reviewer, of what the paywall promises and what
/// it charges. Submitting a product without it leaves it in MISSING_METADATA, which holds the
/// version back without saying why, so `scripts/iap.py` looks for the file this writes.
///
/// A unit test, and not the UI test this started as, because of where `SKTestSession` has to live.
/// A simulator has no App Store account, so `Product.products(for:)` answers nothing and the paywall
/// draws "Prices are not loading", which is what the first attempts at this shot photographed.
/// `SKTestSession` is the fix, and everything `storekitd` keeps for one is filed under a bundle id:
/// the log line is `saveConfigurationData` followed by `Saving Octane configuration for
/// com.aymbam.dawnbreak`. A session created in a UI test runner is therefore a configuration for
/// `com.aymbam.dawnbreak.uitests.xctrunner`, and the app it drives finds nothing. Neither a StoreKit
/// configuration in the scheme's Test action nor the session's private `setBundleID:` moved that. A
/// unit test bundle is loaded into the app itself, so here `Bundle.main` *is* the app and the session
/// configures the process that draws the screen.
///
/// That alone is not enough, and the missing half took four failed runs to find: `storekitd` refuses
/// the configuration outright for an app that is not a development install, with
/// `com.aymbam.dawnbreak is not installed for development`, and what it reads is `get-task-allow` in
/// the installed bundle. `scripts/shots.sh --review` passes an entitlements file that has it. Without
/// that, everything here runs, the session is created without complaint, and the `#require` below is
/// what fails.
///
/// What the design costs is the last of the realism: this renders the screen into a window of the
/// host app's own scene instead of photographing the device, so there is no status bar and the
/// paywall is full screen rather than inside the sheet `RootView` presents it in. It is still the
/// shipped view, at device scale, with the prices out of the file the products are submitted from.
///
/// The path a reviewer follows to this screen is checked separately, by
/// `SmokeTests.testTheFreeTierReachesThePaywallFromSettings`, which is the assertion the review
/// notes depend on.
@Suite("Review screenshot")
@MainActor
struct ReviewShotTests {

    @Test("The paywall, with the prices being submitted", .enabled(if: !destination.isEmpty))
    func capturePaywall() async throws {
        let session = try SKTestSession(contentsOf: try configurationFile())
        // A session inherits whatever the last run left behind, and a subscription still active
        // from an earlier one turns the paywall into a receipt.
        session.resetToDefaultState()
        session.clearTransactions()
        // Nothing is bought here, but a StoreKit dialog would land over the render.
        session.disableDialogs = true

        // Asked here rather than only through the store, because `loadProducts()` swallows the
        // error on purpose: an offline user does not need a failure on a paywall they did not ask
        // for. This run does, and the message is the difference between "the products are missing"
        // and knowing why.
        let identifiers = SubscriptionStore.Product.allCases.map(\.rawValue)
        let loaded = try await StoreKit.Product.products(for: identifiers)
        try #require(
            loaded.count == identifiers.count,
            """
            StoreKit answered with \(loaded.count) of \(identifiers.count) products in \
            \(Bundle.main.bundleIdentifier ?? "an unnamed bundle"), so there is nothing on the \
            paywall worth photographing. Ask the daemon why: `xcrun simctl spawn booted log show \
            --last 5m --style compact --predicate 'subsystem == "com.apple.storekit"'`. "is not \
            installed for development" means the app was built without get-task-allow, which is what \
            `scripts/shots.sh --review` passes and what running this test any other way does not. \
            Otherwise the session reads Configuration/Dawnbreak.storekit out of this bundle: check \
            that project.yml still copies it into DawnbreakTests, and that the ids in it are \
            \(identifiers.joined(separator: ", ")).
            """
        )

        let environment = try scratchEnvironment()
        await environment.subscription.loadProducts()
        try #require(
            environment.subscription.displayPrice(for: .yearly) != nil,
            "the products loaded but the paywall has no price for the yearly plan"
        )

        let scene = try #require(await foregroundScene(), "the host app never connected a window scene")
        let window = present(PaywallView(reason: .manual), in: scene, with: environment)
        defer { window.isHidden = true }

        // Laid out, then given a moment: SwiftUI runs the view's own `task` on the next turn of
        // the run loop, and an image taken on this one comes out as an empty canvas.
        window.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(700))

        let image = render(window)
        let png = try #require(image.pngData(), "the render produced no PNG")
        let directory = URL(filePath: destination, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appending(path: "paywall.png")
        try png.write(to: file, options: .atomic)

        // A blank window still encodes, and small. Not proof the paywall is on it, but it catches
        // the render that happened before the hierarchy existed.
        #expect(png.count > 40_000, "\(file.path) is too small to be a screenshot of anything")
    }

    // MARK: - The environment the screen needs

    /// The products, out of this bundle rather than the app's.
    ///
    /// `SKTestSession(configurationFileNamed:)` searches `Bundle.main`, which under a unit test is
    /// the app, and the app neither ships a StoreKit configuration nor should start to. project.yml
    /// copies the file in here instead, and it is the same one `scripts/iap.py` submits, so the
    /// prices in the picture are the prices being asked for.
    private func configurationFile() throws -> URL {
        let bundle = Bundle(for: TestBundleMarker.self)
        return try #require(
            bundle.url(forResource: "Dawnbreak", withExtension: "storekit"),
            "Dawnbreak.storekit is not in \(bundle.bundlePath): project.yml stopped copying it"
        )
    }

    /// A throwaway app environment, on the free tier.
    ///
    /// Its own directory and its own defaults, because the host app's are live: the paywall marks
    /// itself as seen when it opens, and a screenshot run has no business writing that into the
    /// simulator somebody debugs in next. Free rather than pro because that is the tier a reviewer
    /// downloads, and the only tier that can still be sold something.
    ///
    /// Constructing one also re-points `AlarmBridge.shared` at these stores, which is harmless
    /// here: nothing rings in this process, and the host app is left on screen behind the window.
    private func scratchEnvironment() throws -> AppEnvironment {
        let suite = "com.aymbam.dawnbreak.review-shot"
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "review-shot", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return AppEnvironment(directory: directory, defaults: defaults, entitlement: .free)
    }

    /// The host app's window scene, once it has one.
    ///
    /// A unit test bundle is loaded while the app launches, so the first line of a test can run
    /// before SwiftUI has connected a scene. Polled rather than assumed, because assuming gives a
    /// nil scene on a fast machine and a pass on a slow one.
    private func foregroundScene() async -> UIWindowScene? {
        for _ in 0..<50 {
            let active = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
            if let active { return active }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return nil
    }

    // MARK: - Drawing it

    /// The view, in a window of the app's own scene.
    ///
    /// The scene rather than a bare window, so the layout gets the device's real safe area: a
    /// window that has none of its own draws the toolbar under the notch. Above every other window,
    /// because the host app is sitting on its own root view behind this one.
    private func present(
        _ view: some View,
        in scene: UIWindowScene,
        with environment: AppEnvironment
    ) -> UIWindow {
        let window = UIWindow(windowScene: scene)
        window.frame = scene.effectiveGeometry.coordinateSpace.bounds
        // What a fresh install gets, and what the store screenshots are taken in.
        window.overrideUserInterfaceStyle = .dark
        window.windowLevel = .alert + 1
        window.rootViewController = UIHostingController(rootView: view.environment(\.app, environment))
        window.makeKeyAndVisible()
        return window
    }

    /// The window's own pixels, at the device's scale: 1320x2868 on the 6.9-inch simulator
    /// `scripts/shots.sh` boots, which is the size the store screenshots are.
    ///
    /// `drawHierarchy` rather than `layer.render(in:)`, which does not replay every effect into a
    /// context, and the sunrise in the header is a blur.
    private func render(_ window: UIWindow) -> UIImage {
        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = window.traitCollection.displayScale
        format.opaque = true
        return UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
    }
}
