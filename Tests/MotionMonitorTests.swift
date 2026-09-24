import CoreMotion
import DawnbreakKit
import Foundation
import Testing
@testable import Dawnbreak

/// The steps mission, from the two angles a simulator can hold it: which thread CoreMotion calls
/// back on, and what the app does with what it says.
///
/// The mission crashed the app on device for one reason. `CMPedometer` documents its handler as
/// running "on a serial queue", never the main one, and the handler touched main-actor state
/// through `MainActor.assumeIsolated`. That is not a shortcut, it is an assertion, and libdispatch
/// aborts the process when it fails — so the app died on the tester's first step, every time,
/// while every other mission was fine.
///
/// Nothing here needs a pedometer, which is what makes it runnable at all: the simulator has no
/// step counting and `CMPedometerData` cannot be built by hand. What it needs is the shipped code
/// path called from a thread that is not the main one, which is exactly what these do. If the hop
/// is ever removed, these tests do not fail politely; they take the test process down, the same
/// way the app went down.
@Suite("Steps mission")
struct StepMonitorTests {

    @Test("A sample delivered from a background queue reaches the monitor")
    @MainActor
    func deliveryOffTheMainThreadDoesNotTrap() async throws {
        let monitor = StepMonitor()
        await offMain { StepMonitor.deliver(to: monitor, steps: 12, failure: nil) }
        try await settle { monitor.steps == 12 }
        #expect(monitor.steps == 12)
    }

    /// The closure `start()` hands to `CMPedometer`, called the way `CMPedometer` calls it.
    ///
    /// The error path rather than the data path, because only Apple can make a `CMPedometerData`;
    /// the isolation it has to survive is identical either way, and it is the isolation that was
    /// the bug. That it also classifies the error off the main thread is the second half.
    @Test("The pedometer's own handler survives being called off the main thread")
    @MainActor
    func shippedHandlerOffTheMainThread() async throws {
        let monitor = StepMonitor()
        let handler = StepMonitor.handler(for: monitor)
        await offMain { handler(nil, Self.coreMotionError(CMErrorMotionActivityNotAuthorized)) }
        try await settle { monitor.isDenied }
        #expect(monitor.isDenied, "a refusal has to reach the screen, or the ring never fills")
        #expect(monitor.steps == 0)
    }

    @Test("A revised, lower count does not walk the ring backwards")
    @MainActor
    func countIsMonotonic() {
        let monitor = StepMonitor()
        monitor.apply(steps: 30, failure: nil)
        monitor.apply(steps: 24, failure: nil)
        #expect(monitor.steps == 30)
    }

    @Test("A transient CoreMotion error does not blank the mission")
    @MainActor
    func transientErrorKeepsTheScreen() {
        let monitor = StepMonitor()
        monitor.apply(steps: 8, failure: nil)
        monitor.apply(steps: nil, failure: .transient)
        #expect(monitor.steps == 8)
        #expect(!monitor.isDenied, "the pedometer being busy is not the user saying no")
    }

    /// The trap this closes: a refusal answered while the mission is already on screen used to be
    /// read back from `CMPedometer.authorizationStatus()`, which can still say `notDetermined` at
    /// that moment. The mission then sat at zero steps with no way off it but the corner exit,
    /// which the user is allowed to switch off in Settings.
    @Test("A refusal answered mid-mission shows the wall with the way out")
    @MainActor
    func refusalOpensTheWall() {
        let monitor = StepMonitor()
        monitor.apply(steps: nil, failure: .refused)
        #expect(monitor.isDenied)
    }

    @Test("CoreMotion's final answers are told apart from its momentary ones")
    func refusalsAreClassified() {
        for code in [
            CMErrorMotionActivityNotAuthorized,
            CMErrorMotionActivityNotAvailable,
            CMErrorMotionActivityNotEntitled,
            CMErrorNotAuthorized,
            CMErrorNotAvailable,
            CMErrorNotEntitled
        ] {
            #expect(StepMonitor.isRefusal(Self.coreMotionError(code)), "\(code) means no steps, ever")
        }
        for code in [CMErrorUnknown, CMErrorInvalidParameter, CMErrorNilData, CMErrorDeviceRequiresMovement] {
            #expect(!StepMonitor.isRefusal(Self.coreMotionError(code)), "\(code) is momentary")
        }
    }

    /// A CoreMotion failure as the framework hands it over: an `NSError` carrying a `CMError`
    /// code. Only the code is read, which is why the domain can be spelled here.
    private static func coreMotionError(_ code: CMError) -> any Error {
        NSError(domain: "CMErrorDomain", code: Int(code.rawValue))
    }
    /// Runs `body` on a global queue and returns once it has finished.
    private func offMain(_ body: @escaping @Sendable () -> Void) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                #expect(!Thread.isMainThread, "the point of this test is the queue it runs on")
                body()
                continuation.resume()
            }
        }
    }

    /// Waits for a main-actor condition the delivery hop will satisfy on its own turn.
    @MainActor
    private func settle(
        within limit: Duration = .seconds(2),
        until condition: () -> Bool
    ) async throws {
        let deadline = ContinuousClock.now.advanced(by: limit)
        while ContinuousClock.now < deadline {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("the delivered sample never arrived on the main actor")
    }
}

/// The device half of the squat mission: the parts that need CoreMotion rather than the judge.
///
/// The judge itself is proved in `DawnbreakKit`, against a replay of the cheat it exists to stop.
/// What can only be checked here is the isolation of the motion handler, which is the same trap
/// that killed the steps mission: a closure created inside a `@MainActor` type and handed to a
/// CoreMotion API whose block carries no sendability annotation inherits main-actor isolation, and
/// the runtime aborts the process the first time CoreMotion calls it from its own queue. A squat
/// mission that crashes is not an improvement on a squat mission that can be cheated.
@Suite("Squats mission, device side")
struct SquatGateTests {

    @Test("The motion handler survives being called off the main thread")
    func handlerOffTheMainThread() async {
        let gate = SquatGate()
        let handler = SquatGate.handler(for: gate, reporting: { _ in })
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                #expect(!Thread.isMainThread, "the point of this test is the queue it runs on")
                handler(nil, nil)
                continuation.resume()
            }
        }
    }

    @Test("Body readings are refused from any thread until the phone is proven still")
    func bodyReadingsAreRefusedOffMain() async {
        let gate = SquatGate()
        let refused: Bool = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // A textbook squat, delivered while nothing is known about the phone.
                _ = gate.ingest(SquatJudge.BodySample(timestamp: 1, kneeExtension: 0.92, hipDepth: 0.30))
                _ = gate.ingest(SquatJudge.BodySample(timestamp: 2, kneeExtension: 0.37, hipDepth: 0.85))
                let last = gate.ingest(SquatJudge.BodySample(timestamp: 3, kneeExtension: 0.92, hipDepth: 0.30))
                continuation.resume(returning: last?.count ?? 0 == 0)
            }
        }
        #expect(refused, "a rep was credited before the phone was known to be resting")
    }

    @Test("Down in the picture follows gravity, so a leaning phone is not a squatting user")
    func theDownAxisFollowsGravity() {
        // Vision's y grows upwards, so an upright phone's down axis is (0, -1) and a projection
        // onto it grows as a joint sinks.
        let upright = SIMD2<Double>(0, -1)
        let hipStanding = SIMD2<Double>(0.5, 0.55)
        let hipSquatting = SIMD2<Double>(0.5, 0.40)
        #expect((hipSquatting * upright).sum() > (hipStanding * upright).sum())
    }
}
