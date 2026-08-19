#!/usr/bin/env swift
//
// Generates the eight alarm tones into Resources/Sounds/.
//
// Run from the repo root: `swift scripts/make-sounds.swift`.
//
// Synthesised rather than licensed, because every alarm tone this app could have bought comes
// with a licence that has to be honoured in an App Store submission, and a wake-up app whose
// tones cannot be shipped is not a wake-up app. These are eight waveforms written out as CAF,
// owned outright, and reproducible from this file.
//
// Two constraints shape all of them:
//
//   * `AlarmAudio` plays them with `numberOfLoops = -1`, so each one has to start and end at
//     silence or the loop point clicks once a second for as long as the mission lasts.
//   * `AlarmBridge.tone(for:)` hands the same filename to AlarmKit, which plays it the way
//     iOS plays a notification sound: linear PCM in a CAF container, under thirty seconds.
//
// The file names are `AlarmSound`'s raw values. A tone missing here falls back to the system
// alarm sound rather than to silence, but the editor would offer a tone that does not exist.

import AVFoundation
import Foundation

let sampleRate = 44_100.0

// MARK: - Synthesis primitives

/// A running oscillator phase, fed a frequency per sample.
///
/// The phase is never wrapped back into 0…2π. Wrapping is the usual trick and it is wrong here:
/// a partial at 1.5× the fundamental read off a wrapped phase flips sign at every wrap, which
/// is an audible buzz at the wrap rate. `Double` holds a few hundred thousand radians without
/// losing anything that matters over a six-second tone.
struct Phasor {
    private var phase = 0.0

    mutating func advance(_ frequency: Double) -> Double {
        phase += 2 * .pi * frequency / sampleRate
        return phase
    }
}

func frames(_ seconds: Double) -> Int { Int(seconds * sampleRate) }

/// Cosine-shaped 0…1. A linear ramp on a sustained tone is audible as a corner.
func smoothstep(_ x: Double) -> Double {
    let clamped = min(1, max(0, x))
    return clamped * clamped * (3 - 2 * clamped)
}

/// One struck note: a stack of partials, each with its own amplitude and decay.
///
/// A marimba bar, a desk bell and a glass chime differ only in this table. Non-integer ratios
/// are the whole point of it: a bell's partials are inharmonic, and that is what stops it
/// sounding like an organ.
func strike(
    into buffer: inout [Double],
    at start: Double,
    frequency: Double,
    partials: [(ratio: Double, amplitude: Double, tau: Double)],
    attack: Double = 0.004,
    level: Double = 1
) {
    let begin = frames(start)
    guard begin < buffer.count else { return }
    let longest = partials.map(\.tau).max() ?? 0.5
    let length = min(buffer.count - begin, frames(longest * 6))
    for i in 0..<length {
        let t = Double(i) / sampleRate
        var value = 0.0
        for partial in partials {
            value += partial.amplitude * exp(-t / partial.tau)
                * sin(2 * .pi * frequency * partial.ratio * t)
        }
        buffer[begin + i] += level * min(1, t / attack) * value
    }
}

/// A gated tone: attack, hold at full, release. What a beep is, as opposed to a struck note
/// that starts loud and decays from the first sample.
func burst(
    into buffer: inout [Double],
    at start: Double,
    frequency: Double,
    hold: Double,
    harmonics: [Double],
    attack: Double = 0.006,
    release: Double = 0.05,
    level: Double = 1
) {
    let begin = frames(start)
    guard begin < buffer.count else { return }
    let total = attack + hold + release
    let length = min(buffer.count - begin, frames(total))
    for i in 0..<length {
        let t = Double(i) / sampleRate
        let envelope: Double
        if t < attack {
            envelope = t / attack
        } else if t < attack + hold {
            envelope = 1
        } else {
            envelope = max(0, 1 - (t - attack - hold) / release)
        }
        var value = 0.0
        for (index, amplitude) in harmonics.enumerated() {
            value += amplitude * sin(2 * .pi * frequency * Double(index + 1) * t)
        }
        buffer[begin + i] += level * envelope * value
    }
}

