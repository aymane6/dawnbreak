import Foundation

/// Decides whether a squat happened, and refuses to decide at all while the phone is in a hand.
///
/// This exists because the mission was trivially cheatable, and the cheat is worth writing down:
/// stand with your knees already bent, hold the phone in front of you, and tilt it up and down.
/// Every joint sweeps vertically through the frame exactly as it would if you were squatting, the
/// old counter measured nothing but those vertical sweeps, and it credited a rep per tilt. Nobody
/// squatted. The alarm went off.
///
/// The fix is not a better pose heuristic. A camera cannot tell, from one frame, whether the world
/// moved down or it moved up — that ambiguity is the whole of projective geometry, and no amount of
/// joint arithmetic resolves it. What resolves it is the second sensor: the phone knows whether
/// *it* moved. So the rule is that image-space geometry is only believed while the phone is proven
/// still, and a still phone is one that has been propped against something. Once that holds, a hip
/// travelling down the frame is a hip travelling down.
///
/// Pure, deterministic, and clock-free: every instant comes from a sample's own timestamp, so the
/// owner's cheat can be replayed as data in a test and the answer is the same every time.
public struct SquatJudge: Sendable {

    // MARK: - Input

    /// One reading of where the phone is and how it is being held.
    public struct PhoneMotionSample: Sendable, Equatable {
        public var timestamp: TimeInterval
        /// The gravity vector in the device's own frame, roughly unit length. Its *direction* is
        /// what matters: it names which way is down in the picture, and it changes the instant
        /// somebody tilts the phone.
        public var gravity: SIMD3<Double>
        /// Radians per second about each device axis.
        public var rotationRate: SIMD3<Double>
        /// Acceleration with gravity already removed, in g.
        public var userAcceleration: SIMD3<Double>

        public init(
            timestamp: TimeInterval,
            gravity: SIMD3<Double>,
            rotationRate: SIMD3<Double> = .zero,
            userAcceleration: SIMD3<Double> = .zero
        ) {
            self.timestamp = timestamp
            self.gravity = gravity
            self.rotationRate = rotationRate
            self.userAcceleration = userAcceleration
        }
    }

    /// One reading of the body, already projected onto the gravity-referenced axis by the caller.
    ///
    /// `kneeExtension` is a ratio and so needs no reference. `hipDepth` and `torso` are raw
    /// projections in the caller's units, deliberately: dividing the hip position by the *current*
    /// torso length looks like the obvious way to make it scale-free and quietly destroys the
    /// measurement, because a squat leans the torso forward and its projection onto the down axis
    /// shrinks by a third. Hip and torso then shrink together and the ratio barely moves — an honest
    /// squat would measure as no descent at all. So the division happens in one place, against the
    /// torso as it was measured standing, and it happens here rather than in the caller because only
    /// this type knows when the user was last upright.
    public struct BodySample: Sendable, Equatable {
        public var timestamp: TimeInterval
        /// Hip-to-knee separation along the down axis, over torso length. Around 0.9 standing,
        /// under 0.5 at the bottom of a squat: the thigh turns edge-on to the camera as the knee
        /// comes up.
        public var kneeExtension: Double
        /// Where the hip sits along the down axis. Bigger is lower. It only means anything while
        /// the phone is planted — which is the point.
        public var hipDepth: Double
        /// Shoulder-to-hip separation along the same axis, as the unit of length.
        public var torso: Double
        /// Whether the ankles were confidently found. Used to ask for better framing, never to
        /// refuse a rep: a bedroom at six in the morning loses ankles to the duvet, and a mission
        /// that cannot be cleared is worse than a mission that can be cheated.
        public var anklesVisible: Bool

        public init(
            timestamp: TimeInterval,
            kneeExtension: Double,
            hipDepth: Double,
            torso: Double = 1,
            anklesVisible: Bool = true
        ) {
            self.timestamp = timestamp
            self.kneeExtension = kneeExtension
            self.hipDepth = hipDepth
            self.torso = torso
            self.anklesVisible = anklesVisible
        }
    }

