import DawnbreakKit
import Foundation
import Testing
@testable import Dawnbreak

/// Twelve languages is a promise made in `CFBundleLocalizations` and on twelve App Store pages.
/// These tests are what makes it checkable: every key resolved in every language, every format
/// specifier accounted for, every plural rule the language actually has.
///
/// The keys the code derives from an enum are the reason this suite exists in the app target
/// rather than in the kit. `MissionKind.titleKey` builds `mission.squats.title` at runtime; add a
/// thirteenth mission and nothing fails to compile, the mission simply shows `mission.yoga.title`
/// to everyone. Here, it fails.
@Suite("Localization")
struct LocalizationTests {

    /// Every key the app builds from an enum case rather than writing as a literal.
    static var derivedKeys: [String] {
        var keys: [String] = []
        keys += MissionKind.allCases.flatMap { [$0.titleKey, $0.subtitleKey, $0.instructionKey] }
        keys += Difficulty.allCases.map(\.titleKey)
        keys += AlarmSound.allCases.map(\.titleKey)
        keys += Weekday.allCases.flatMap { [$0.localizationKey, $0.shortLocalizationKey] }
        keys += Preferences.Appearance.allCases.map(\.titleKey)
        keys += WakeRecord.Outcome.allCases.map(\.titleKey)
        keys += DrawingPrompt.all.map(\.nameKey)
        keys += TypingChallenge.LengthBand.allCases.flatMap { band in
            (0..<band.count).map { "typing.sentence.\(band.rawValue).\($0)" }
        }
        keys += StatsView.Window.allCases.map(\.titleKey)
        keys += CaptureLaunch.Screen.allCases.flatMap { [$0.captionKey, $0.subcaptionKey] }
        keys += SubscriptionStore.Product.allCases.map(\.titleKey)
        keys += AppEnvironment.PaywallReason.allCases.map(\.headlineKey)
        return keys
    }

    @Test("Every declared language has a compiled catalog in the bundle")
    func everyLanguageIsBuilt() {
        for locale in Catalog.locales {
            #expect(Catalog.isBuilt(locale), "\(locale).lproj/Localizable.strings is not in the app")
        }
        let declared = Bundle.main.object(forInfoDictionaryKey: "CFBundleLocalizations") as? [String]
        #expect(declared.map(Set.init) == Set(Catalog.locales), "CFBundleLocalizations: \(declared ?? [])")
    }

    @Test("The screenshot run photographs exactly the languages the app ships")
    func captureLocalesMatchTheBundle() {
        // Four lists say which languages this app has: the Python tables, `CFBundleLocalizations`,
        // the `.lproj` folders the compiler produced, and `CaptureLocale.all`, which is what the
        // screenshot run and the App Store upload iterate over. The first three are checked
        // against each other above and by `make_strings.py`; this is the one that closes the loop,
        // because a language missing from `CaptureLocale.all` fails nothing at all. It ships, and
        // its App Store page has English screenshots.
        #expect(CaptureLocale.all.map(\.language).sorted() == Catalog.locales.sorted())
        #expect(Set(CaptureLocale.all.map(\.store)).count == CaptureLocale.all.count, "two languages want the same store folder")
        #expect(CaptureLocale.all.first == .english, "English is photographed first, so a broken run breaks on it")
    }

    @Test("Every screenshot locale is spelled the way each system spells it", arguments: CaptureLocale.all)
    func captureLocaleSpellingsAreConsistent(locale: CaptureLocale) {
        // `-AppleLocale` has to name the same language it is a region of, or the screenshots come
        // out in one language on another language's clock.
        let language = locale.appleLocale.split(separator: "_").first.map(String.init) ?? ""
        #expect(locale.language.hasPrefix(language), "\(locale.appleLocale) is not a \(locale.language) region")
        // App Store Connect codes are `ja` or `pt-BR`, never `pt_BR`, and it rejects the whole
        // metadata upload on an unknown one.
        #expect(!locale.store.contains("_"), "\(locale.store) is not an App Store Connect code")
        #expect(locale.store.hasPrefix(String(locale.language.prefix(2))), "\(locale.store) is not a \(locale.language) listing")
        #expect(locale.isRightToLeft == (locale.language == "ar"), "Arabic is the only mirrored language shipped")

        // What `shots.sh` writes into the simulator's global domain to put the status bar in this
        // language. The keys are the two Foundation reads at startup; a typo in either is a
        // screenshot whose clock is in English above a screen that is not, and nothing else here
        // would notice.
        let defaults = locale.systemLanguageDefaults
        #expect(defaults.map(\.key) == ["AppleLanguages", "AppleLocale"])
        #expect(defaults.map(\.value) == [locale.language, locale.appleLocale])
    }

    @Test("The English catalog is the whole catalog")
    func englishIsPopulated() {
        // A sanity floor on the reader itself. Every assertion below is "the other eleven match
        // English", which passes trivially if English came back empty because the table moved.
        #expect(Catalog.keys(Catalog.developmentLanguage).count > 400)
    }

