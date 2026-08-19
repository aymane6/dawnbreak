import AVFoundation
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

/// Counts squats from the front camera.
///
/// The signal is the vertical distance between hip and knee, normalised by the torso length
/// so it does not change when the user steps closer to the phone. A rep is counted on the
/// down-then-up transition, with hysteresis, because a single threshold on a noisy joint
/// stream counts a dozen reps for one shaky squat.
@MainActor
@Observable
final class SquatCounter {
    private(set) var count = 0
    private(set) var state: State = .waitingForBody
    private(set) var permission: ObjectRecogniser.Permission = .unknown
    /// 0…1 how deep the current squat is, for the on-screen gauge.
    private(set) var depth: Double = 0

    enum State {
        case waitingForBody
        case standing
        case down

        var promptKey: String {
            switch self {
            case .waitingForBody: "mission.squats.frameYourself"
            case .standing: "mission.squats.goDown"
            case .down: "mission.squats.standUp"
            }
        }
    }

    let engine = CameraEngine()
    private let request = DetectHumanBodyPoseRequest()
    /// Below this the user counts as down, above it as standing. The gap between the two is
    /// the hysteresis that stops a jittering joint from counting reps.
    private let downThreshold = 0.55
    private let upThreshold = 0.80
    /// A rep cannot be counted faster than this. A genuine squat takes at least a second.
    private let minimumRepInterval: TimeInterval = 0.9
    private var lastRepAt: Date = .distantPast

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
    }

    func stop() { engine.stop() }

    private func process(_ box: FrameBox) async {
        defer { box.finish() }
        guard let observations = try? await request.perform(on: box.buffer, orientation: box.orientation),
              let pose = observations.first else {
            state = .waitingForBody
            return
        }

        guard let ratio = Self.kneeExtension(pose) else {
            state = .waitingForBody
            return
        }

        depth = min(1, max(0, (upThreshold - ratio) / max(0.01, upThreshold - downThreshold)))

        switch state {
        case .waitingForBody:
            state = ratio > upThreshold ? .standing : .down
        case .standing where ratio < downThreshold:
            state = .down
        case .down where ratio > upThreshold:
            let now = Date()
            guard now.timeIntervalSince(lastRepAt) > minimumRepInterval else {
                state = .standing
                return
            }
            lastRepAt = now
            count += 1
            state = .standing
        default:
            break
        }
    }

    /// Hip-to-knee vertical distance over shoulder-to-hip distance.
    ///
    /// Both are measured in the same normalised image space, so the ratio is invariant to how
    /// far away the user is standing. Whichever leg the model is more confident about wins;
    /// one leg is often occluded by the other.
    static func kneeExtension(_ pose: HumanBodyPoseObservation) -> Double? {
        func vertical(_ a: HumanBodyPoseObservation.JointName, _ b: HumanBodyPoseObservation.JointName) -> (value: Double, confidence: Float)? {
            guard let first = pose.joint(for: a), let second = pose.joint(for: b),
                  first.confidence > 0.25, second.confidence > 0.25 else { return nil }
            return (abs(first.location.y - second.location.y), min(first.confidence, second.confidence))
        }

        guard let torso = vertical(.leftShoulder, .leftHip) ?? vertical(.rightShoulder, .rightHip), torso.value > 0.01 else {
            return nil
        }
        let left = vertical(.leftHip, .leftKnee)
        let right = vertical(.rightHip, .rightKnee)
        guard let leg = [left, right].compactMap({ $0 }).max(by: { $0.confidence < $1.confidence }) else { return nil }
        return leg.value / torso.value
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
