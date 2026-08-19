// swift-tools-version: 6.0
import PackageDescription

// Foundation-only on purpose. Everything in here runs under `swift test` on the Mac,
// which is the only way to exercise mission logic and streak arithmetic without
// booting a simulator and waiting for an alarm to fire.
let package = Package(
    name: "DawnbreakKit",
    defaultLocalization: "en",
    // Spelled as strings rather than `.v26`, which this PackageDescription does not expose.
    platforms: [.iOS("26.0"), .macOS("15.0")],
    products: [
        .library(name: "DawnbreakKit", targets: ["DawnbreakKit"])
    ],
    targets: [
        .target(name: "DawnbreakKit"),
        .testTarget(name: "DawnbreakKitTests", dependencies: ["DawnbreakKit"])
    ]
)