    /// Every number the judge uses, in one table, so the shipping values are a single named thing
    /// a test can vary rather than constants scattered through a state machine.
    public struct Thresholds: Sendable, Equatable {
        /// Angle, in degrees, between the current and reference gravity below which the phone
        /// counts as unmoved. Two degrees is about a millimetre of lean on a bedside table.
        public var plantDriftDegrees: Double
        /// Sustained drift that means somebody picked it up.
        public var movedDriftDegrees: Double
        /// How long that drift has to hold before it counts, so one thump on the mattress is not a
        /// pick-up.
        public var movedDriftHold: TimeInterval
        /// Rotation, radians per second, averaged over `gyroWindow`.
        public var plantGyro: Double
        public var movedGyro: Double
        public var gyroWindow: TimeInterval
        /// Acceleration in g, averaged over `accelerationWindow`. A phone in a hand is never still
        /// at this resolution; a phone on furniture is, even while the room shakes.
        public var plantAcceleration: Double
        public var movedAcceleration: Double
        public var accelerationWindow: TimeInterval
        /// Rotation that has to accompany the acceleration for it to count as carrying rather than
        /// as the floor being jumped on next to the phone.
        public var carryGyro: Double
        /// How long the phone must be quiet before its geometry is believed again.
        public var settle: TimeInterval
        /// Knee extension below which the body counts as down, and above which as standing. The gap
        /// is hysteresis: a single threshold on a noisy joint counts a dozen reps for one squat.
        public var downExtension: Double
        public var upExtension: Double
        /// A rep needs the bottom held, the top reached, and a minimum gap from the last one.
        public var bottomDwell: TimeInterval
        public var standDwell: TimeInterval
        public var minimumInterval: TimeInterval
        /// How far the hip must actually travel down the frame, in torso lengths, between standing
        /// and the bottom. A tilt that survives the stillness gate still cannot move the hip this
        /// far relative to the torso without the knees bending.
        public var hipTravel: Double

        public static let shipping = Thresholds(
            plantDriftDegrees: 2.0,
            movedDriftDegrees: 3.0,
            movedDriftHold: 0.15,
            plantGyro: 0.12,
            movedGyro: 0.10,
            gyroWindow: 0.40,
            plantAcceleration: 0.035,
            movedAcceleration: 0.06,
            accelerationWindow: 0.60,
            carryGyro: 0.05,
            settle: 1.5,
            downExtension: 0.55,
            upExtension: 0.80,
            bottomDwell: 0.30,
            standDwell: 0.25,
            minimumInterval: 0.9,
            hipTravel: 0.35
        )
    }

    // MARK: - Output

    /// What the judge has to say. Returned rather than published so the caller decides what is
    /// worth a haptic, a sentence on screen, or nothing at all.
    public enum Event: Sendable, Equatable {
        case repCounted(total: Int)
        /// The phone left its resting place. Any rep in flight is void.
        case phoneMoved
        /// Still again, and long enough that the picture can be trusted.
        case phonePlanted
    }

    /// What the screen should be saying, which is the only reason the caller needs to know any of
    /// this. One case, one localized string.
    public enum Prompt: Sendable, Equatable {
        /// Somebody is holding the phone. Nothing counts until they stop.
        case propThePhone
        /// Propped, but not for long enough yet.
        case holdStill
        /// No body, or not enough of one.
        case frameYourself
        case goDown
        case standUp
    }

    public private(set) var count = 0
    /// 0…1, how deep the current squat is, for the gauge.
    public private(set) var depth: Double = 0
    public private(set) var prompt: Prompt = .propThePhone
    /// Whether image-space geometry is currently believed.
    public var isPhonePlanted: Bool { phone == .planted }

    private enum Phone: Equatable { case unknown, moving, settling, planted }
    private enum Posture: Equatable { case unknown, standing, down }

    private let thresholds: Thresholds
    private var phone: Phone = .unknown
    private var posture: Posture = .unknown
    /// The gravity direction the phone had when it was last found at rest. Drift is measured
    /// against this rather than against the previous sample: a slow, smooth tilt has a tiny
    /// per-sample delta and would otherwise pass for stillness the whole way down.
    private var restingGravity: SIMD3<Double>?
    private var motion: [PhoneMotionSample] = []
    private var driftingSince: TimeInterval?
    private var quietSince: TimeInterval?
    /// Hip depth at the top of the current rep, and the deepest point reached since.
    private var standingHip: Double?
    private var deepestHip: Double?
    /// The torso as it measured while standing, which is the unit the hip's travel is counted in.
    /// Taken standing because that is when the torso is upright and its projection is longest.
    private var standingTorso: Double?
    private var bottomReachedAt: TimeInterval?
    private var topReachedAt: TimeInterval?
    private var lastRepAt: TimeInterval = -.greatestFiniteMagnitude
    private var lastBodyAt: TimeInterval?

