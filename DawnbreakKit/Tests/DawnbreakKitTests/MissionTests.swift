import Foundation
import Testing
@testable import DawnbreakKit

/// A seeded generator, so "easy maths is never negative" is a proof over many draws rather
/// than a hope about one.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        // splitmix64
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

@Suite("Maths mission")
struct MathChallengeTests {

    @Test("Easy never asks for a negative answer", arguments: 0..<200)
    func easyStaysPositive(seed: Int) {
        var generator = SeededGenerator(seed: UInt64(seed) + 1)
        let challenge = MathChallenge.make(MissionConfig(kind: .math, difficulty: .easy).math, using: &generator)
        #expect(challenge.answer >= 0)
    }

    @Test("Easy uses single-digit operands only", arguments: 0..<200)
    func easyIsSingleDigit(seed: Int) {
        var generator = SeededGenerator(seed: UInt64(seed) + 1)
        let challenge = MathChallenge.make(MissionConfig(kind: .math, difficulty: .easy).math, using: &generator)
        #expect((1...9).contains(challenge.left))
        #expect((1...9).contains(challenge.right))
    }

    @Test("Multiplication stays head-solvable even at brutal", arguments: 0..<200)
    func multiplicationIsBounded(seed: Int) {
        var generator = SeededGenerator(seed: UInt64(seed) + 1)
        let challenge = MathChallenge.make(MissionConfig(kind: .math, difficulty: .brutal).math, using: &generator)
        if challenge.op == .multiply {
            // Three digits times twelve at most: hard, not a calculator task.
            #expect(challenge.right <= 12)
        }
    }

    @Test("The stated answer is the arithmetic answer", arguments: 0..<300)
    func answerIsCorrect(seed: Int) {
        var generator = SeededGenerator(seed: UInt64(seed) + 7)
        for difficulty in Difficulty.allCases {
            let challenge = MathChallenge.make(MissionConfig(kind: .math, difficulty: difficulty).math, using: &generator)
            let expected: Int
            switch challenge.op {
            case .add: expected = challenge.left + challenge.right
            case .subtract: expected = challenge.left - challenge.right
            case .multiply: expected = challenge.left * challenge.right
            }
            #expect(challenge.answer == expected)
        }
    }

    @Test("Answers typed with whitespace and a Unicode minus are accepted")
    func tolerantParsing() {
        let challenge = MathChallenge(left: 5, right: 9, op: .subtract, answer: -4)
        #expect(challenge.accepts("-4"))
        #expect(challenge.accepts(" -4 "))
        #expect(challenge.accepts("\u{2212}4"))     // U+2212 MINUS SIGN
        #expect(challenge.accepts("\u{FF0D}4"))     // fullwidth hyphen-minus
        #expect(!challenge.accepts("4"))
        #expect(!challenge.accepts(""))
        #expect(!challenge.accepts("banana"))
    }

    @Test("Answers typed on a non-Latin numeric keypad are accepted")
    func nonLatinDigits() {
        let challenge = MathChallenge(left: 12, right: 3, op: .multiply, answer: 36)
        #expect(challenge.accepts("٣٦"))    // Arabic-Indic
        #expect(challenge.accepts("३६"))    // Devanagari
        #expect(challenge.accepts("36"))
        #expect(!challenge.accepts("٣٧"))
    }

    @Test("The prompt uses typographic operator glyphs")
    func promptGlyphs() {
        let english = Locale(identifier: "en_US")
        #expect(MathChallenge(left: 7, right: 8, op: .multiply, answer: 56).prompt(in: english) == "7 × 8")
        #expect(MathChallenge(left: 9, right: 2, op: .subtract, answer: 7).prompt(in: english) == "9 − 2")
    }

