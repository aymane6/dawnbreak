import AVFoundation
import CoreMotion
import DawnbreakKit
import Foundation
import Observation
import Vision

/// Classifies what the back camera is pointed at.
///
/// Used by the photo mission (match the object you registered) and by the drawing mission
/// (match what you drew). One classifier, two callers, because the interesting logic is the
/// same in both: run `ClassifyImageRequest`, keep the top labels, compare canonically.
@MainActor
@Observable
final class ObjectRecogniser {
    private(set) var topLabels: [(label: String, confidence: Float)] = []
    private(set) var isRunning = false
    private(set) var permission: Permission = .unknown

    enum Permission { case unknown, granted, denied, unavailable }

    let engine = CameraEngine()
    private let request = ClassifyImageRequest()

    func start(position: AVCaptureDevice.Position = .back) async {
        switch CameraEngine.authorizationStatus() {
        case .authorized:
            permission = .granted
        case .notDetermined:
            permission = await CameraEngine.requestAccess() ? .granted : .denied
        default:
            permission = .denied
        }
        guard permission == .granted else { return }

        engine.onFailure = { [weak self] in
            MainActor.assumeIsolated { self?.permission = .unavailable }
        }
        engine.onFrame = { [weak self] box in
            Task { @MainActor [weak self] in
                await self?.classify(box)
            }
        }
        engine.start(position: position, mode: .frames)
        isRunning = true
    }

    func stop() {
        engine.stop()
        isRunning = false
    }

    /// Runs the classifier and keeps the ten best labels.
    ///
    /// `perform` is async and does its work off the main thread, so awaiting it here does not
    /// block the UI; what stays on the main actor is the array of strings it returns.
    private func classify(_ box: FrameBox) async {
        defer { box.finish() }
        guard let observations = try? await request.perform(on: box.buffer, orientation: box.orientation) else { return }
        topLabels = observations
            .sorted { $0.confidence > $1.confidence }
            .prefix(10)
            .map { (label: $0.identifier, confidence: $0.confidence) }
    }

    /// Whether the current frame matches an enrolled reference label above the threshold.
    func matches(reference: String, threshold: Float) -> Bool {
        let wanted = DrawingPrompt.canonical(reference)
        return topLabels.contains { DrawingPrompt.canonical($0.label) == wanted && $0.confidence >= threshold }
    }

    /// The best label seen, for the enrollment screen's "we think this is a kettle" line.
    var bestLabel: (label: String, confidence: Float)? { topLabels.first }
}

/// Counts squats from the front camera, and refuses to count while the phone is in a hand.
///
/// The counting rules live in `SquatJudge` in the kit, where they are pure and can be replayed
/// against the cheat that beat the old version of this class: knees already bent, phone held out in
/// front, tilt it up and down, and every joint sweeps through the frame exactly as it would in a
/// real squat. No pose heuristic can tell those apart — a lens cannot distinguish the world moving
/// down from itself moving up — so the second sensor decides. `CMDeviceMotion` says whether the
/// phone moved; the picture is only believed while it did not.
///
/// What is left here is the two things that need a device: the camera frames, and the motion
/// stream.
@MainActor
@Observable
final class SquatCounter {
    private(set) var count = 0
    private(set) var permission: ObjectRecogniser.Permission = .unknown
    /// 0…1 how deep the current squat is, for the on-screen gauge.
    private(set) var depth: Double = 0
    /// The sentence on screen: which of "put the phone down", "hold still", "step back", "go down",
    /// "stand up" is currently true.
    private(set) var prompt: SquatJudge.Prompt = .propThePhone
    /// Whether the picture is currently trusted. The viewfinder border uses it, because a user who
    /// cannot see why nothing is counting will assume the app is broken.
    private(set) var isPhonePlanted = false

    let engine = CameraEngine()
    private let request = DetectHumanBodyPoseRequest()
    private let gate = SquatGate()

    var promptKey: String { Self.key(for: prompt) }

    func start() async {
        switch CameraEngine.authorizationStatus() {
        case .authorized: permission = .granted
        case .notDetermined: permission = await CameraEngine.requestAccess() ? .granted : .denied
        default: permission = .denied
        }
        guard permission == .granted else { return }

        engine.onFailure = { [weak self] in
            MainActor.assumeIsolated { self?.permission = .unavailable }
        }
        engine.onFrame = { [weak self] box in
            Task { @MainActor [weak self] in
                await self?.process(box)
            }
        }
        engine.start(position: .front, mode: .frames)
        gate.start(reporting: { [weak self] state in
            Task { @MainActor [weak self] in self?.apply(state) }
        })
    }

