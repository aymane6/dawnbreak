import Foundation

/// Reads the *built* String Catalogs back out of the app bundle.
///
/// `Resources/Localizable.xcstrings` is one JSON file in the repo. By the time it is inside the
/// app it is twelve compiled `.strings` and `.stringsdict` tables under `<locale>.lproj/`, and
/// this reads that side of the build on purpose: `scripts/make_strings.py` already checks the JSON
/// against the Swift sources, so what is left to catch is everything that happens afterwards. A
/// catalog left out of the target's resources, a locale Xcode declined to compile, a `pt-BR` that
/// shipped as `pt`, an entry whose plural variants were dropped. None of those are visible from
/// the repo, and all of them ship a raw key onto somebody's lock screen.
enum Catalog {
    /// The twelve languages, in `CFBundleLocalizations` order. Written out here rather than read
    /// from the Info.plist, so a locale quietly dropped from that list fails a test instead of
    /// shrinking the set of languages the tests check.
    static let locales = [
        "ar", "de", "en", "es", "fr", "hi", "it", "ja", "ko", "pt-BR", "ru", "zh-Hans",
    ]

    static let developmentLanguage = "en"

    /// Plural categories each language distinguishes, straight from CLDR.
    ///
    /// Copied from the specification rather than imported from the generator's own table, because
    /// this is the second opinion on that table. Sharing one list would make both sides agree on
    /// the same mistake.
    static let cldrPluralCategories: [String: Set<String>] = [
        "en": ["one", "other"],
        "ar": ["zero", "one", "two", "few", "many", "other"],
        "de": ["one", "other"],
        "es": ["one", "many", "other"],
        "fr": ["one", "many", "other"],
        "hi": ["one", "other"],
        "it": ["one", "many", "other"],
        "ja": ["other"],
        "ko": ["other"],
        "pt-BR": ["one", "many", "other"],
        "ru": ["one", "few", "many", "other"],
        "zh-Hans": ["other"],
    ]

    // MARK: - Tables

    /// The flat entries of a table: key to translated value.
    static func strings(_ locale: String, table: String = "Localizable") -> [String: String] {
        plist(table, "strings", locale).compactMapValues { $0 as? String }
    }

    /// The plural entries, keyed the same way. Value is the raw `.stringsdict` entry.
    static func plurals(_ locale: String, table: String = "Localizable") -> [String: [String: Any]] {
        plist(table, "stringsdict", locale).compactMapValues { $0 as? [String: Any] }
    }

    /// Every key a locale can answer for, flat and plural together.
    static func keys(_ locale: String, table: String = "Localizable") -> Set<String> {
        Set(strings(locale, table: table).keys).union(plurals(locale, table: table).keys)
    }

    /// The categories a locale's `.stringsdict` actually declares for a plural key, or nil when
    /// the key is not a plural entry there.
    static func pluralCategories(_ key: String, in locale: String) -> Set<String>? {
        guard let entry = plurals(locale)[key] else { return nil }
        // The substitution is the one value that is itself a dictionary describing a rule; its
        // name is chosen per key ("days", "snoozes"), so it is found by shape, not by name.
        guard let substitution = entry.values.compactMap({ $0 as? [String: Any] })
            .first(where: { $0["NSStringFormatSpecTypeKey"] != nil }) else { return nil }
        return Set(substitution.keys).subtracting([
            "NSStringFormatSpecTypeKey", "NSStringFormatValueTypeKey",
        ])
    }

    private static func plist(_ table: String, _ ext: String, _ locale: String) -> [String: Any] {
        guard let url = url(table, ext, locale),
              let data = try? Data(contentsOf: url),
              let object = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dictionary = object as? [String: Any]
        else { return [:] }
        return dictionary
    }

    private static func url(_ table: String, _ ext: String, _ locale: String) -> URL? {
        if let url = Bundle.main.url(forResource: table, withExtension: ext, subdirectory: "\(locale).lproj") {
            return url
        }
        // Xcode writes the development language into Base.lproj in some project shapes. Only the
        // place en is read from changes; a missing translation still fails.
        guard locale == developmentLanguage else { return nil }
        return Bundle.main.url(forResource: table, withExtension: ext, subdirectory: "Base.lproj")
    }

    /// True when the bundle has a compiled directory for the language at all, which is the
    /// difference between "translated badly" and "not shipped".
    static func isBuilt(_ locale: String) -> Bool {
        url("Localizable", "strings", locale) != nil
    }

    // MARK: - Format specifiers

    /// `%1$lld`, `%lld`, `%@`, `%.1f`. Not the `%%` that renders a literal percent sign, which is
    /// removed first so `−%lld%%` reports one argument rather than two.
    static func specifiers(_ value: String) -> [String] {
        // Built per call: `Regex` is not `Sendable`, so it cannot be a static let under strict
        // concurrency, and these tables are small enough that it does not matter.
        let specifier = /%(?:[0-9]+\$)?[-+ 0#]*[0-9]*(?:\.[0-9]+)?(?:l{0,2}[du]|@|f)/
        return value.replacingOccurrences(of: "%%", with: "")
            .matches(of: specifier)
            .map { String($0.output) }
    }
}
