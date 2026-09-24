import Foundation
import Testing
@testable import DawnbreakKit

/// The squat mission, held down against the cheat that beat it.
///
/// The owner's words, the morning he broke it: knees already bent, phone in the hand, held out in
/// front, and "juste en soulevant la caméra, on tourne la caméra, ça donne l'illusion que je monte
/// et je descends et par la suite elle remarque rien". He was right, and the reason is geometric
/// rather than a tuning mistake: a lens cannot tell a world moving down from itself moving up, so a
/// counter that reads only the picture is not defeatable by better arithmetic. Every test here is
/// therefore about the same claim — the picture is believed only while the phone is proven still —
/// and the first one is his cheat, replayed as data.
@Suite("Squat judge")
struct SquatJudgeTests {

    // MARK: - Streams

    /// One sample, timestamps and all, so a test reads as a story rather than as a constructor.
    fileprivate enum Step {
        case phone(SquatJudge.PhoneMotionSample)
        case body(SquatJudge.BodySample)
    }

    /// Deterministic noise, because "still" is not "identical": a real gyro on a bedside table
    /// reports a few thousandths of a radian per second forever, and a judge that only accepts
    /// exact zeros would never let anybody squat.
    private struct Noise {
        private var state: UInt64 = 0x2545F4914F6CDD1D
        mutating func next(_ scale: Double) -> Double {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return (Double(state % 2000) / 1000 - 1) * scale
        }
    }

    /// A phone lying against something, untouched.
    private static func planted(
        from start: TimeInterval,
        to end: TimeInterval,
        gravity: SIMD3<Double> = [0, -0.97, -0.24],
        rate: TimeInterval = 0.02
    ) -> [Step] {
        var noise = Noise()
        var steps: [Step] = []
        var t = start
        while t <= end {
            steps.append(.phone(SquatJudge.PhoneMotionSample(
                timestamp: t,
                // A propped phone drifts by hundredths of a degree, not degrees.
                gravity: gravity + SIMD3(noise.next(0.0004), noise.next(0.0004), noise.next(0.0004)),
                rotationRate: SIMD3(noise.next(0.01), noise.next(0.01), noise.next(0.01)),
                userAcceleration: SIMD3(noise.next(0.004), noise.next(0.004), noise.next(0.004))
            )))
            t += rate
        }
        return steps
    }

    /// A phone in a hand, held as steadily as a human can hold anything.
    ///
    /// The numbers are the honest ones: a still hand is around a tenth of a radian per second of
    /// tremor and a few hundredths of a g, which is two orders of magnitude above furniture.
    private static func handHeld(
        from start: TimeInterval,
        to end: TimeInterval,
        tiltDegreesPerSecond: Double = 12,
        rate: TimeInterval = 0.02
    ) -> [Step] {
        var noise = Noise()
        var steps: [Step] = []
        var t = start
        while t <= end {
            // The tilt that produces the illusion: the phone is rocked back and forth, which is
            // exactly what sweeps the joints up and down the frame.
            let angle = sin(2 * .pi * 0.4 * t) * tiltDegreesPerSecond * .pi / 180
            steps.append(.phone(SquatJudge.PhoneMotionSample(
                timestamp: t,
                gravity: SIMD3(sin(angle), -cos(angle), -0.24),
                rotationRate: SIMD3(noise.next(0.03), 0.35 * cos(2 * .pi * 0.4 * t), noise.next(0.03)),
                userAcceleration: SIMD3(noise.next(0.02), 0.05 + noise.next(0.02), noise.next(0.02))
            )))
            t += rate
        }
        return steps
    }

    /// A real squat: the knee closes, the hip travels down the frame, the bottom is held — and the
    /// torso leans forward, so its projection onto the down axis shortens by a third on the way
    /// down. That last part is not decoration: it is what a squat does to the picture, and a judge
    /// that divides the hip position by the current torso measures it as no descent at all.
    private static func honestSquat(
        startingAt start: TimeInterval,
        hold: TimeInterval = 0.45,
        descent: TimeInterval = 0.7,
        torsoStanding: Double = 0.26,
        torsoBottom: Double = 0.17
    ) -> [Step] {
        var steps: [Step] = []
        let step = min(0.05, descent / 4)
        var t = 0.0
        while t < descent {
            let fraction = t / descent
            steps.append(.body(SquatJudge.BodySample(
                timestamp: start + t,
                kneeExtension: 0.92 - 0.55 * fraction,
                hipDepth: 0.30 + 0.55 * fraction,
                torso: torsoStanding + (torsoBottom - torsoStanding) * fraction
            )))
            t += step
        }
        t = 0
        while t < hold {
            steps.append(.body(SquatJudge.BodySample(
                timestamp: start + descent + t,
                kneeExtension: 0.37,
                hipDepth: 0.85,
                torso: torsoBottom
            )))
            t += step
        }
        t = 0
        while t < descent {
            let fraction = t / descent
            steps.append(.body(SquatJudge.BodySample(
                timestamp: start + descent + hold + t,
                kneeExtension: 0.37 + 0.55 * fraction,
                hipDepth: 0.85 - 0.55 * fraction,
                torso: torsoBottom + (torsoStanding - torsoBottom) * fraction
            )))
            t += step
        }
        steps.append(.body(SquatJudge.BodySample(
            timestamp: start + 2 * descent + hold,
            kneeExtension: 0.92,
            hipDepth: 0.30,
            torso: torsoStanding
        )))
        return steps
    }