    func stop() {
        engine.stop()
        gate.stop()
    }

    private func apply(_ state: SquatGate.State) {
        count = state.count
        depth = state.depth
        prompt = state.prompt
        isPhonePlanted = state.isPlanted
    }

    private func process(_ box: FrameBox) async {
        defer { box.finish() }
        guard let observations = try? await request.perform(on: box.buffer, orientation: box.orientation),
              let pose = observations.first,
              let reading = Self.reading(pose, downAxis: gate.imageDownAxis)
        else {
            if let state = gate.lostBody() { apply(state) }
            return
        }
        if let state = gate.ingest(reading) { apply(state) }
    }

    /// One frame of body geometry, measured along the direction gravity says is down.
    ///
    /// Gravity rather than the image's own vertical, because the two are only the same while the
    /// phone is upright: a phone leaning against a lamp is rotated, and measuring "vertical" as
    /// "the y axis of the picture" then reports a squat for a lean. Two numbers come out, and both
    /// are divided by the torso so they do not change when the user steps closer to the camera.
    static func reading(
        _ pose: HumanBodyPoseObservation,
        downAxis: SIMD2<Double>
    ) -> SquatJudge.BodySample? {
        func joint(_ name: HumanBodyPoseObservation.JointName) -> SIMD2<Double>? {
            guard let joint = pose.joint(for: name), joint.confidence > 0.25 else { return nil }
            return SIMD2(joint.location.x, joint.location.y)
        }
        /// How far along the down axis a point sits. Bigger is lower.
        func depth(_ point: SIMD2<Double>) -> Double { (point * downAxis).sum() }

        guard let shoulder = joint(.leftShoulder) ?? joint(.rightShoulder),
              let hip = joint(.leftHip) ?? joint(.rightHip),
              let knee = joint(.leftKnee) ?? joint(.rightKnee)
        else { return nil }

        let torso = abs(depth(hip) - depth(shoulder))
        guard torso > 0.01 else { return nil }

        return SquatJudge.BodySample(
            timestamp: ProcessInfo.processInfo.systemUptime,
            kneeExtension: abs(depth(knee) - depth(hip)) / torso,
            // Raw, not divided: the judge normalises the hip's travel against the torso as it was
            // *standing*, because a squat leans the torso forward and shortens its projection. Both
            // numbers shrinking together is how a deep squat measures as no descent at all.
            hipDepth: depth(hip),
            torso: torso,
            anklesVisible: joint(.leftAnkle) != nil || joint(.rightAnkle) != nil
        )
    }

    /// Named so `make_strings` can see the keys: they are built from a case, not written out.
    static func key(for prompt: SquatJudge.Prompt) -> String {
        switch prompt {
        case .propThePhone: "mission.squats.propThePhone"
        case .holdStill: "mission.squats.holdStill"
        case .frameYourself: "mission.squats.frameYourself"
        case .goDown: "mission.squats.goDown"
        case .standUp: "mission.squats.standUp"
        }
    }
}

/// Holds the squat judge, and the device-motion stream that feeds half of it.
///
/// Off the main actor on purpose. Device motion arrives fifty times a second and almost none of it
/// changes anything the screen shows, so hopping every sample onto the main actor would be fifty
/// pointless awakenings a second in a mission that already runs the camera and Vision. The judge is
/// a value behind one lock instead, and only a *changed* verdict is published.
///
/// The handler is built by a `nonisolated static` function for the reason written out in
/// `StepMonitor`: a closure created inside a `@MainActor` type and handed to a CoreMotion API whose
/// block carries no sendability annotation inherits main-actor isolation, and the runtime then
/// aborts the process when CoreMotion calls it from its own queue.
final class SquatGate: @unchecked Sendable {

    /// Everything the screen needs, in one `Sendable` value.
    struct State: Sendable, Equatable {
        var count: Int
        var depth: Double
        var prompt: SquatJudge.Prompt
        var isPlanted: Bool
    }

