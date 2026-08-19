import Foundation

/// One of the twelve languages the app ships in, with the three different spellings it needs.
///
/// The same language is written three ways by three different systems and none of them agree:
/// the bundle calls Brazilian Portuguese `pt-BR`, `-AppleLocale` wants `pt_BR`, and App Store
/// Connect wants `pt-BR` for the listing but `ar-SA` for the Arabic one whose screenshots are
/// taken on an Egyptian clock. Written out once here, so the screenshot directory a run produces
/// is already named the way the upload expects, and the mapping cannot be got wrong twice.
///
/// Compiled into the app target as well as the test target. Nothing in the app reads it, and the
/// cost is a few hundred bytes; what it buys is that `LocalizationTests` can check this table
/// against `CFBundleLocalizations` in the built bundle and against the `.lproj` folders the
/// compiler actually produced. A fourth list of languages in a shell script would be checked by
/// nothing.
struct CaptureLocale: Hashable, Sendable, Identifiable {
    /// The `.lproj` and `CFBundleLocalizations` spelling, and the value `-AppleLanguages` takes.
    let language: String

    /// What goes after `-AppleLocale`, which is what decides the clock format, the digits and
    /// the first day of the week in the screenshots.
    ///
    /// The region is a choice, not a formality. `ar_EG` rather than `ar_SA` because Saudi phones
    /// default to the Umm al-Qura calendar, and the stats screen would then show Hijri dates in
    /// a screenshot sitting next to eleven Gregorian ones. `en_US` for the primary listing, so
    /// the clock reads 6:15 AM.
    let appleLocale: String

    /// The App Store Connect locale code, which is also the folder name under `metadata/` and
    /// under the screenshot output directory.
    let store: String

    var id: String { store }

    /// What has to be on the app's command line for it to come up in this language.
    ///
    /// The parentheses are not decoration: `AppleLanguages` is an array in the defaults system,
    /// and the command-line parser only reads it as one when it is written this way.
    var launchArguments: [String] {
        ["-AppleLanguages", "(\(language))", "-AppleLocale", appleLocale]
    }

    /// Whether the screenshots of this language are mirrored.
    ///
    /// Asked of Foundation rather than kept as a flag next to the row, because a hand-maintained
    /// `isRTL: true` is a thing to forget on the day a thirteenth language is added.
    var isRightToLeft: Bool {
        Locale.Language(identifier: language).characterDirection == .rightToLeft
    }

    /// What has to be written into the simulator's own preferences for the *system* to be in this
    /// language, as opposed to the app.
    ///
    /// The status bar is drawn by SpringBoard, not by the app, so `-AppleLanguages` on the app's
    /// command line does not reach it: an Arabic screenshot taken on an English simulator has a
    /// left-to-right status bar with Latin digits above a mirrored Arabic screen, which is the kind
    /// of detail that tells a reader the listing was assembled rather than made. `scripts/shots.sh`
    /// writes these into the global domain and resprings before each language.
    ///
    /// A tuple of `defaults write` arguments rather than a shell command, because the value has to
    /// be quoted by whoever runs it, and building shell syntax in Swift is how a locale with a
    /// hyphen in it stops working.
    var systemLanguageDefaults: [(key: String, value: String)] {
        [("AppleLanguages", language), ("AppleLocale", appleLocale)]
    }

    static let english = CaptureLocale(language: "en", appleLocale: "en_US", store: "en-US")
    static let arabic = CaptureLocale(language: "ar", appleLocale: "ar_EG", store: "ar-SA")
    static let german = CaptureLocale(language: "de", appleLocale: "de_DE", store: "de-DE")
    static let spanish = CaptureLocale(language: "es", appleLocale: "es_ES", store: "es-ES")
    static let french = CaptureLocale(language: "fr", appleLocale: "fr_FR", store: "fr-FR")
    static let hindi = CaptureLocale(language: "hi", appleLocale: "hi_IN", store: "hi")
    static let italian = CaptureLocale(language: "it", appleLocale: "it_IT", store: "it")
    static let japanese = CaptureLocale(language: "ja", appleLocale: "ja_JP", store: "ja")
    static let korean = CaptureLocale(language: "ko", appleLocale: "ko_KR", store: "ko")
    static let portuguese = CaptureLocale(language: "pt-BR", appleLocale: "pt_BR", store: "pt-BR")
    static let russian = CaptureLocale(language: "ru", appleLocale: "ru_RU", store: "ru")
    static let chinese = CaptureLocale(language: "zh-Hans", appleLocale: "zh_CN", store: "zh-Hans")

    /// English first, then alphabetical by language: the same order as the translation tables in
    /// `scripts/strings`, and the order the screenshot run photographs them in. English leads
    /// because it is the fallback and the listing that gets read most, so a run that is going to
    /// fail should fail on it rather than eleven languages later.
    static let all: [CaptureLocale] = [
        .english, .arabic, .german, .spanish, .french, .hindi,
        .italian, .japanese, .korean, .portuguese, .russian, .chinese,
    ]
}
