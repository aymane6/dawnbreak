import AVFoundation
import DawnbreakKit
import Foundation
import Observation
import UIKit

/// The audio that keeps playing while the mission is on screen.
///
/// AlarmKit rings the alarm; this takes over once the user has opened the mission, because
/// the system alert goes silent the moment its button is pressed and a silent mission screen
/// is a screen you fall back asleep in front of. `.playback` category with
/// `.duckOthers` so it is audible over a podcast that was still running.
@MainActor
@Observable
final class AlarmAudio {
    private var player: AVAudioPlayer?
    private var rampTask: Task<Void, Never>?
    private var hapticTask: Task<Void, Never>?
    private(set) var isPlaying = false

    /// Starts the loop.
    /// - Parameters:
    ///   - soundName: filename without extension, matching `AlarmSound`.
    ///   - volume: the target volume, 0…1.
    ///   - rampSeconds: fade in from silence over this long. 0 starts at full volume.
    func start(soundName: String, volume: Double, rampSeconds: Int, vibrate: Bool) {
        stop()
        guard let url = Self.url(for: soundName) else { return }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = rampSeconds > 0 ? 0 : Float(volume)
            player.prepareToPlay()
            player.play()
            self.player = player
            isPlaying = true
        } catch {
            // A missing or unplayable tone must not stop the mission: the alarm has already
            // rung, and the user's job now is to clear the challenge. Vibration alone still
            // keeps the screen alive.
            isPlaying = false
        }

        if rampSeconds > 0 {
            ramp(to: Float(volume), over: rampSeconds)
        }
        if vibrate {
            startVibrating(matching: AlarmSound(rawValue: soundName)?.loudness ?? .standard)
        }
    }

    func stop() {
        rampTask?.cancel()
        hapticTask?.cancel()
        rampTask = nil
        hapticTask = nil
        player?.stop()
        player = nil
        isPlaying = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Briefly drops the volume, so a correct answer is audibly acknowledged without the
    /// alarm going quiet enough to fall back asleep.
    func acknowledge() {
        guard let player else { return }
        let target = player.volume
        player.setVolume(target * 0.25, fadeDuration: 0.1)
        player.setVolume(target, fadeDuration: 0.6)
    }

    private func ramp(to target: Float, over seconds: Int) {
        rampTask = Task { [weak self] in
            let steps = max(1, seconds * 4)
            for step in 1...steps {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                self?.player?.volume = target * Float(step) / Float(steps)
            }
        }
    }

    /// A repeating haptic rather than one buzz: the point is to stay awake through the
    /// mission, and a single tap at the start does nothing for that.
    ///
    /// The cadence follows the tone, because the two are one decision. Somebody who chose the
    /// cicadas did not choose them to be tapped politely every three seconds, and somebody who
    /// chose the sunrise did not ask to be drilled.
    private func startVibrating(matching loudness: AlarmSound.Loudness) {
        hapticTask = Task {
            let generator = UIImpactFeedbackGenerator(style: loudness >= .harsh ? .rigid : .heavy)
            generator.prepare()
            // The gap between bursts, and how many hits are in one.
            let (gap, burst): (Duration, Int) = switch loudness {
            case .gentle: (.seconds(2.6), 1)
            case .standard: (.seconds(2), 2)
            case .harsh: (.milliseconds(900), 3)
            case .savage: (.milliseconds(420), 4)
            }
            while !Task.isCancelled {
                for hit in 0..<burst {
                    generator.impactOccurred(intensity: hit == 0 ? 1.0 : 0.75)
                    try? await Task.sleep(for: .milliseconds(loudness >= .harsh ? 110 : 700))
                    if Task.isCancelled { return }
                }
                try? await Task.sleep(for: gap)
            }
        }
    }

    /// The bundled tone, or the system's own fallback if a build ever ships without it.
    static func url(for soundName: String) -> URL? {
        Bundle.main.url(forResource: soundName, withExtension: "caf")
            ?? Bundle.main.url(forResource: AlarmSound.default.rawValue, withExtension: "caf")
    }
}

/// The short preview played when the user taps a tone in the editor. Separate from
/// `AlarmAudio` because it must not duck other audio, loop, or vibrate: it is a two-second
/// sample, not an alarm.
///
/// `.playback`, not `.ambient`: the alarm rings through the silent switch, so the preview has
/// to as well. Under `.ambient` a muted phone played nothing at all, and fourteen silent tiles
/// read as fourteen broken tones.
@MainActor
@Observable
final class SoundPreviewer {
    private var player: AVAudioPlayer?
    private var stopTask: Task<Void, Never>?

    func play(_ soundName: String) {
        stop()
        guard let url = AlarmAudio.url(for: soundName) else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = 0.7
            player.play()
            self.player = player
        } catch {
            return
        }
        stopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }

    func stop() {
        stopTask?.cancel()
        stopTask = nil
        player?.stop()
        player = nil
    }
}