    private let lock = NSLock()
    private var judge = SquatJudge()
    private var published: State
    /// Where "down" points in the picture, from the last motion sample. Portrait and upright is
    /// (0, -1): Vision's y grows upwards, so a bigger projection onto this is lower in the frame.
    private var downAxis = SIMD2<Double>(0, -1)
    private let manager = CMMotionManager()
    private let queue = OperationQueue()

    init() {
        published = State(count: 0, depth: 0, prompt: .propThePhone, isPlanted: false)
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
    }

    var imageDownAxis: SIMD2<Double> { lock.withLock { downAxis } }

    func start(reporting onChange: @escaping @Sendable (State) -> Void) {
        guard manager.isDeviceMotionAvailable else {
            // No gyroscope at all: nothing can be proven about the phone, so the picture is
            // believed as it was before. A mission that cannot run is worse than one that can be
            // cheated, and every iPhone AlarmKit runs on has this sensor anyway.
            lock.withLock { judge.trustWithoutMotion() }
            onChange(snapshot())
            return
        }
        manager.deviceMotionUpdateInterval = 1.0 / 50.0
        manager.startDeviceMotionUpdates(
            using: .xArbitraryZVertical,
            to: queue,
            withHandler: Self.handler(for: self, reporting: onChange)
        )
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }

    nonisolated static func handler(
        for gate: SquatGate?,
        reporting onChange: @escaping @Sendable (State) -> Void
    ) -> CMDeviceMotionHandler {
        { [weak gate] motion, _ in
            guard let gate, let motion else { return }
            gate.ingest(motion, reporting: onChange)
        }
    }

    private func ingest(_ motion: CMDeviceMotion, reporting onChange: @escaping @Sendable (State) -> Void) {
        let gravity = SIMD3(motion.gravity.x, motion.gravity.y, motion.gravity.z)
        let sample = SquatJudge.PhoneMotionSample(
            timestamp: motion.timestamp,
            gravity: gravity,
            rotationRate: SIMD3(motion.rotationRate.x, motion.rotationRate.y, motion.rotationRate.z),
            userAcceleration: SIMD3(motion.userAcceleration.x, motion.userAcceleration.y, motion.userAcceleration.z)
        )
        let changed: State? = lock.withLock {
            _ = judge.ingest(sample)
            // Gravity's horizontal components name the down direction in the picture. Normalised,
            // because a phone lying almost flat has a tiny horizontal component and dividing by it
            // is how a stable axis becomes a spinning one.
            let planar = SIMD2(gravity.x, gravity.y)
            let length = (planar * planar).sum().squareRoot()
            if length > 0.25 { downAxis = planar / length }
            return commit()
        }
        if let changed { onChange(changed) }
    }

    func ingest(_ body: SquatJudge.BodySample) -> State? {
        lock.withLock {
            _ = judge.ingest(body)
            judge.noteFraming(anklesVisible: body.anklesVisible)
            return commit()
        }
    }

    func lostBody() -> State? {
        lock.withLock {
            judge.lostBody()
            return commit()
        }
    }

    private func snapshot() -> State {
        State(count: judge.count, depth: judge.depth, prompt: judge.prompt, isPlanted: judge.isPhonePlanted)
    }

    /// The new state, or nil when nothing the screen draws has moved. Called under the lock.
    private func commit() -> State? {
        let next = snapshot()
        guard next != published else { return nil }
        published = next
        return next
    }
}

/// Reads barcodes. Thin, because AVFoundation does the reading; this only keeps the last
/// payload and the permission state.
@MainActor
@Observable
final class BarcodeReader {
    private(set) var lastPayload: String?
    private(set) var permission: ObjectRecogniser.Permission = .unknown

    let engine = CameraEngine()

    func start() async {
        switch CameraEngine.authorizationStatus() {
        case .authorized: permission = .granted
        case .notDetermined: permission = await CameraEngine.requestAccess() ? .granted : .denied
        default: permission = .denied
        }
        guard permission == .granted else { return }

        engine.onFailure = { [weak self] in
            MainActor.assumeIsolated { self?.permission = .unavailable }
        }
        engine.onBarcode = { [weak self] payload in
            Task { @MainActor [weak self] in
                self?.lastPayload = payload
            }
        }
        engine.start(position: .back, mode: .barcodes)
    }

    func stop() { engine.stop() }
}
