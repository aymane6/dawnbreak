import Foundation

/// A small atomic JSON file, used for the alarm list and the wake log.
///
/// Not SwiftData, on purpose. An alarm app is woken by the system at 06:00 in whatever
/// state the phone is in, reads its alarms, and must not fail: a schema migration that
/// throws on launch is a missed alarm. A single Codable file with a version tag can be
/// migrated in code and, in the worst case, recovered by hand.
public struct JSONFileStore<Value: Codable & Sendable>: Sendable {
    public let url: URL
    private let fallback: @Sendable () -> Value

    public init(url: URL, fallback: @escaping @Sendable () -> Value) {
        self.url = url
        self.fallback = fallback
    }

    /// Reads the file. A missing file is not an error — it is the first launch — and a
    /// *corrupt* file is not an error either: the corrupt copy is moved aside so it can be
    /// inspected, and the caller gets the fallback rather than a crash loop at 6am.
    public func load() -> Value {
        guard FileManager.default.fileExists(atPath: url.path) else { return fallback() }
        do {
            let data = try Data(contentsOf: url)
            return try Self.decoder.decode(Value.self, from: data)
        } catch {
            quarantine(reason: error)
            return fallback()
        }
    }

    /// Writes via a temporary file in the same directory and an atomic replace. Writing in
    /// place risks a half-written file if the app is killed mid-write, and a half-written
    /// alarm list is worse than a stale one.
    public func save(_ value: Value) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try Self.encoder.encode(value)
        let temporary = directory.appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString)")
        try data.write(to: temporary, options: .atomic)
        // `replaceItemAt` is the only call that is atomic across the whole swap; a
        // remove-then-move has a window where neither file exists.
        _ = try FileManager.default.replaceItemAt(url, withItemAt: temporary)
        try? excludeFromBackup()
    }

    /// The wake log is personal data with no value on another device, and the alarm list is
    /// small enough to recreate. Keeping both out of the iCloud backup is the privacy
    /// default; nothing here is ever uploaded anywhere.
    private func excludeFromBackup() throws {
        var mutable = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try mutable.setResourceValues(values)
    }

    private func quarantine(reason: any Error) {
        let broken = url.appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970))")
        try? FileManager.default.moveItem(at: url, to: broken)
        NSLog("[Dawnbreak] store at %@ was unreadable (%@); moved to %@",
              url.lastPathComponent, String(describing: reason), broken.lastPathComponent)
    }

    /// Fractional seconds are kept on purpose.
    ///
    /// Plain `.iso8601` truncates to the second, and `AlarmStore` breaks a sort tie on
    /// `createdAt`: two alarms added to the same minute in the same second would compare
    /// equal after a reload and the list would reorder itself between launches.
    public static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(StoreDateFormat.withFraction.format(date))
        }
        encoder.outputFormatting = [.sortedKeys]   // stable diffs when inspecting by hand
        return encoder
    }

    public static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            // Accepts both spellings, so a store written by a build that used plain
            // `.iso8601` still opens.
            if let date = try? StoreDateFormat.withFraction.parse(text) { return date }
            if let date = try? StoreDateFormat.withoutFraction.parse(text) { return date }
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "not an ISO-8601 date: \(text)")
            )
        }
        return decoder
    }
}

/// The two date spellings the stores accept.
///
/// A separate, non-generic type: a generic struct cannot hold a static stored property.
/// `Date.ISO8601FormatStyle` rather than `ISO8601DateFormatter` because the format style is
/// a `Sendable` value type, and the class is not — a shared `static let` of it does not
/// compile under Swift 6's concurrency checking.
enum StoreDateFormat {
    static let withFraction = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    static let withoutFraction = Date.ISO8601FormatStyle()
}

/// Where the stores live.
///
/// Deliberately not a static on `JSONFileStore`: spelling it `JSONFileStore<Payload>.supportDirectory()`
/// in a public initialiser's default argument would leak the internal `Payload` type into
/// the public signature, which does not compile.
public enum StoreLocation {
    /// The shared app-group identifier. The widget extension draws the Live Activity from
    /// the alarm label and mission name, so those have to be readable outside the app
    /// sandbox.
    public static let appGroup = "group.com.aymbam.dawnbreak"

    /// The app's own support directory, created on demand by the first write.
    public static func supportDirectory(appGroup: String? = Self.appGroup) -> URL {
        if let appGroup, let shared = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) {
            return shared.appendingPathComponent("Dawnbreak", isDirectory: true)
        }
        // No group container means either the entitlement is missing or this is a unit test
        // on the Mac. Both want a plain sandboxed directory rather than a crash.
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL.temporaryDirectory
        return base.appendingPathComponent("Dawnbreak", isDirectory: true)
    }
}