    /// The cheat: the knee ratio swings exactly as much as in a real squat, because the camera is
    /// doing the swinging, but the hip barely travels relative to the torso — the body is not
    /// going anywhere.
    private static func tiltedIllusion(startingAt start: TimeInterval) -> [Step] {
        var steps: [Step] = []
        var t = 0.0
        while t < 2.0 {
            let sweep = (sin(2 * .pi * 0.4 * (start + t)) + 1) / 2
            steps.append(.body(SquatJudge.BodySample(
                timestamp: start + t,
                kneeExtension: 0.92 - 0.55 * sweep,
                // Knees already bent, standing on the spot: the hip is where it was.
                hipDepth: 0.42 + 0.06 * sweep,
                torso: 0.26
            )))
            t += 0.05
        }
        return steps
    }

    /// Runs a merged stream and returns everything the judge said.
    private static func run(_ judge: inout SquatJudge, _ streams: [Step]...) -> [SquatJudge.Event] {
        let all: [Step] = streams.reduce(into: []) { $0 += $1 }
        let merged = all.sorted { lhs, rhs in
            let left = lhs.timestamp, right = rhs.timestamp
            // Motion first at equal timestamps: the phone's verdict gates the body's, and a body
            // sample that arrives before the first motion sample can only be refused.
            return left == right ? lhs.isPhone && !rhs.isPhone : left < right
        }
        var events: [SquatJudge.Event] = []
        for step in merged {
            switch step {
            case .phone(let sample): events += judge.ingest(sample)
            case .body(let sample): events += judge.ingest(sample)
            }
        }
        return events
    }

    // MARK: - The cheat

    @Test("The owner's cheat counts nothing: knees bent, phone in hand, tilt it up and down")
    func theTiltCheatCountsNothing() {
        var judge = SquatJudge()
        let events = Self.run(&judge, Self.handHeld(from: 0, to: 12), Self.tiltedIllusion(startingAt: 1.0),
                              Self.tiltedIllusion(startingAt: 3.5), Self.tiltedIllusion(startingAt: 6.0),
                              Self.tiltedIllusion(startingAt: 8.5))
        #expect(judge.count == 0, "four tilt cycles were credited as squats")
        #expect(!events.contains { if case .repCounted = $0 { return true } else { return false } })
        #expect(judge.prompt == .propThePhone, "the screen has to say why nothing is counting")
    }

    @Test("Even with the phone propped, a tilt-shaped signal with no hip travel is not a squat")
    func aSweepWithoutTravelIsNotASquat() {
        var judge = SquatJudge()
        _ = Self.run(&judge, Self.planted(from: 0, to: 12), Self.tiltedIllusion(startingAt: 2.0),
                     Self.tiltedIllusion(startingAt: 5.0), Self.tiltedIllusion(startingAt: 8.0))
        #expect(judge.count == 0, "the hip never moved a third of a torso: nobody squatted")
    }

    @Test("A phone lifted mid-squat voids the rep in flight")
    func liftingThePhoneVoidsTheRep() {
        var judge = SquatJudge()
        // Propped and settled, then the descent, then it is picked up before standing back up.
        var steps = Self.planted(from: 0, to: 3.0)
        steps += Self.handHeld(from: 3.0, to: 6.0)
        let squat = Self.honestSquat(startingAt: 2.6)
        _ = Self.run(&judge, steps, squat)
        #expect(judge.count == 0)
    }

    // MARK: - The honest path

