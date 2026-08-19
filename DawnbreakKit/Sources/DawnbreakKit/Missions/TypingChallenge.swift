import Foundation

/// The retype-this-sentence mission.
///
/// The sentences are *keys*, not text: the app resolves them through the string catalog so
/// a Japanese user retypes a Japanese sentence. Asking someone to retype English at 6am on
/// a Japanese keyboard is not a wake-up challenge, it is a wall.
public struct TypingChallenge: Hashable, Sendable {
    /// Key into the string catalog, e.g. `typing.sentence.07`.
    public let sentenceKey: String
    /// Resolved text, filled in by the app once the catalog has been consulted. The model
    /// carries it so comparison logic stays here and stays testable.
    public var sentence: String

    public static let sentenceKeyCount = 24

    public static func make(wordCount: Int, using generator: inout some RandomNumberGenerator) -> TypingChallenge {
        // The catalog holds sentences grouped by length band; picking by band keeps the
        // difficulty honest across languages, where a "7 word" sentence in German and in
        // Thai are wildly different lengths in characters.
        let band = LengthBand(wordCount: wordCount)
        let index = Int.random(in: 0..<band.count, using: &generator)
        let key = "typing.sentence.\(band.rawValue).\(index)"
        return TypingChallenge(sentenceKey: key, sentence: "")
    }

    public static func make(wordCount: Int) -> TypingChallenge {
        var g = SystemRandomNumberGenerator()
        return make(wordCount: wordCount, using: &g)
    }

    public enum LengthBand: String, Sendable, CaseIterable {
        case short, medium, long, epic

        init(wordCount: Int) {
            switch wordCount {
            case ..<6: self = .short
            case 6..<10: self = .medium
            case 10..<14: self = .long
            default: self = .epic
            }
        }

        /// How many sentences exist per band in the catalog. Must match the catalog or the
        /// mission shows a raw key, so `DawnbreakTests.LocalizationTests` resolves every one of
        /// them in every language: the kit cannot check it itself, having no bundle to read.
        public var count: Int { 6 }
    }

    /// Compares what was typed against the sentence.
    ///
    /// Forgiving about the things a phone keyboard decides for you and unforgiving about
    /// the rest: case, curly vs straight apostrophes, and runs of whitespace are ignored;
    /// missing words are not. Trailing punctuation the autocorrect adds is tolerated.
    public func accepts(_ typed: String) -> Bool {
        Self.normalise(typed) == Self.normalise(sentence)
    }

    /// How much of the sentence is correct so far, 0…1, for the progress bar.
    public func progress(of typed: String) -> Double {
        let target = Self.normalise(sentence)
        guard !target.isEmpty else { return 0 }
        let input = Self.normalise(typed)
        let shared = zip(target, input).prefix { $0 == $1 }.count
        return min(1, Double(shared) / Double(target.count))
    }

    /// Index of the first character that diverges, so the field can underline it in red.
    public func firstMismatch(in typed: String) -> Int? {
        let target = Array(Self.normalise(sentence))
        let input = Array(Self.normalise(typed))
        for i in input.indices {
            guard i < target.count else { return i }
            if input[i] != target[i] { return i }
        }
        return nil
    }

    static func normalise(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            // Folds accents and case together, and folds the width of CJK punctuation,
            // which is what a Japanese keyboard produces for a full stop.
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: ".。!！?？"))
    }
}

/// The draw-this mission.
///
/// Each prompt pairs a localized noun shown to the user with the English label the on-device
/// classifier actually emits. The two are not the same string and conflating them is how a
/// French user gets told to draw "bateau" and then fails because Vision said "boat".
public struct DrawingPrompt: Hashable, Sendable, Identifiable {
    /// The classifier label to match, always English.
    public let visionLabel: String
    /// Additional labels that should also count. Vision is confident about "sailboat" when
    /// shown a child's drawing of a boat, and refusing that is indefensible.
    public let acceptedLabels: [String]
    /// Key into the string catalog for the word the user reads.
    public let nameKey: String