// MARK: - The eight tones

/// Gentle. A slow harmonic swell, the audio equivalent of the icon: it arrives rather than
/// starts. Four seconds of build, then an ease-off so the loop seam is silent.
func sunrise() -> [Double] {
    let seconds = 6.0
    var out = [Double](repeating: 0, count: frames(seconds))
    var fundamental = Phasor()
    var detuned = Phasor()
    var shimmer = Phasor()
    for i in out.indices {
        let t = Double(i) / sampleRate
        let envelope = smoothstep(t / 4.0) * smoothstep((seconds - t) / 1.4)
        let base = fundamental.advance(220)
        let second = detuned.advance(220 * 1.004)
        let high = shimmer.advance(1320)
        // The brightness arrives after the volume does, which is what makes a swell feel like
        // light coming up rather than a fade-in.
        let sparkle = 0.11 * smoothstep((t - 1.5) / 3.0) * (0.6 + 0.4 * sin(2 * .pi * 0.45 * t))
        out[i] = envelope * (
            0.55 * sin(base)
                + 0.26 * sin(second)
                + 0.30 * sin(1.5 * base)
                + 0.16 * sin(2 * base)
                + 0.08 * sin(3 * base)
                + sparkle * sin(high)
        )
    }
    return out
}

/// Urgent. Eight two-tone beeps that get louder as they go, which is what reads as "answer me"
/// instead of as a notification.
func radar() -> [Double] {
    var out = [Double](repeating: 0, count: frames(4.0))
    for beep in 0..<8 {
        burst(
            into: &out,
            at: 0.08 + Double(beep) * 0.48,
            frequency: beep.isMultiple(of: 2) ? 880 : 1174.66,
            hold: 0.11,
            harmonics: [1.0, 0.30, 0.12],
            release: 0.06,
            level: 0.70 + 0.30 * Double(beep) / 7
        )
    }
    return out
}

/// Harsh, and meant to be. Two alternating sawtooth notes with a buzz on top: the tone for
/// someone who has already learned to sleep through the gentle ones.
func klaxon() -> [Double] {
    let seconds = 3.2
    var out = [Double](repeating: 0, count: frames(seconds))
    var phasor = Phasor()
    let notes = [440.0, 587.33]
    for i in out.indices {
        let t = Double(i) / sampleRate
        let step = Int(t / 0.4)
        let inStep = t - Double(step) * 0.4
        // Each note is gated with 8ms edges: a hard square edge on a sawtooth is a click, and
        // a click in the middle of a klaxon just sounds broken.
        let gate = min(1, min(inStep, 0.4 - inStep) / 0.008)
        let phase = phasor.advance(notes[step % notes.count])
        var saw = 0.0
        for harmonic in 1...8 {
            saw += sin(Double(harmonic) * phase) / Double(harmonic)
        }
        // A tremolo fast enough to be heard as roughness rather than as pulsing.
        let buzz = 0.82 + 0.18 * sin(2 * .pi * 7.5 * t)
        out[i] = gate * buzz * saw * smoothstep((seconds - t) / 0.12)
    }
    return out
}

/// Gentle. A wooden arpeggio up and back down. Marimba bars have a strong fourth partial and
/// almost nothing between, which is the whole character.
func marimba() -> [Double] {
    var out = [Double](repeating: 0, count: frames(3.4))
    let scale = [523.25, 659.25, 783.99, 1046.50, 783.99, 659.25, 523.25, 392.00]
    for (index, frequency) in scale.enumerated() {
        strike(
            into: &out,
            at: 0.05 + Double(index) * 0.36,
            frequency: frequency,
            partials: [(1, 1.0, 0.34), (4, 0.42, 0.10), (10, 0.10, 0.04)],
            attack: 0.003,
            level: index == 3 ? 1.0 : 0.82
        )
    }
    return out
}