    @Test("The prompt is written in the digits the keypad shows")
    func promptDigits() {
        let challenge = MathChallenge(left: 13, right: 10, op: .add, answer: 23)
        // The Arabic keypad's keys are ١ ٢ ٣, so the problem above it cannot read "13 + 10".
        #expect(challenge.prompt(in: Locale(identifier: "ar_EG")) == "١٣ + ١٠")
        // Hindi is a Latin-digit locale on iOS despite Devanagari having its own digits.
        #expect(challenge.prompt(in: Locale(identifier: "hi_IN")) == "13 + 10")
        // Four digits, and no thousands separator: the keypad cannot type a comma.
        #expect(MathChallenge(left: 1000, right: 4, op: .multiply, answer: 4000)
            .prompt(in: Locale(identifier: "de_DE")) == "1000 × 4")
    }

    @Test("A half-typed answer keeps its shape in the locale's digits")
    func typedDigits() {
        let arabic = Locale(identifier: "ar_EG")
        #expect("07".localizedDigits(in: arabic) == "٠٧")     // the leading zero survives
        #expect("".localizedDigits(in: arabic) == "")
        #expect("13".localizedDigits(in: Locale(identifier: "fr_FR")) == "13")
        // A lone minus is what is on screen after the first tap of the negative key.
        let minus = "-".localizedDigits(in: arabic)
        #expect(minus.contains("-"))
        #expect("-5".localizedDigits(in: arabic).hasSuffix("٥"))
    }
}

@Suite("Pattern and sequence missions")
struct PatternTests {

    @Test("The grid is never entirely lit", arguments: 0..<100)
    func neverAllLit(seed: Int) {
        var generator = SeededGenerator(seed: UInt64(seed) + 1)
        let challenge = PatternChallenge.make(side: 3, litTiles: 99, previewSeconds: 1, using: &generator)
        #expect(challenge.lit.count == challenge.tileCount - 1)
    }

    @Test("Every lit tile is inside the grid", arguments: 0..<100)
    func litTilesInBounds(seed: Int) {
        var generator = SeededGenerator(seed: UInt64(seed) + 3)
        let config = MissionConfig(kind: .memory, difficulty: .brutal)
        let challenge = PatternChallenge.make(side: config.memory.side, litTiles: config.memory.litTiles, previewSeconds: 1, using: &generator)
        #expect(challenge.lit.allSatisfy { (0..<challenge.tileCount).contains($0) })
        #expect(challenge.lit.count == config.memory.litTiles)
    }

    @Test("The pattern completes only on an exact match")
    func exactMatch() {
        let challenge = PatternChallenge(side: 3, lit: [0, 4, 8], previewSeconds: 1)
        #expect(challenge.isComplete(selection: [0, 4, 8]))
        #expect(!challenge.isComplete(selection: [0, 4]))
        #expect(!challenge.isComplete(selection: [0, 4, 8, 1]))
        #expect(challenge.isMistake(tile: 1))
        #expect(!challenge.isMistake(tile: 4))
    }

    @Test("A wrong tap is caught on the tap, not at the end of the sequence")
    func sequenceFailsFast() {
        let challenge = SequenceChallenge(steps: [0, 3, 1, 2])
        #expect(challenge.isValidSoFar([0], round: 3))
        #expect(challenge.isValidSoFar([0, 3], round: 3))
        #expect(!challenge.isValidSoFar([0, 2], round: 3))
        #expect(!challenge.isValidSoFar([0, 3, 1, 2], round: 3))   // longer than the round
        #expect(challenge.isRoundComplete([0, 3, 1], round: 3))
        #expect(!challenge.isRoundComplete([0, 3], round: 3))
    }

    @Test("The sequence prefix is clamped to what exists")
    func prefixClamping() {
        let challenge = SequenceChallenge(steps: [1, 2])
        #expect(challenge.prefix(round: 99).count == 2)
        #expect(challenge.prefix(round: 0).count == 1)
    }

    @Test("Every pad index is in range", arguments: 0..<50)
    func padsInRange(seed: Int) {
        var generator = SeededGenerator(seed: UInt64(seed) + 11)
        let challenge = SequenceChallenge.make(length: 11, using: &generator)
        #expect(challenge.steps.count == 11)
        #expect(challenge.steps.allSatisfy { (0..<SequenceChallenge.padCount).contains($0) })
    }
}

@Suite("Typing mission")
struct TypingTests {

    @Test("Case, accents and doubled spaces are forgiven")
    func forgiving() {
        var challenge = TypingChallenge(sentenceKey: "k", sentence: "Le soleil se lève à l'est")
        challenge.sentence = "Le soleil se lève à l'est"
        #expect(challenge.accepts("le soleil se leve a l'est"))
        #expect(challenge.accepts("Le  soleil   se lève à l’est"))   // curly apostrophe
        #expect(challenge.accepts("Le soleil se lève à l'est."))     // autocorrect full stop
        #expect(!challenge.accepts("Le soleil se lève"))
        #expect(!challenge.accepts(""))
    }

