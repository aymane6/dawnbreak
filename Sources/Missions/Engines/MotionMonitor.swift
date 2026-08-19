import CoreMotion
import Foundation
import Observation

/// Counts shakes from the accelerometer.
///
/// A shake is a sign change in the dominant axis above a threshold, with a refractory period.
/// Counting raw samples over a threshold would score fifty "shakes" for one flick of the
/// wrist, which is how a shake mission ends up clearing itself.
@MainActor
@Observable
final class ShakeMonitor {
    private(set) var count = 0
    private(set) var isAvailable = true
    /// 0…1, the strength of the most recent movement, for the wobble animation.
    private(set) var intensity: Double = 0

    private let manager = CMMotionManager()
    /// g-force above which a movement counts. 1.9 g is a deliberate flick; walking across a
    /// room with the phone in hand peaks around 1.3.
    private let threshold = 1.9
    /// Two shakes cannot be counted closer together than this.
    private let refractory: TimeInterval = 0.22
    private var lastCountedAt: Date = .distantPast
    private var lastSign = 0

    func start() {
        guard manager.isAccelerometerAvailable else {
            isAvailable = false
            return
        }
        manager.accelerometerUpdateInterval = 1.0 / 50.0
        manager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            MainActor.assumeIsolated { self.handle(data.acceleration) }
        }
    }

    func stop() {
        manager.stopAccelerometerUpdates()
    }

    func reset() {
        count = 0
        lastSign = 0
        lastCountedAt = .distantPast
    }

    private func handle(_ acceleration: CMAcceleration) {
        // The dominant axis rather than the magnitude: the magnitude includes the constant
        // 1 g of gravity, so a phone lying still already reads 1.0 and a threshold on it
        // would have to be tuned per orientation.
        let axes = [acceleration.x, acceleration.y, acceleration.z]
        guard let dominant = axes.max(by: { abs($0) < abs($1) }) else { return }
        let magnitude = sqrt(acceleration.x * acceleration.x + acceleration.y * acceleration.y + acceleration.z * acceleration.z)
        intensity = min(1, max(0, (magnitude - 1) / 2))

        guard magnitude > threshold else { return }
        let sign = dominant > 0 ? 1 : -1
        let now = Date()
        // A direction change is what makes it a shake rather than a drop.
        guard sign != lastSign, now.timeIntervalSince(lastCountedAt) > refractory else {
            lastSign = sign
            return
        }
        lastSign = sign
        lastCountedAt = now
        count += 1
    }
}

/// Counts steps while the mission is on screen.
///
/// `CMPedometer` from "now" rather than a query over the last minute: the target is steps
/// taken *after* the alarm rang, and a query window would let yesterday's walk clear today's
/// alarm.
@MainActor
@Observable
final class StepMonitor {
    private(set) var steps = 0
    private(set) var isAvailable = CMPedometer.isStepCountingAvailable()
    private(set) var isDenied = false

    private let pedometer = CMPedometer()
    private var isRunning = false

    func start() {
        guard CMPedometer.isStepCountingAvailable() else {
            isAvailable = false
            return
        }
        switch CMPedometer.authorizationStatus() {
        case .denied, .restricted:
            isDenied = true
            return
        default:
            break
        }
        guard !isRunning else { return }
        isRunning = true
        pedometer.startUpdates(from: Date()) { [weak self] data, error in
            guard let self else { return }
            MainActor.assumeIsolated {
                if error != nil {
                    self.isDenied = CMPedometer.authorizationStatus() == .denied
                    return
                }
                guard let data else { return }
                self.steps = data.numberOfSteps.intValue
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        pedometer.stopUpdates()
    }
}