/// A falling run of bell tones over a soft wash, like water. Pentatonic, so no two adjacent
/// notes can clash however they overlap.
func cascade() -> [Double] {
    let seconds = 4.6
    var out = [Double](repeating: 0, count: frames(seconds))
    let scale = [1046.50, 880.00, 783.99, 659.25, 587.33, 523.25, 440.00, 392.00,
                 349.23, 329.63, 293.66, 261.63]
    for (index, frequency) in scale.enumerated() {
        strike(
            into: &out,
            at: 0.06 + Double(index) * 0.30,
            frequency: frequency,
            partials: [(1, 1.0, 0.52), (2.76, 0.24, 0.22), (5.4, 0.08, 0.10)],
            level: 0.55 + 0.45 * (1 - Double(index) / Double(scale.count - 1))
        )
    }
    // A filtered noise bed under the notes. One pole of lowpass is enough: what it has to do
    // is stop sounding like hiss, not model a river.
    var lowpassed = 0.0
    var seed: UInt64 = 0x5EED_DA_1
    for i in out.indices {
        let t = Double(i) / sampleRate
        // A small deterministic generator rather than `Double.random`: the tones are checked
        // into the repository, and a rebuild that changes them is a diff nobody can review.
        seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let white = Double(Int64(bitPattern: seed >> 11)) / Double(1 << 52) - 1
        lowpassed += 0.06 * (white - lowpassed)
        out[i] += 0.28 * lowpassed * smoothstep(t / 0.8) * smoothstep((seconds - t) / 1.2)
    }
    return out
}

/// Two strikes of a hotel desk bell. Inharmonic partials and a long tail; the second strike
/// lands while the first is still ringing, which is what a bell being hit twice sounds like.
func bellhop() -> [Double] {
    var out = [Double](repeating: 0, count: frames(4.2))
    let partials: [(ratio: Double, amplitude: Double, tau: Double)] = [
        (1.0, 1.00, 1.50), (1.51, 0.58, 1.05), (2.0, 0.42, 0.85),
        (2.49, 0.28, 0.62), (3.02, 0.18, 0.44), (4.18, 0.10, 0.26),
    ]
    strike(into: &out, at: 0.03, frequency: 1046.50, partials: partials, attack: 0.002)
    strike(into: &out, at: 1.30, frequency: 1046.50, partials: partials, attack: 0.002, level: 0.86)
    return out
}

/// A continuous sweep, three full cycles in four seconds so the loop lands exactly on the
/// bottom of the sweep. The worst tone in the app to wake up to, which is the point.
func siren() -> [Double] {
    let seconds = 4.0
    let period = seconds / 3
    var out = [Double](repeating: 0, count: frames(seconds))
    var phasor = Phasor()
    for i in out.indices {
        let t = Double(i) / sampleRate
        // A triangle sweep, not a sine one: a sine spends most of its time at the extremes,
        // and the interesting part of a siren is the travel between them.
        let position = (t.truncatingRemainder(dividingBy: period)) / period
        let ramp = position < 0.5 ? position * 2 : (1 - position) * 2
        let phase = phasor.advance(520 + 580 * ramp)
        let voice = sin(phase) + 0.34 * sin(2 * phase) + 0.17 * sin(3 * phase) + 0.09 * sin(4 * phase)
        out[i] = voice * smoothstep(t / 0.05) * smoothstep((seconds - t) / 0.05)
    }
    return out
}