    @Test("No language is missing a key", arguments: Catalog.locales)
    func nothingIsUntranslated(locale: String) {
        let missing = Catalog.keys(Catalog.developmentLanguage)
            .subtracting(Catalog.keys(locale))
            .sorted()
        #expect(missing.isEmpty, "\(locale) has no value for \(missing.count) keys: \(missing.prefix(8).joined(separator: ", "))")
    }

    @Test("No value is blank or left as its own key", arguments: Catalog.locales)
    func noValueIsAPlaceholder(locale: String) {
        for (key, value) in Catalog.strings(locale) {
            #expect(!value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(locale): \(key) is blank")
            #expect(value != key, "\(locale): \(key) was left as the key itself")
        }
    }

    /// The eleven, not the twelve: English cannot differ from itself, and `#expect` has no skip.
    static let translatedLocales = Catalog.locales.filter { $0 != Catalog.developmentLanguage }

    @Test("A translated language does not read as English", arguments: LocalizationTests.translatedLocales)
    func translationsDiffer(locale: String) {
        let english = Catalog.strings(Catalog.developmentLanguage)
        let mine = Catalog.strings(locale)
        // Some values are genuinely identical across languages: "AM", a bare "%lld", a product
        // name. Half is far below any honest translation and far above a copied file, which is
        // the failure this catches: twelve .lproj folders all holding English.
        let identical = mine.filter { english[$0.key] == $0.value }.count
        #expect(Double(identical) < Double(mine.count) * 0.5, "\(locale): \(identical) of \(mine.count) values are the English ones")
    }

    @Test("Format specifiers match English", arguments: Catalog.locales)
    func specifiersMatchEnglish(locale: String) {
        let english = Catalog.strings(Catalog.developmentLanguage)
        for (key, value) in Catalog.strings(locale) {
            guard let source = english[key] else { continue }
            // Sorted, not ordered: Japanese writes the clock as "%2$@%1$@" and that is the whole
            // point of positional specifiers. What must not differ is which arguments appear. A
            // dropped `%2$lld` loses a number silently; a `%@` where English has `%lld` crashes.
            #expect(
                Catalog.specifiers(value).sorted() == Catalog.specifiers(source).sorted(),
                "\(locale): \(key) takes \(Catalog.specifiers(value)) where English takes \(Catalog.specifiers(source))"
            )
        }
    }

    @Test("Plural entries declare exactly the categories the language has", arguments: Catalog.locales)
    func pluralCategoriesFollowCLDR(locale: String) throws {
        let expected = try #require(Catalog.cldrPluralCategories[locale])
        let pluralKeys = Set(Catalog.plurals(Catalog.developmentLanguage).keys)
        #expect(!pluralKeys.isEmpty, "no plural entries compiled at all")

        for key in pluralKeys.sorted() {
            let categories = Catalog.pluralCategories(key, in: locale)
            #expect(categories == expected, "\(locale): \(key) declares \(categories?.sorted() ?? []), CLDR wants \(expected.sorted())")
        }
    }

    @Test("Every key derived from an enum resolves", arguments: Catalog.locales)
    func derivedKeysResolve(locale: String) {
        let available = Catalog.keys(locale)
        for key in Self.derivedKeys {
            #expect(available.contains(key), "\(locale): nothing answers to \(key)")
        }
    }

    @Test("The typing mission's sentence count matches the catalog")
    func typingSentencesAreAllPresent() {
        let bands = TypingChallenge.LengthBand.allCases
        let claimed = bands.reduce(0) { $0 + $1.count }
        #expect(claimed == TypingChallenge.sentenceKeyCount)

        // The other direction, which is the one that catches a sentence added to the catalog and
        // never offered to anyone: the catalog must hold exactly what the bands can ask for.
        let inCatalog = Catalog.keys(Catalog.developmentLanguage).filter { $0.hasPrefix("typing.sentence.") }
        #expect(inCatalog.count == claimed, "catalog holds \(inCatalog.count) sentences, the bands ask for \(claimed)")
    }

    @Test("The permission prompts iOS draws are translated", arguments: Catalog.locales)
    func permissionPromptsAreTranslated(locale: String) {
        let usage = Catalog.strings(locale, table: "InfoPlist")
        for key in ["NSAlarmKitUsageDescription", "NSCameraUsageDescription", "NSMotionUsageDescription"] {
            let value = usage[key]
            #expect(value?.isEmpty == false, "\(locale): \(key) is not translated")
        }
    }

    @Test("Arabic is built, because it is the only right-to-left language shipped")
    func arabicIsPresent() {
        // Called out on its own because Arabic is the language that exercises the mirrored
        // layout and the screenshot compositor's RTL path. Losing it would not fail anything
        // else here, only the eleven remaining languages would keep passing.
        #expect(Catalog.isBuilt("ar"))
        #expect(Catalog.strings("ar").count > 400)
    }
}