    public init(thresholds: Thresholds = .shipping) {
        self.thresholds = thresholds
    }

    // MARK: - Phone

    /// Feeds one motion reading. Returns an event only when the verdict changes.
    public mutating func ingest(_ sample: PhoneMotionSample) -> [Event] {
        motion.append(sample)
        // A second of history is enough for the longest window, and bounds the array at 50 Hz.
        let horizon = sample.timestamp - 1.0
        if motion.count > 8, let first = motion.first, first.timestamp < horizon {
            motion.removeAll { $0.timestamp < horizon }
        }

        let gyro = magnitudeAverage(\.rotationRate, over: thresholds.gyroWindow, now: sample.timestamp)
        let acceleration = magnitudeAverage(\.userAcceleration, over: thresholds.accelerationWindow, now: sample.timestamp)
        // No reference means nothing to have drifted from. Reading that as "infinitely tilted"
        // deadlocks the gate: a moving phone drops its reference, and a missing reference would
        // then keep it moving forever, so putting the phone down could never be noticed.
        let drift = restingGravity.map { Self.angleDegrees(between: $0, and: sample.gravity) } ?? 0

        // Carrying is a tilt held, or a sustained rotation, or a sustained acceleration that comes
        // with *some* rotation. The last conjunction matters: a phone flat on a table when its
        // owner jumps beside it reads real acceleration and almost no rotation, and calling that a
        // pick-up would stop the mission every time the user landed.
        if drift >= thresholds.movedDriftDegrees {
            driftingSince = driftingSince ?? sample.timestamp
        } else {
            driftingSince = nil
        }
        let heldTilt = driftingSince.map { sample.timestamp - $0 >= thresholds.movedDriftHold } ?? false
        let carried = gyro > thresholds.movedGyro
            || (acceleration > thresholds.movedAcceleration && gyro > thresholds.carryGyro)

        if heldTilt || carried {
            quietSince = nil
            // The reference is dropped, not updated: wherever the phone ends up is a new resting
            // place, and it has to earn the settle period from there.
            restingGravity = nil
            return transition(to: .moving)
        }

        let quiet = gyro <= thresholds.plantGyro
            && acceleration <= thresholds.plantAcceleration
            && drift <= thresholds.plantDriftDegrees
        guard quiet else {
            // Between the two bands: not carried, not yet still. Hold whatever is believed now.
            if restingGravity == nil { restingGravity = sample.gravity }
            return []
        }

        if restingGravity == nil {
            restingGravity = sample.gravity
            quietSince = sample.timestamp
            return transition(to: .settling)
        }
        let since = quietSince ?? sample.timestamp
        quietSince = since
        if sample.timestamp - since >= thresholds.settle {
            return transition(to: .planted)
        }
        return transition(to: .settling)
    }

    /// No motion sensor on this device, so nothing can be proven about the phone.
    ///
    /// The picture is believed unconditionally in that case, which is the old, cheatable behaviour
    /// — deliberately. Every iPhone AlarmKit runs on has a gyroscope, so this is a path for a
    /// simulator and for a hypothetical device, and on those a mission that can be cheated is far
    /// better than a mission that can never be cleared.
    public mutating func trustWithoutMotion() {
        phone = .planted
        prompt = .frameYourself
    }

    // MARK: - Body