    @Test("A CJK full stop does not fail the sentence")
    func cjkPunctuation() {
        let challenge = TypingChallenge(sentenceKey: "k", sentence: "朝日が昇る")
        #expect(challenge.accepts("朝日が昇る。"))
        #expect(challenge.accepts("朝日が昇る"))
    }

    @Test("Progress grows with the shared prefix and never exceeds 1")
    func progress() {
        let challenge = TypingChallenge(sentenceKey: "k", sentence: "wake up now")
        #expect(challenge.progress(of: "") == 0)
        #expect(challenge.progress(of: "wake") > 0.3)
        #expect(challenge.progress(of: "wake up now") == 1)
        #expect(challenge.progress(of: "wake up now and then") == 1)
    }

    @Test("The first divergent character is reported so the field can mark it")
    func mismatchIndex() {
        let challenge = TypingChallenge(sentenceKey: "k", sentence: "wake up")
        #expect(challenge.firstMismatch(in: "wake up") == nil)
        #expect(challenge.firstMismatch(in: "wake") == nil)          // still a valid prefix
        #expect(challenge.firstMismatch(in: "wake in") == 5)
        #expect(challenge.firstMismatch(in: "wake up now") == 7)     // overrun
    }

    @Test("Difficulty maps onto a length band that exists in the catalog")
    func bandsExist() {
        for difficulty in Difficulty.allCases {
            let config = MissionConfig(kind: .typing, difficulty: difficulty)
            let band = TypingChallenge.LengthBand(wordCount: config.typingWordCount)
            #expect(band.count > 0)
            var generator = SeededGenerator(seed: 4)
            let challenge = TypingChallenge.make(wordCount: config.typingWordCount, using: &generator)
            #expect(challenge.sentenceKey.hasPrefix("typing.sentence.\(band.rawValue)."))
        }
    }
}

@Suite("Drawing mission")
struct DrawingTests {

    @Test("A prompt matches its own label above the threshold")
    func matchesOwnLabel() throws {
        let boat = try #require(DrawingPrompt.all.first { $0.visionLabel == "boat" })
        #expect(boat.matches(observations: [("boat", 0.42)], threshold: 0.30))
        #expect(!boat.matches(observations: [("boat", 0.11)], threshold: 0.30))
    }

    /// Vision spells the same concept three ways across models and OS builds. All three
    /// have to land on the same accepted synonym, or a correct drawing is rejected because
    /// the classifier happened to emit an underscore.
    @Test("A near-miss label the classifier prefers still counts, however it is spelled")
    func acceptsSynonyms() throws {
        let boat = try #require(DrawingPrompt.all.first { $0.visionLabel == "boat" })
        #expect(boat.matches(observations: [("sailboat", 0.5)], threshold: 0.3))
        #expect(boat.matches(observations: [("Sail-Boat", 0.5)], threshold: 0.3))
        #expect(boat.matches(observations: [("sail boat", 0.5)], threshold: 0.3))
        #expect(boat.matches(observations: [("water_craft", 0.5)], threshold: 0.3))
        #expect(boat.matches(observations: [("watercraft", 0.5)], threshold: 0.3))
    }

    @Test("An unrelated label never counts")
    func rejectsUnrelated() throws {
        let cat = try #require(DrawingPrompt.all.first { $0.visionLabel == "cat" })
        #expect(!cat.matches(observations: [("bicycle", 0.99)], threshold: 0.3))
    }

    @Test("Every prompt has a distinct label and a catalog key")
    func promptsAreWellFormed() {
        let labels = DrawingPrompt.all.map(\.visionLabel)
        #expect(Set(labels).count == labels.count)
        #expect(DrawingPrompt.all.allSatisfy { $0.nameKey.hasPrefix("draw.prompt.") })
        #expect(DrawingPrompt.all.count >= 12)
    }

    @Test("The threshold rises with difficulty but never reaches certainty")
    func thresholds() {
        let thresholds = Difficulty.allCases.map { MissionConfig(kind: .draw, difficulty: $0).recognitionThreshold }
        #expect(thresholds == thresholds.sorted())
        #expect(thresholds.allSatisfy { $0 > 0 && $0 < 1 })
    }
}