    @Test("A propped phone and a real squat counts, and the settle period is respected")
    func anHonestSquatCounts() {
        var judge = SquatJudge()
        let events = Self.run(&judge, Self.planted(from: 0, to: 8), Self.honestSquat(startingAt: 2.0))
        #expect(judge.count == 1)
        #expect(events.contains(.phonePlanted))
        #expect(events.contains(.repCounted(total: 1)))
    }

    /// The bug this catches was mine, in the first draft of the judge: `hipDepth` divided by the
    /// *current* torso. Leaning forward shortens the torso's projection, both numbers shrink
    /// together, the ratio hardly moves, and a deep honest squat measures as three hundredths of a
    /// torso of travel — under any threshold worth having. Normalising against the standing torso
    /// is the fix, and this is the case that proves it: a lean so pronounced it halves the torso.
    @Test("A squat with a heavy forward lean still counts")
    func aForwardLeanStillCounts() {
        var judge = SquatJudge()
        _ = Self.run(&judge, Self.planted(from: 0, to: 8),
                     Self.honestSquat(startingAt: 2.0, torsoStanding: 0.28, torsoBottom: 0.14))
        #expect(judge.count == 1, "leaning forward, which is what squatting looks like, lost the rep")
    }

    /// The numbers the app actually produces are negative, and that must not matter.
    ///
    /// Vision measures upwards from the bottom of the frame while gravity points down, so the down
    /// axis is (0, -1) and every projection comes out below zero: a standing hip reads -0.90 and a
    /// squatting one -0.35. Deeper means closer to zero, the differences are what the rules use, and
    /// a rule that quietly assumed positive coordinates would count nothing on a real phone while
    /// passing every other test in this file.
    @Test("A squat measured the way the app measures it, in negative projections, still counts")
    func negativeProjectionsCountToo() {
        var judge = SquatJudge()
        let shifted = Self.honestSquat(startingAt: 2.0).map { step -> Step in
            guard case .body(var sample) = step else { return step }
            sample.hipDepth -= 1.2
            return .body(sample)
        }
        _ = Self.run(&judge, Self.planted(from: 0, to: 8), shifted)
        #expect(judge.count == 1)
    }

    @Test("A rep taken before the phone has settled does not count")
    func theSettlePeriodIsRespected() {
        var judge = SquatJudge()
        // The squat starts 0.2s after the phone is put down: inside the 1.5s settle window.
        _ = Self.run(&judge, Self.planted(from: 0, to: 6), Self.honestSquat(startingAt: 0.2))
        #expect(judge.count == 0, "geometry was believed before the phone was proven still")
    }

    @Test("Cheating first does not lock the mission: an honest squat afterwards still counts")
    func theGateIsNotADeadEnd() {
        var judge = SquatJudge()
        var steps = Self.handHeld(from: 0, to: 4)
        steps += Self.planted(from: 4, to: 12)
        _ = Self.run(&judge, steps, Self.tiltedIllusion(startingAt: 1.0), Self.honestSquat(startingAt: 7.0))
        #expect(judge.count == 1, "putting the phone down has to be a way forward, not a punishment")
    }

    @Test("Somebody landing next to the phone does not stop the mission")
    func floorThumpsAreNotAPickUp() {
        var judge = SquatJudge()
        var noise = Noise()
        var steps = Self.planted(from: 0, to: 2.0)
        // Real acceleration, no rotation: the table shakes, the phone does not turn.
        var t = 2.0
        while t < 2.4 {
            steps.append(.phone(SquatJudge.PhoneMotionSample(
                timestamp: t,
                gravity: SIMD3(0, -0.97, -0.24) + SIMD3(noise.next(0.001), noise.next(0.001), noise.next(0.001)),
                rotationRate: SIMD3(noise.next(0.01), noise.next(0.01), noise.next(0.01)),
                userAcceleration: SIMD3(noise.next(0.02), 0.22, noise.next(0.02))
            )))
            t += 0.02
        }
        steps += Self.planted(from: 2.4, to: 9.0)
        _ = Self.run(&judge, steps, Self.honestSquat(startingAt: 4.0))
        #expect(judge.count == 1, "a thump on the floor voided an honest rep")
    }

    @Test("Every target a difficulty can ask for is reachable by squatting honestly")
    func everyTargetIsClearable() {
        for target in [3, 8, 15, 25] {
            var judge = SquatJudge()
            var steps = Self.planted(from: 0, to: Double(target) * 2.2 + 6)
            var squats: [Step] = []
            for rep in 0..<target {
                squats += Self.honestSquat(startingAt: 2.0 + Double(rep) * 2.2)
            }
            _ = Self.run(&judge, steps, squats)
            #expect(judge.count == target, "a target of \(target) came out as \(judge.count)")
            steps.removeAll()
        }
    }