    /// Feeds one pose reading. Returns `[.repCounted]` at the top of a squat that satisfied every
    /// condition, and nothing at all while the phone is not planted.
    public mutating func ingest(_ sample: BodySample) -> [Event] {
        lastBodyAt = sample.timestamp
        guard phone == .planted else {
            // Deliberately not just "don't count": the whole rep is abandoned, so a cheat cannot
            // be assembled out of a descent taken while holding the phone and a stand-up taken
            // after putting it down.
            resetRep()
            depth = 0
            prompt = phone == .settling ? .holdStill : .propThePhone
            return []
        }

        depth = min(1, max(0, (thresholds.upExtension - sample.kneeExtension)
            / max(0.01, thresholds.upExtension - thresholds.downExtension)))

        switch posture {
        case .unknown:
            posture = sample.kneeExtension > thresholds.upExtension ? .standing : .down
            if posture == .standing {
                standingHip = sample.hipDepth
                standingTorso = sample.torso
                topReachedAt = sample.timestamp
            }
            prompt = posture == .standing ? .goDown : .standUp
            return []

        case .standing:
            // The standing hip is tracked while standing rather than sampled once: someone shifts
            // their weight between reps, and a stale reference would make the next rep's travel
            // look shorter or longer than it was.
            standingHip = min(standingHip ?? sample.hipDepth, sample.hipDepth)
            standingTorso = max(standingTorso ?? sample.torso, sample.torso)
            topReachedAt = topReachedAt ?? sample.timestamp
            guard sample.kneeExtension < thresholds.downExtension else {
                prompt = .goDown
                return []
            }
            guard let top = topReachedAt, sample.timestamp - top >= thresholds.standDwell else {
                // Down again before standing was ever really held: a bounce, not a rep.
                return []
            }
            posture = .down
            deepestHip = sample.hipDepth
            bottomReachedAt = sample.timestamp
            prompt = .standUp
            return []

        case .down:
            deepestHip = max(deepestHip ?? sample.hipDepth, sample.hipDepth)
            guard sample.kneeExtension > thresholds.upExtension else {
                prompt = .standUp
                return []
            }
            let heldBottom = bottomReachedAt.map { sample.timestamp - $0 >= thresholds.bottomDwell } ?? false
            // In torso lengths, against the torso as it was standing rather than as it is now.
            let travel = ((deepestHip ?? 0) - (standingHip ?? 0)) / max(standingTorso ?? sample.torso, 1e-6)
            let spaced = sample.timestamp - lastRepAt >= thresholds.minimumInterval
            posture = .standing
            topReachedAt = sample.timestamp
            standingHip = sample.hipDepth
            standingTorso = sample.torso
            deepestHip = nil
            bottomReachedAt = nil
            prompt = .goDown
            guard heldBottom, spaced, travel >= thresholds.hipTravel else { return [] }
            lastRepAt = sample.timestamp
            count += 1
            return [.repCounted(total: count)]
        }
    }

    /// No body in the frame. Keeps the phone verdict, drops the rep.
    public mutating func lostBody() {
        resetRep()
        depth = 0
        prompt = phone == .planted ? .frameYourself : (phone == .settling ? .holdStill : .propThePhone)
    }

    /// The framing hint, for a body that is found but cut off at the ankles.
    public mutating func noteFraming(anklesVisible: Bool) {
        guard phone == .planted, !anklesVisible, posture != .down else { return }
        prompt = .frameYourself
    }

    // MARK: - Plumbing

    private mutating func transition(to next: Phone) -> [Event] {
        guard next != phone else { return [] }
        let previous = phone
        phone = next
        switch next {
        case .moving:
            resetRep()
            depth = 0
            posture = .unknown
            prompt = .propThePhone
            return [.phoneMoved]
        case .settling:
            prompt = .holdStill
            // Only worth announcing when it follows movement; the first sample after launch is
            // settling too, and nothing has been lost yet.
            return previous == .planted ? [.phoneMoved] : []
        case .planted:
            prompt = .frameYourself
            return [.phonePlanted]
        case .unknown:
            return []
        }
    }

    private mutating func resetRep() {
        posture = .unknown
        standingHip = nil
        standingTorso = nil
        deepestHip = nil
        bottomReachedAt = nil
        topReachedAt = nil
    }

    private func magnitudeAverage(
        _ field: KeyPath<PhoneMotionSample, SIMD3<Double>>,
        over window: TimeInterval,
        now: TimeInterval
    ) -> Double {
        let slice = motion.filter { $0.timestamp > now - window }
        guard !slice.isEmpty else { return 0 }
        // The mean of magnitudes rather than the magnitude of the mean: a hand shaking a phone
        // back and forth averages to nothing as a vector and to a lot as a length, and it is the
        // length that says a hand is holding it.
        return slice.reduce(0.0) { $0 + Self.length($1[keyPath: field]) } / Double(slice.count)
    }

    static func length(_ vector: SIMD3<Double>) -> Double {
        (vector * vector).sum().squareRoot()
    }

    /// The angle between two directions, in degrees. Clamped before `acos` because a dot product
    /// of two nearly-parallel unit vectors lands on 1.0000000000000002 often enough to matter.
    static func angleDegrees(between a: SIMD3<Double>, and b: SIMD3<Double>) -> Double {
        let lengths = length(a) * length(b)
        guard lengths > 1e-9 else { return 0 }
        let cosine = min(1, max(-1, (a * b).sum() / lengths))
        return acos(cosine) * 180 / .pi
    }
}
