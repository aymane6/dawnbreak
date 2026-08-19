import Foundation

/// The memory-grid mission: a set of tiles lights up, then the grid goes dark and the
/// user has to tap exactly those tiles.
public struct PatternChallenge: Hashable, Sendable {
    public let side: Int
    public let lit: Set<Int>
    public let previewSeconds: Double

    public var tileCount: Int { side * side }

    public static func make(
        side: Int,
        litTiles: Int,
        previewSeconds: Double,
        using generator: inout some RandomNumberGenerator
    ) -> PatternChallenge {
        let total = side * side
        let wanted = min(max(1, litTiles), total - 1)   // never light the whole grid
        var chosen = Set<Int>()
        // Sampling without replacement rather than shuffling the whole range: the grid is
        // at most 25 tiles, but this keeps the cost proportional to what is drawn.
        while chosen.count < wanted {
            chosen.insert(Int.random(in: 0..<total, using: &generator))
        }
        return PatternChallenge(side: side, lit: chosen, previewSeconds: previewSeconds)
    }

    public static func make(side: Int, litTiles: Int, previewSeconds: Double) -> PatternChallenge {
        var g = SystemRandomNumberGenerator()
        return make(side: side, litTiles: litTiles, previewSeconds: previewSeconds, using: &g)
    }

    public func isComplete(selection: Set<Int>) -> Bool { selection == lit }
    /// A tap that is not part of the pattern. The mission screen flashes and restarts the
    /// round rather than ending the mission, which would be punitive at 6am.
    public func isMistake(tile: Int) -> Bool { !lit.contains(tile) }
}

/// The Simon-style mission: a sequence of coloured pads plays back and grows by one each
/// time it is repeated correctly.
public struct SequenceChallenge: Hashable, Sendable {
    /// Four pads. The colours live in the view; the model only needs the indices, so the
    /// same logic drives a colour-blind-safe palette without changing.
    public static let padCount = 4
    public let steps: [Int]

    public static func make(length: Int, using generator: inout some RandomNumberGenerator) -> SequenceChallenge {
        SequenceChallenge(steps: (0..<max(1, length)).map { _ in Int.random(in: 0..<padCount, using: &generator) })
    }

    public static func make(length: Int) -> SequenceChallenge {
        var g = SystemRandomNumberGenerator()
        return make(length: length, using: &g)
    }

    /// The prefix that should be played on round `round` (1-based).
    public func prefix(round: Int) -> [Int] { Array(steps.prefix(max(1, min(round, steps.count)))) }

    /// Whether `tapped` is still a valid prefix of the round's sequence. Called on every
    /// tap so a mistake is caught immediately instead of after the whole sequence.
    public func isValidSoFar(_ tapped: [Int], round: Int) -> Bool {
        let expected = prefix(round: round)
        guard tapped.count <= expected.count else { return false }
        return Array(expected.prefix(tapped.count)) == tapped
    }

    public func isRoundComplete(_ tapped: [Int], round: Int) -> Bool {
        tapped == prefix(round: round)
    }
}