    // MARK: - Rep quality

    @Test("A bounce is not a rep: the bottom has to be held")
    func bouncesDoNotCount() {
        var judge = SquatJudge()
        // A whole cycle inside a third of a second, which is a knee flick rather than a squat.
        _ = Self.run(&judge, Self.planted(from: 0, to: 8),
                     Self.honestSquat(startingAt: 2.0, hold: 0.04, descent: 0.12))
        #expect(judge.count == 0)
    }

    @Test("Jitter across the threshold counts nothing")
    func hysteresisHolds() {
        var judge = SquatJudge()
        var steps: [Step] = []
        var t = 2.0
        while t < 6.0 {
            // Oscillating either side of `downExtension` without ever reaching the standing band.
            steps.append(.body(SquatJudge.BodySample(
                timestamp: t,
                kneeExtension: 0.56 + 0.03 * sin(2 * .pi * 3 * t),
                hipDepth: 0.6
            )))
            t += 0.03
        }
        _ = Self.run(&judge, Self.planted(from: 0, to: 8), steps)
        #expect(judge.count == 0)
    }

    /// The dwells and the minimum interval are separate rules, and this one is tested with the
    /// dwells relaxed on purpose: with the shipping numbers a cycle short enough to break the
    /// spacing rule already breaks a dwell, and a test that cannot fail for the reason it names is
    /// not a test.
    @Test("Two squats closer together than the minimum interval count once")
    func repsAreSpaced() {
        var relaxed = SquatJudge.Thresholds.shipping
        relaxed.bottomDwell = 0.05
        relaxed.standDwell = 0.05
        var judge = SquatJudge(thresholds: relaxed)
        _ = Self.run(&judge, Self.planted(from: 0, to: 10),
                     Self.honestSquat(startingAt: 3.0, hold: 0.08, descent: 0.14),
                     Self.honestSquat(startingAt: 3.6, hold: 0.08, descent: 0.14))
        #expect(judge.count == 1, "two flicks 0.6s apart counted \(judge.count) times")
    }

    // MARK: - What the screen says

    @Test("The prompt names the thing standing between the user and the mission")
    func thePromptIsHonest() {
        var judge = SquatJudge()
        #expect(judge.prompt == .propThePhone, "before anything is known, ask for the phone to be put down")

        _ = Self.run(&judge, Self.handHeld(from: 0, to: 2))
        #expect(judge.prompt == .propThePhone)

        _ = Self.run(&judge, Self.planted(from: 2, to: 2.6))
        #expect(judge.prompt == .holdStill, "propped but not settled has its own sentence")

        _ = Self.run(&judge, Self.planted(from: 2.6, to: 5))
        #expect(judge.prompt == .frameYourself)

        _ = Self.run(&judge, [], [.body(SquatJudge.BodySample(timestamp: 5.1, kneeExtension: 0.92, hipDepth: 0.3))])
        #expect(judge.prompt == .goDown)
    }

    @Test("Ankles out of frame ask for framing but never refuse a rep")
    func anklesAreAHintNotAGate() {
        var judge = SquatJudge()
        var squat = Self.honestSquat(startingAt: 2.0)
        squat = squat.map { step in
            guard case .body(var sample) = step else { return step }
            sample.anklesVisible = false
            return .body(sample)
        }
        _ = Self.run(&judge, Self.planted(from: 0, to: 8), squat)
        #expect(judge.count == 1, "a duvet over the ankles must not cost the user their morning")
    }

    // MARK: - Geometry

    @Test("The angle between two gravity directions is measured, not approximated")
    func gravityAngles() {
        #expect(abs(SquatJudge.angleDegrees(between: [0, -1, 0], and: [0, -1, 0])) < 0.001)
        #expect(abs(SquatJudge.angleDegrees(between: [0, -1, 0], and: [1, 0, 0]) - 90) < 0.001)
        // The clamp: two identical unit vectors whose dot product lands just above 1.
        #expect(SquatJudge.angleDegrees(between: [0.6, -0.8, 0], and: [0.6, -0.8, 0]).isFinite)
        #expect(SquatJudge.angleDegrees(between: .zero, and: [0, -1, 0]) == 0)
    }
}

private extension SquatJudgeTests.Step {
    var timestamp: TimeInterval {
        switch self {
        case .phone(let sample): sample.timestamp
        case .body(let sample): sample.timestamp
        }
    }

    var isPhone: Bool {
        if case .phone = self { return true }
        return false
    }
}
