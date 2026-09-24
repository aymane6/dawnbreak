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
        // `to: .main` is the difference between this and `StepMonitor`: the accelerometer
        // lets us name the queue, so assuming main-actor isolation in the body is sound.
        // The pedometer takes no queue and uses its own; see the note there before copying
        // this shape onto another CoreMotion API.
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
        // Started from a nonisolated context on purpose, and this is the bug that killed the
        // steps mission on device.
        //
        // CoreMotion's header says it plainly: "Starts a series of continuous pedometer updates
        // to the handler on a serial queue." That queue is never the main one, and
        // `CMPedometerHandler` carries no sendability annotation, so a closure written inline in
        // a `@MainActor` method inherits main-actor isolation and the compiler wraps it in a
        // thunk that asserts the main queue before the body runs. CoreMotion then calls it from
        // its own queue and libdispatch aborts the process — "BUG IN CLIENT OF LIBDISPATCH:
        // Assertion failed: Block was expected to execute on queue [com.apple.main-thread]" — on
        // the user's very first step, which is precisely when a steps mission is supposed to
        // start working. `MainActor.assumeIsolated` inside the body traps for the same reason,
        // one frame lower.
        //
        // `begin` is nonisolated, so nothing written inside it can inherit this actor, and the
        // hop onto the main actor is spelled out in `deliver`. Keeping the two apart is what
        // makes the crash unreachable rather than merely absent.
        Self.begin(pedometer, from: Date(), for: self)
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        pedometer.stopUpdates()
    }

    /// Hands CoreMotion the handler. Nonisolated so that the closure it passes cannot pick up
    /// main-actor isolation from the caller, whatever a future edit does to it.
    ///
    /// Called synchronously from the main actor, which is why a non-`Sendable` `CMPedometer` may
    /// cross into it: a nonisolated synchronous function runs on its caller's thread, so nothing
    /// is shared and nothing is sent.
    nonisolated static func begin(_ pedometer: CMPedometer, from date: Date, for monitor: StepMonitor) {
        pedometer.startUpdates(from: date, withHandler: handler(for: monitor))
    }

    /// The block CoreMotion calls, on CoreMotion's own queue.
    ///
    /// Nonisolated and static so that it cannot pick up main-actor isolation from its
    /// surroundings, and so that a test can call the shipped closure from a background queue.
    /// Nothing that is not `Sendable` may cross out of it: the count is read out of
    /// `CMPedometerData` here, the error is classified here, and only two values travel.
    nonisolated static func handler(for monitor: StepMonitor?) -> @Sendable (CMPedometerData?, (any Error)?) -> Void {
        { [weak monitor] data, error in
            deliver(
                to: monitor,
                steps: data?.numberOfSteps.intValue,
                failure: error.map { isRefusal($0) ? .refused : .transient }
            )
        }
    }

    /// What a CoreMotion failure means for the screen.
    enum Failure: Sendable {
        /// The pedometer will never answer: permission was refused, or motion data is off.
        case refused
        /// Something momentary. The mission stays up, because the user may already be walking.
        case transient
    }

    /// Whether an error means "you are not getting steps, ever" rather than "not this time".
    ///
    /// Asking `CMPedometer.authorizationStatus()` instead is not enough on its own: a refusal
    /// answered mid-mission arrives here as an error while the cached status can still read
    /// `notDetermined`, and the mission would then sit at zero steps with no way out but the
    /// emergency exit, which gives up the whole morning. Motion & Fitness turned off
    /// device-wide answers `CMErrorNotAvailable` and is just as final.
    nonisolated static func isRefusal(_ error: any Error) -> Bool {
        let code = (error as NSError).code
        return [
            CMErrorMotionActivityNotAuthorized,
            CMErrorMotionActivityNotAvailable,
            CMErrorMotionActivityNotEntitled,
            CMErrorNotAuthorized,
            CMErrorNotAvailable,
            CMErrorNotEntitled
        ].contains { Int($0.rawValue) == code }
    }

    /// Carries one pedometer sample from whatever thread CoreMotion used onto the main actor.
    ///
    /// The single door into `StepMonitor` from outside the main actor, deliberately, so that
    /// the hop exists in one place a test can drive: `StepMonitorTests` calls this from a
    /// background queue, and any future `assumeIsolated` here crashes that test rather than a
    /// tester's phone.
    nonisolated static func deliver(to monitor: StepMonitor?, steps: Int?, failure: Failure?) {
        guard let monitor else { return }
        Task { @MainActor in monitor.apply(steps: steps, failure: failure) }
    }

    /// Applies one sample, already on the main actor.
    func apply(steps newValue: Int?, failure: Failure?) {
        switch failure {
        case .refused:
            // The screen with a way off it. Anything else would strand a user in front of a
            // ring that cannot fill.
            isDenied = true
            return
        case .transient:
            // Deliberately nothing: the pedometer is busy or the start date slipped, and
            // blanking the mission for that would interrupt someone who is already walking.
            return
        case nil:
            break
        }
        guard let newValue else { return }
        // Monotonic: CoreMotion revises a cumulative count downwards when it decides the last
        // few steps were the phone being put down, and a progress ring that walks backwards
        // reads as a broken app to someone standing in their bedroom at six in the morning.
        steps = max(steps, newValue)
    }
}