/// Gentle. Chirps in groups, with gaps that are longer than you expect: birds do not trill
/// continuously, and a continuous trill is what makes a birdsong alarm sound synthetic.
func birdsong() -> [Double] {
    let seconds = 5.0
    var out = [Double](repeating: 0, count: frames(seconds))
    // (group start, how many chirps, the top of the sweep). Written out rather than randomised
    // so the file is reproducible byte for byte.
    let groups: [(start: Double, count: Int, top: Double)] = [
        (0.12, 3, 3400), (1.05, 2, 3150), (1.95, 4, 3600), (3.00, 2, 3250), (3.95, 3, 3450),
    ]
    for group in groups {
        for chirp in 0..<group.count {
            let start = group.start + Double(chirp) * 0.115
            let begin = frames(start)
            let length = min(out.count - begin, frames(0.075))
            guard begin < out.count, length > 0 else { continue }
            var phasor = Phasor()
            var lower = Phasor()
            for i in 0..<length {
                let t = Double(i) / sampleRate
                let progress = t / 0.075
                let frequency = 2100 + (group.top - 2100) * progress
                let phase = phasor.advance(frequency)
                let octave = lower.advance(frequency / 2)
                let envelope = min(1, t / 0.006) * exp(-t / 0.030)
                out[begin + i] += envelope * (sin(phase) + 0.22 * sin(octave)) * (chirp == 0 ? 1.0 : 0.86)
            }
        }
    }
    // The room the birds are in: a barely-there low bed, so the gaps between chirps are not
    // digital silence.
    var phasor = Phasor()
    for i in out.indices {
        let t = Double(i) / sampleRate
        out[i] += 0.02 * sin(phasor.advance(196)) * smoothstep(t / 1.0) * smoothstep((seconds - t) / 1.0)
    }
    return out
}

// MARK: - Output

/// Normalises to `peak`, fades both ends, and writes 16-bit mono CAF.
///
/// The per-tone peak is a loudness decision, not a technical one: the gentle tones are
/// deliberately quieter than the harsh ones at the same volume setting, because "gentle" that
/// arrives at full scale is a contradiction.
func write(_ samples: [Double], named name: String, peak: Double) {
    let loudest = samples.map(abs).max() ?? 0
    guard loudest > 0 else { fatalError("make-sounds: \(name) rendered silence") }
    let scale = peak / loudest
    let fade = frames(0.012)

    var floats = [Float](repeating: 0, count: samples.count)
    for i in samples.indices {
        var value = samples[i] * scale
        if i < fade { value *= Double(i) / Double(fade) }
        if i >= samples.count - fade { value *= Double(samples.count - i) / Double(fade) }
        floats[i] = Float(min(1, max(-1, value)))
    }

    let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appending(path: "Resources/Sounds/\(name).caf")
    let settings: [String: Any] = [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: sampleRate,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsNonInterleaved: false,
    ]
    guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
          let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(floats.count)) else {
        fatalError("make-sounds: could not build a mono buffer")
    }
    buffer.frameLength = AVAudioFrameCount(floats.count)
    floats.withUnsafeBufferPointer { source in
        buffer.floatChannelData![0].update(from: source.baseAddress!, count: floats.count)
    }

    do {
        // Scoped so the file is flushed and closed before the size is read below.
        let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        try file.write(from: buffer)
    } catch {
        fatalError("make-sounds: could not write \(url.path): \(error)")
    }

    let bytes = ((try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int) ?? 0
    let duration = Double(floats.count) / sampleRate
    let padded = name.padding(toLength: 9, withPad: " ", startingAt: 0)
    print(String(format: "%@ %.2fs  peak %.2f  %4d KB", padded, duration, peak, bytes / 1024))
}

let folder = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appending(path: "Resources/Sounds")
try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

write(sunrise(), named: "sunrise", peak: 0.72)
write(radar(), named: "radar", peak: 0.95)
write(klaxon(), named: "klaxon", peak: 0.97)
write(marimba(), named: "marimba", peak: 0.84)
write(cascade(), named: "cascade", peak: 0.80)
write(bellhop(), named: "bellhop", peak: 0.88)
write(siren(), named: "siren", peak: 0.95)
write(birdsong(), named: "birdsong", peak: 0.74)