    public var id: String { visionLabel }

    public static let all: [DrawingPrompt] = [
        DrawingPrompt(visionLabel: "boat", acceptedLabels: ["sailboat", "ship", "watercraft", "vessel"], nameKey: "draw.prompt.boat"),
        DrawingPrompt(visionLabel: "house", acceptedLabels: ["building", "home", "cottage", "hut"], nameKey: "draw.prompt.house"),
        DrawingPrompt(visionLabel: "tree", acceptedLabels: ["plant", "conifer", "foliage"], nameKey: "draw.prompt.tree"),
        DrawingPrompt(visionLabel: "star", acceptedLabels: ["asterisk", "starfish"], nameKey: "draw.prompt.star"),
        DrawingPrompt(visionLabel: "fish", acceptedLabels: ["shark", "aquatic_animal"], nameKey: "draw.prompt.fish"),
        DrawingPrompt(visionLabel: "cat", acceptedLabels: ["feline", "kitten"], nameKey: "draw.prompt.cat"),
        DrawingPrompt(visionLabel: "car", acceptedLabels: ["vehicle", "automobile", "truck"], nameKey: "draw.prompt.car"),
        DrawingPrompt(visionLabel: "flower", acceptedLabels: ["blossom", "petal", "plant"], nameKey: "draw.prompt.flower"),
        DrawingPrompt(visionLabel: "sun", acceptedLabels: ["sunlight", "star"], nameKey: "draw.prompt.sun"),
        DrawingPrompt(visionLabel: "umbrella", acceptedLabels: ["parasol"], nameKey: "draw.prompt.umbrella"),
        DrawingPrompt(visionLabel: "key", acceptedLabels: ["lock"], nameKey: "draw.prompt.key"),
        DrawingPrompt(visionLabel: "cup", acceptedLabels: ["mug", "glass", "drinkware"], nameKey: "draw.prompt.cup"),
        DrawingPrompt(visionLabel: "clock", acceptedLabels: ["watch", "timepiece"], nameKey: "draw.prompt.clock"),
        DrawingPrompt(visionLabel: "bicycle", acceptedLabels: ["bike", "cycle"], nameKey: "draw.prompt.bicycle"),
        DrawingPrompt(visionLabel: "heart", acceptedLabels: [], nameKey: "draw.prompt.heart"),
        DrawingPrompt(visionLabel: "moon", acceptedLabels: ["crescent"], nameKey: "draw.prompt.moon")
    ]

    public static func random(using generator: inout some RandomNumberGenerator) -> DrawingPrompt {
        all.randomElement(using: &generator)!
    }

    /// True when any of the classifier's top observations matches this prompt above
    /// `threshold`. Matching is case- and separator-insensitive because Vision emits
    /// `bell_pepper` in some taxonomies and `bell pepper` in others.
    public func matches(observations: [(label: String, confidence: Float)], threshold: Float) -> Bool {
        let wanted = Set(([visionLabel] + acceptedLabels).map(Self.canonical))
        return observations.contains { wanted.contains(Self.canonical($0.label)) && $0.confidence >= threshold }
    }

    /// Folds every separator away rather than normalising them to a space.
    ///
    /// Vision's taxonomies are not consistent with themselves: the same concept arrives as
    /// `sailboat`, `sail_boat` and `Sail-Boat` depending on the model and the OS build.
    /// Normalising separators *to* a space still leaves "sail boat" ≠ "sailboat", which is
    /// how a correct drawing gets rejected. Removing them entirely makes all three equal.
    ///
    /// Public because the photo mission compares an enrolled label the same way, and two
    /// implementations of "is this the same label" would eventually disagree.
    public static func canonical(_ label: String) -> String {
        label.lowercased().filter { !$0.isWhitespace && $0 != "_" && $0 != "-" }
    }
}
