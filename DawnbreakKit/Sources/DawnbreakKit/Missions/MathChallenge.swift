import Foundation

/// One arithmetic problem and its answer.
public struct MathChallenge: Hashable, Sendable {
    public let left: Int
    public let right: Int
    public let op: MathParameters.Operator
    public let answer: Int

    /// "47 × 8", with the digits written the way `locale` writes them.
    ///
    /// The operator glyphs are the typographic ones (− and ×, not - and x) because at 60pt a
    /// hyphen reads as a dash and the multiplication x reads as a letter.
    ///
    /// Locale-aware because the keypad below it is: an Arabic interface draws its keys ١ ٢ ٣, so a
    /// problem written 13 + 10 asks the sleeper to read one numbering system and type in another.
    /// Grouping is off, so a hard four-digit operand stays 1000 rather than becoming 1,000 and
    /// inviting a comma the keypad cannot produce.
    public func prompt(in locale: Locale) -> String {
        let style = IntegerFormatStyle<Int>(locale: locale).grouping(.never)
        return "\(left.formatted(style)) \(op.rawValue) \(right.formatted(style))"
    }

    /// Deterministic under an injected generator, which is what lets the tests assert that
    /// `.easy` never produces a negative answer instead of hoping across 100 random runs.
    public static func make(
        _ parameters: MathParameters,
        using generator: inout some RandomNumberGenerator
    ) -> MathChallenge {
        let op = parameters.operators.randomElement(using: &generator) ?? .add

        // Multiplication with two 3-digit operands is not "hard", it is a calculator task.
        // The second operand is capped so the problem stays solvable in the head.
        let digits = parameters.digits
        let upper = Int(pow(10.0, Double(digits))) - 1
        let lower = digits == 1 ? 1 : Int(pow(10.0, Double(digits - 1)))

        var a = Int.random(in: lower...upper, using: &generator)
        var b: Int
        switch op {
        case .multiply:
            b = Int.random(in: 2...max(2, min(12, upper)), using: &generator)
        case .add, .subtract:
            b = Int.random(in: lower...upper, using: &generator)
        }

        if op == .subtract && !parameters.allowNegative && b > a {
            swap(&a, &b)
        }

        let answer: Int
        switch op {
        case .add: answer = a + b
        case .subtract: answer = a - b
        case .multiply: answer = a * b
        }
        return MathChallenge(left: a, right: b, op: op, answer: answer)
    }

    public static func make(_ parameters: MathParameters) -> MathChallenge {
        var g = SystemRandomNumberGenerator()
        return make(parameters, using: &g)
    }

    /// Accepts the typed string. Tolerant of whitespace and of the minus sign the numeric
    /// keypad produces, which is U+2212 on some locales and U+002D on others.
    public func accepts(_ typed: String) -> Bool {
        let normalised = typed
            .replacingOccurrences(of: "\u{2212}", with: "-")
            .replacingOccurrences(of: "\u{FF0D}", with: "-")
            .filter { !$0.isWhitespace }
        // Arabic-Indic and Devanagari digits reach us verbatim from those keyboards.
        guard let value = Int(normalised) ?? Int(normalised.decimalDigitsTransliterated) else { return false }
        return value == answer
    }
}

extension String {
    /// Maps every Unicode decimal digit onto 0-9 so a Hindi or Arabic keypad's digits
    /// parse. `Int(_:)` only accepts ASCII, and a locked-to-Arabic-numerals keypad is not
    /// something we can assume at 6am.
    var decimalDigitsTransliterated: String {
        var out = ""
        out.reserveCapacity(count)
        for scalar in unicodeScalars {
            if let value = Character(scalar).wholeNumberValue, Character(scalar).isNumber {
                out.append(String(value))
            } else if scalar == "-" || scalar == "\u{2212}" {
                out.append("-")
            }
        }
        return out
    }

    /// The other direction: ASCII digits rewritten in `locale`'s own, for display only.
    ///
    /// Digit by digit rather than parsing the whole string and formatting the number, because what
    /// is on screen while someone is typing is not always a number: a lone "-" before the first
    /// digit, and "07" before the third, both have to render exactly as typed, and `Int("07")`
    /// would drop the zero.
    public func localizedDigits(in locale: Locale) -> String {
        let style = IntegerFormatStyle<Int>(locale: locale).grouping(.never)
        let digits = (0...9).map { $0.formatted(style) }
        // Eleven of the twelve languages write Latin digits, where every digit maps to itself.
        guard digits[0] != "0" else { return self }

        // The sign the locale actually uses, taken from a formatted -1 with its digit removed.
        // Arabic's is not a bare hyphen: CLDR prefixes it with a mark that keeps it on the left of
        // the number instead of letting bidi push it to the far side.
        let minus = String((-1).formatted(style).dropLast(digits[1].count))

        var out = ""
        out.reserveCapacity(count)
        for character in self {
            if let value = character.wholeNumberValue, character.isASCII, digits.indices.contains(value) {
                out += digits[value]
            } else if character == "-" {
                out += minus
            } else {
                out.append(character)
            }
        }
        return out
    }
}
