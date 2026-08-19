import DawnbreakKit
import SwiftUI

/// Tap to fly through the gaps. Clear N of them and the alarm stops.
///
/// The point is not the game, it is that hand-eye coordination is the one thing that does not
/// work when you are half asleep. Two gaps is genuinely hard at 06:00 and trivial at 09:00,
/// which is exactly the property a wake-up mission wants.
struct FlapMissionView: View {
    let config: MissionConfig
    let callbacks: MissionCallbacks

    @State private var world = FlapWorld()
    @State private var isRunning = false

    var body: some View {
        MissionScaffold(
            instructionKey: MissionKind.flap.instructionKey,
            instruction: world.crashed ? localized("mission.flap.crashed") : nil
        ) {
            GeometryReader { proxy in
                ZStack {
                    // The sky, dawn-coloured, so the one bright thing on screen is the game.
                    LinearGradient(
                        colors: [Color(hex: 0x1B2036), Color(hex: 0x2E2340), Color(hex: 0x4A2C3A)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    ForEach(world.obstacles) { obstacle in
                        ObstacleShape(obstacle: obstacle, size: proxy.size)
                    }

                    Image(systemName: "bird.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Theme.dawnStart)
                        .rotationEffect(.degrees(min(35, max(-25, world.velocity * 900))))
                        .position(
                            x: proxy.size.width * FlapWorld.birdX,
                            y: proxy.size.height * world.birdY
                        )

                    VStack {
                        HStack {
                            Text(verbatim: "\(world.cleared.formatted(.number.grouping(.never))) / \(config.flapTarget.formatted(.number.grouping(.never)))")
                                .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.black.opacity(0.35), in: .capsule)
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(12)

                    if !isRunning {
                        VStack(spacing: 8) {
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 30))
                            Text(world.crashed ? "mission.flap.retry" : "mission.flap.start", bundle: .main)
                                .font(Theme.headlineFont)
                        }
                        .foregroundStyle(.white)
                        .padding(20)
                        .background(.black.opacity(0.4), in: .rect(cornerRadius: 18))
                    }
                }
                .clipShape(.rect(cornerRadius: 24))
                .contentShape(.rect)
                .onTapGesture { tap() }
            }
            .aspectRatio(0.72, contentMode: .fit)
            .padding(.horizontal, Theme.Metric.gutter)
            .accessibilityLabel(Text("mission.flap.canvas", bundle: .main))
            .accessibilityValue(localized("mission.progress.value", world.cleared, config.flapTarget))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { tap() }
        }
        .onDisappear { isRunning = false }
    }

    private func tap() {
        guard isRunning else {
            world.reset()
            isRunning = true
            Task { await loop() }
            return
        }
        world.flap()
    }

    private func loop() async {
        // A fixed 60 Hz step. The world is integrated per tick rather than per elapsed second
        // so the difficulty does not change with the frame rate; a dropped frame costs a
        // fraction of a pipe, not a crash.
        while isRunning && !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(16))
            world.step()

            if world.cleared >= config.flapTarget {
                isRunning = false
                callbacks.cleared()
                return
            }
            if world.crashed {
                isRunning = false
                // A crash restarts the run without restarting the whole mission: the round
                // counter belongs to the runner, and one crash is not a failed morning.
                return
            }
        }
    }
}

/// The game state. A struct, so it is trivially testable and cannot be mutated from a
/// background thread.
struct FlapWorld {
    /// Normalised coordinates throughout, 0…1 in both axes, so the same physics work on
    /// every screen size.
    static let birdX: Double = 0.28
    static let gapHeight: Double = 0.30
    static let obstacleWidth: Double = 0.14
    static let spacing: Double = 0.62

    var birdY: Double = 0.4
    var velocity: Double = 0
    var obstacles: [Obstacle] = []
    var cleared = 0
    var crashed = false

    private let gravity: Double = 0.00055
    private let flapImpulse: Double = -0.0135
    private let scrollSpeed: Double = 0.0055
    private var nextObstacleAt: Double = 1.0

    struct Obstacle: Identifiable, Hashable {
        let id: Int
        var x: Double
        /// Centre of the gap, 0…1.
        var gapCentre: Double
        var passed = false
    }

    mutating func reset() {
        birdY = 0.4
        velocity = 0
        cleared = 0
        crashed = false
        obstacles = []
        nextObstacleAt = 0.55
    }

    mutating func flap() {
        velocity = flapImpulse
    }

    mutating func step() {
        guard !crashed else { return }

        velocity += gravity
        birdY += velocity

        // The ceiling is a wall, not a death: bouncing off the top is forgiving in a way that
        // matters when the first tap of the morning is too enthusiastic.
        if birdY < 0.02 {
            birdY = 0.02
            velocity = 0
        }
        if birdY > 0.98 {
            crashed = true
            return
        }

        for index in obstacles.indices {
            obstacles[index].x -= scrollSpeed
        }
        obstacles.removeAll { $0.x < -Self.obstacleWidth }

        nextObstacleAt -= scrollSpeed
        if nextObstacleAt <= 0 {
            nextObstacleAt = Self.spacing
            // Gap centres stay away from the very top and bottom so no pipe is unplayable.
            obstacles.append(Obstacle(id: (obstacles.last?.id ?? 0) + 1, x: 1.05, gapCentre: .random(in: 0.28...0.72)))
        }

        for index in obstacles.indices {
            let obstacle = obstacles[index]
            let overlapsHorizontally = abs(obstacle.x - Self.birdX) < (Self.obstacleWidth / 2 + 0.035)
            if overlapsHorizontally {
                let halfGap = Self.gapHeight / 2
                if birdY < obstacle.gapCentre - halfGap || birdY > obstacle.gapCentre + halfGap {
                    crashed = true
                    return
                }
            }
            if !obstacle.passed && obstacle.x < Self.birdX - Self.obstacleWidth / 2 {
                obstacles[index].passed = true
                cleared += 1
            }
        }
    }
}

private struct ObstacleShape: View {
    let obstacle: FlapWorld.Obstacle
    let size: CGSize

    var body: some View {
        let width = size.width * FlapWorld.obstacleWidth
        let x = size.width * obstacle.x
        let gapTop = size.height * (obstacle.gapCentre - FlapWorld.gapHeight / 2)
        let gapBottom = size.height * (obstacle.gapCentre + FlapWorld.gapHeight / 2)

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Theme.dusk.opacity(0.85))
                .frame(width: width, height: max(0, gapTop))
                .position(x: x, y: gapTop / 2)
            RoundedRectangle(cornerRadius: 6)
                .fill(Theme.dusk.opacity(0.85))
                .frame(width: width, height: max(0, size.height - gapBottom))
                .position(x: x, y: gapBottom + (size.height - gapBottom) / 2)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}