@Suite("Mission configuration")
struct MissionConfigTests {

    @Test("Rounds are clamped to the supported range")
    func roundsClamped() {
        #expect(MissionConfig(kind: .math, rounds: 0).rounds == 1)
        #expect(MissionConfig(kind: .math, rounds: 999).rounds == MissionConfig.maxRounds)
    }

    @Test("Targets rise monotonically with difficulty")
    func monotonic() {
        let steps = Difficulty.allCases.map { MissionConfig(kind: .steps, difficulty: $0).stepTarget }
        let squats = Difficulty.allCases.map { MissionConfig(kind: .squats, difficulty: $0).squatTarget }
        let shakes = Difficulty.allCases.map { MissionConfig(kind: .shake, difficulty: $0).shakeCount }
        let flaps = Difficulty.allCases.map { MissionConfig(kind: .flap, difficulty: $0).flapTarget }
        #expect(steps == steps.sorted())
        #expect(squats == squats.sorted())
        #expect(shakes == shakes.sorted())
        #expect(flaps == flaps.sorted())
    }

    @Test("A mission needing enrollment is incomplete until it has one")
    func enrollmentGate() {
        #expect(MissionConfig(kind: .photo).isIncomplete)
        #expect(MissionConfig(kind: .barcode).isIncomplete)
        #expect(!MissionConfig(kind: .math).isIncomplete)
        let enrolled = MissionConfig(kind: .photo, enrollment: .init(reference: "sink", displayName: "Kitchen sink"))
        #expect(!enrolled.isIncomplete)
    }

    @Test("Hardware requirements are declared for the missions that need them")
    func capabilities() {
        #expect(MissionKind.squats.requiredCapability == .camera)
        #expect(MissionKind.barcode.requiredCapability == .camera)
        #expect(MissionKind.steps.requiredCapability == .pedometer)
        #expect(MissionKind.shake.requiredCapability == .accelerometer)
        #expect(MissionKind.math.requiredCapability == nil)
    }

    @Test("Every mission has a stable raw value and its own SF Symbol")
    func identifiers() {
        let symbols = MissionKind.allCases.map(\.systemImage)
        #expect(Set(symbols).count == symbols.count)
        #expect(MissionKind.allCases.count == 12)
        // The raw values are written into the store; a rename is a data migration.
        #expect(MissionKind.allCases.map(\.rawValue).sorted() ==
                ["barcode", "breathe", "draw", "flap", "math", "memory", "photo", "sequence", "shake", "squats", "steps", "typing"])
    }
}

@Suite("Free and paid tiers")
struct EntitlementTests {

    @Test("The free tier keeps three missions that need no hardware")
    func freeMissions() {
        let free = Entitlement.free.availableMissions
        #expect(Set(free) == [.math, .shake, .breathe])
        #expect(free.allSatisfy { !$0.isPremium })
    }

    @Test("Pro unlocks every mission and every difficulty")
    func proUnlocksAll() {
        #expect(Entitlement.pro.availableMissions.count == MissionKind.allCases.count)
        #expect(Difficulty.allCases.allSatisfy(Entitlement.pro.allows))
    }

    @Test("The free tier is capped at one alarm and one round")
    func freeCaps() {
        #expect(Entitlement.free.maximumAlarms == 1)
        #expect(Entitlement.free.maximumRounds == 1)
        #expect(Entitlement.pro.maximumAlarms > Entitlement.free.maximumAlarms)
    }

    @Test("Ninety days of history is what Pro is sold on, so free cannot have it")
    func historyGate() {
        // Both numbers are printed in twelve store descriptions and on the paywall.
        #expect(Entitlement.pro.maximumHistoryDays == 90)
        #expect(Entitlement.free.maximumHistoryDays < Entitlement.pro.maximumHistoryDays)
    }

    @Test("Hard and brutal are paid")
    func difficultyGate() {
        #expect(Entitlement.free.allows(Difficulty.easy))
        #expect(Entitlement.free.allows(Difficulty.medium))
        #expect(!Entitlement.free.allows(Difficulty.hard))
        #expect(!Entitlement.free.allows(Difficulty.brutal))
    }

    @Test("The mission picker is ordered gentlest first")
    func ordering() {
        let ranks = Entitlement.pro.availableMissions.map(\.effortRank)
        #expect(ranks == ranks.sorted())
    }
}
