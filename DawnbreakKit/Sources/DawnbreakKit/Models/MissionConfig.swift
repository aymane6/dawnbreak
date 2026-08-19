import Foundation

/// Everything the mission screen needs to build a challenge, resolved from the mission
/// kind plus a difficulty. Kept as data rather than behaviour so the numbers can be
/// asserted in tests and shown in the editor's preview row before the alarm is armed.
public struct MissionConfig: Codable, Hashable, Sendable {
    public var kind: MissionKind
    public var difficulty: Difficulty
    /// How many times the challenge has to be cleared before the alarm stops. One is the
    /// default; three consecutive maths problems is what makes the alarm actually work.
    public var rounds: Int
    /// A reference the mission needs and cannot generate: the label of the object to
    /// photograph, or the payload of the barcode to scan.
    public var enrollment: Enrollment?

    public struct Enrollment: Codable, Hashable, Sendable {
        /// For `.photo`: the Vision label the shot has to match ("couch", "sink").
        /// For `.barcode`: the exact payload string read at setup time.
        public var reference: String
        /// A user-facing name, so the mission can say "photograph the kettle" using the
        /// word the user typed rather than the classifier's English label.
        public var displayName: String
        /// Relative path inside the app's support directory for the thumbnail shown in
        /// the editor. Never an absolute path: the container path changes between installs.
        public var thumbnailFilename: String?

        public init(reference: String, displayName: String, thumbnailFilename: String? = nil) {
            self.reference = reference
            self.displayName = displayName
            self.thumbnailFilename = thumbnailFilename
        }
    }

    public init(kind: MissionKind, difficulty: Difficulty = .medium, rounds: Int = 1, enrollment: Enrollment? = nil) {
        self.kind = kind
        self.difficulty = difficulty
        self.rounds = max(1, min(rounds, Self.maxRounds))
        self.enrollment = enrollment
    }

    public static let maxRounds = 10
    public static let `default` = MissionConfig(kind: .math, difficulty: .medium, rounds: 3)

    /// True when the alarm cannot be armed yet because the mission still needs setup.
    public var isIncomplete: Bool { kind.needsEnrollment && enrollment == nil }

    // MARK: - Per-mission parameters

    /// Digits per operand and which operators are allowed.
    public var math: MathParameters {
        switch difficulty {
        case .easy: MathParameters(digits: 1, operators: [.add, .subtract], allowNegative: false)
        case .medium: MathParameters(digits: 2, operators: [.add, .subtract, .multiply], allowNegative: false)
        case .hard: MathParameters(digits: 2, operators: [.add, .subtract, .multiply], allowNegative: true)
        case .brutal: MathParameters(digits: 3, operators: [.add, .subtract, .multiply], allowNegative: true)
        }
    }

    /// Grid side and how many tiles light up.
    public var memory: (side: Int, litTiles: Int, previewSeconds: Double) {
        switch difficulty {
        case .easy: (3, 3, 3.0)
        case .medium: (4, 5, 2.5)
        case .hard: (4, 7, 2.0)
        case .brutal: (5, 9, 1.5)
        }
    }

    /// How long the colour sequence grows before the mission is cleared.
    public var sequenceLength: Int {
        switch difficulty {
        case .easy: 4
        case .medium: 6
        case .hard: 8
        case .brutal: 11
        }
    }

    /// Word count of the sentence to retype.
    public var typingWordCount: Int {
        switch difficulty {
        case .easy: 4
        case .medium: 7
        case .hard: 11
        case .brutal: 16
        }
    }

    public var shakeCount: Int {
        switch difficulty {
        case .easy: 15
        case .medium: 35
        case .hard: 60
        case .brutal: 100
        }
    }

    public var stepTarget: Int {
        switch difficulty {
        case .easy: 20
        case .medium: 50
        case .hard: 100
        case .brutal: 200
        }
    }

    public var squatTarget: Int {
        switch difficulty {
        case .easy: 3
        case .medium: 8
        case .hard: 15
        case .brutal: 25
        }
    }

    /// Pipes to clear in the side-scroller.
    public var flapTarget: Int {
        switch difficulty {
        case .easy: 2
        case .medium: 5
        case .hard: 9
        case .brutal: 15
        }
    }

    /// Breathing cycles, and the length of one inhale-hold-exhale.
    public var breathe: (cycles: Int, inhale: Double, hold: Double, exhale: Double) {
        switch difficulty {
        case .easy: (3, 4, 2, 4)
        case .medium: (5, 4, 4, 6)
        case .hard: (7, 4, 7, 8)
        case .brutal: (10, 5, 7, 8)
        }
    }

    /// The confidence the on-device classifier has to reach for a drawing or a photo to
    /// count. Deliberately never 1.0: a sleepy scribble of a boat is still a boat, and an
    /// unclearable mission is a support ticket, not a feature.
    public var recognitionThreshold: Float {
        switch difficulty {
        case .easy: 0.20
        case .medium: 0.30
        case .hard: 0.42
        case .brutal: 0.55
        }
    }

    /// Seconds allowed per round before the round resets. `nil` means untimed.
    public var timeLimit: TimeInterval? {
        switch (kind, difficulty) {
        case (.math, .brutal): 25
        case (.math, .hard): 40
        case (.memory, .brutal): 20
        case (.sequence, .brutal): 30
        case (.typing, .brutal): 60
        default: nil
        }
    }
}

public struct MathParameters: Hashable, Sendable {
    public enum Operator: String, Hashable, Sendable, CaseIterable {
        case add = "+", subtract = "−", multiply = "×"
    }
    public var digits: Int
    public var operators: [Operator]
    public var allowNegative: Bool
}
