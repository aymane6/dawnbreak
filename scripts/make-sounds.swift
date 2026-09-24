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

// MARK: - Aggressive primitives
//
// Everything below this line exists because the eight original tones were too polite. The owner's
// verdict, and he is right about his own product: "les gens quand ils veulent cette application
// c'est parce qu'ils veulent se faire réveiller" — nobody installs an alarm that holds you hostage
// because they want a pleasant chime. What follows is the psychoacoustics of that, made explicit:
//
//   * 2–4 kHz is where the ear is most sensitive; energy put there is heard as loud for free.
//   * Amplitude modulation between 4 and 8 Hz is maximally "rough" and maximally hard to ignore.
//   * A minor second (a ratio near 1.06) beats against itself and cannot be heard as music.
//   * A rising sweep reads as something approaching, which no sleeping brain files under "later".
//   * Dense harmonics fill the spectrum, so no matter where a pillow absorbs, something gets out.

/// A sawtooth, summed harmonic by harmonic up to `partials`.
///
/// Additive rather than a ramp modulo one: a ramp aliases hard at 44.1 kHz, and aliasing at these
/// frequencies is a whistle sitting on top of the tone rather than the buzz that is wanted.
func sawValue(_ phase: Double, partials: Int = 24) -> Double {
    var value = 0.0
    for harmonic in 1...partials {
        value += sin(Double(harmonic) * phase) / Double(harmonic)
    }
    return value * 2 / .pi
}

/// A square, odd harmonics only. Hollow, and much harsher than a saw at the same level.
func squareValue(_ phase: Double, partials: Int = 15) -> Double {
    var value = 0.0
    for harmonic in stride(from: 1, through: partials, by: 2) {
        value += sin(Double(harmonic) * phase) / Double(harmonic)
    }
    return value * 4 / .pi
}

/// Deterministic white noise. Checked-in tones have to be reproducible, so no `Double.random`.
struct Noise {
    private var seed: UInt64 = 0xD1B5_4A32_D192_ED03

    mutating func next() -> Double {
        seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(Int64(bitPattern: seed >> 11)) / Double(1 << 52) - 1
    }
}

/// A one-pole band-emphasis around `centre`, used to shove energy into the band the ear cannot
/// ignore. Two poles would be cleaner and are not needed: the point is a tilt, not a filter.
struct Resonator {
    private var low = 0.0
    private var band = 0.0
    let coefficient: Double
    let damping: Double

    init(centre: Double, q: Double = 6) {
        coefficient = 2 * sin(.pi * min(centre, sampleRate / 2.2) / sampleRate)
        damping = 1 / q
    }

    mutating func process(_ input: Double) -> Double {
        low += coefficient * band
        let high = input - low - damping * band
        band += coefficient * high
        return band
    }
}

/// Soft saturation. Folds peaks over instead of squaring them off, which raises the average level
/// without the digital crackle of hard clipping — and adds the odd harmonics that make a tone
/// sound angry rather than merely loud.
func saturate(_ value: Double, drive: Double) -> Double {
    tanh(value * drive) / tanh(drive)
}

// MARK: - The six aggressive tones

/// Savage. An insect at the ear: a low sawtooth pair a minor second apart, ring-modulated at 55 Hz
/// so the tone is rough rather than sustained, with a resonance at 2.6 kHz to put the whole thing
/// where hearing is sharpest.
func hornet() -> [Double] {
    let seconds = 3.0
    var out = [Double](repeating: 0, count: frames(seconds))
    var first = Phasor(), second = Phasor(), modulator = Phasor()
    var resonator = Resonator(centre: 2600, q: 4)
    for i in out.indices {
        let t = Double(i) / sampleRate
        let a = sawValue(first.advance(184))
        let b = sawValue(second.advance(195))
        let rough = 0.55 + 0.45 * sin(modulator.advance(55))
        let body = (a + b) * 0.5 * rough
        let edge = resonator.process(body)
        let value = saturate(body + 1.6 * edge, drive: 2.4)
        out[i] = value * smoothstep(t / 0.02) * smoothstep((seconds - t) / 0.05)
    }
    return out
}

/// Savage. A fault buzzer: two square waves a minor second apart, gated eight times a second with
/// hard edges. The dissonance beats, the gate stops the ear adapting, and there is nothing musical
/// anywhere in it.
func buzzer() -> [Double] {
    let seconds = 3.0
    var out = [Double](repeating: 0, count: frames(seconds))
    var first = Phasor(), second = Phasor()
    for i in out.indices {
        let t = Double(i) / sampleRate
        let period = 0.125
        let inGate = t.truncatingRemainder(dividingBy: period)
        // 2 ms edges: enough not to click at the loop point, short enough to stay a hard gate.
        let gate = min(1, min(inGate, period * 0.72 - inGate) / 0.002)
        guard gate > 0 else { continue }
        let value = squareValue(first.advance(932)) * 0.5 + squareValue(second.advance(988)) * 0.5
        out[i] = saturate(value, drive: 1.8) * gate * smoothstep(t / 0.01) * smoothstep((seconds - t) / 0.04)
    }
    return out
}

/// Savage. A swarm: filtered noise pulsing forty times a second around 3.1 kHz. No pitch to latch
/// onto, no rhythm to predict, and it sits exactly where the ear is most sensitive.
func cicada() -> [Double] {
    let seconds = 3.0
    var out = [Double](repeating: 0, count: frames(seconds))
    var noise = Noise()
    var high = Resonator(centre: 3100, q: 9)
    var low = Resonator(centre: 1450, q: 7)
    var modulator = Phasor()
    for i in out.indices {
        let t = Double(i) / sampleRate
        let white = noise.next()
        let voice = high.process(white) * 1.0 + low.process(white) * 0.5
        // Squared modulation: a sharper pulse than a sine, which is what makes it chatter.
        let pulse = pow(max(0, sin(modulator.advance(40))), 0.6)
        out[i] = saturate(voice * pulse * 3.0, drive: 2.0)
            * smoothstep(t / 0.02) * smoothstep((seconds - t) / 0.05)
    }
    return out
}

/// Harsh. Metal being hit: four inharmonic strikes a second, bright and short, with a resonance
/// that rings just long enough to overlap the next one.
func hammer() -> [Double] {
    let seconds = 3.0
    var out = [Double](repeating: 0, count: frames(seconds))
    let partials: [(ratio: Double, amplitude: Double, tau: Double)] = [
        (1.0, 1.00, 0.10), (2.37, 0.72, 0.075), (3.61, 0.55, 0.055),
        (5.13, 0.40, 0.040), (7.42, 0.26, 0.028), (10.9, 0.16, 0.018),
    ]
    for hit in 0..<12 {
        strike(
            into: &out,
            at: 0.02 + Double(hit) * 0.25,
            frequency: 620,
            partials: partials,
            attack: 0.001,
            level: hit.isMultiple(of: 2) ? 1.0 : 0.78
        )
    }
    var noise = Noise()
    var resonator = Resonator(centre: 3400, q: 12)
    for i in out.indices {
        let t = Double(i) / sampleRate
        // A click of noise on each hit: an impact has a transient that a partial stack does not.
        let phase = t.truncatingRemainder(dividingBy: 0.25)
        let transient = exp(-phase / 0.004)
        out[i] = saturate(out[i] + 0.9 * resonator.process(noise.next()) * transient, drive: 1.6)
            * smoothstep((seconds - t) / 0.03)
    }
    return out
}

/// Harsh. The two-tone attention signal: 853 and 960 Hz alternating without a gap, the pair used by
/// emergency broadcast systems because it is unmistakable and impossible to mistake for music.
/// Public frequencies, synthesised here, nothing sampled.
func pulse() -> [Double] {
    let seconds = 3.0
    var out = [Double](repeating: 0, count: frames(seconds))
    var first = Phasor(), second = Phasor()
    for i in out.indices {
        let t = Double(i) / sampleRate
        let value = squareValue(first.advance(853), partials: 9) * 0.5
            + squareValue(second.advance(960), partials: 9) * 0.5
        // Continuous, deliberately: silence is where a sleeping brain gets its rest.
        out[i] = saturate(value, drive: 1.5) * smoothstep(t / 0.01) * smoothstep((seconds - t) / 0.03)
    }
    return out
}

/// Harsh. A siren that never arrives: 420 Hz up to 2.6 kHz in eight tenths of a second, over and
/// over, each sweep starting before the ear has finished the last one.
func spiral() -> [Double] {
    let seconds = 3.2
    var out = [Double](repeating: 0, count: frames(seconds))
    var lower = Phasor(), upper = Phasor()
    for i in out.indices {
        let t = Double(i) / sampleRate
        let sweep = t.truncatingRemainder(dividingBy: 0.8) / 0.8
        // Exponential in frequency, because pitch is heard logarithmically and a linear ramp
        // spends most of its time sounding high.
        let frequency = 420 * pow(2.6e3 / 420, sweep)
        let value = sawValue(lower.advance(frequency), partials: 14) * 0.7
            // A second voice an octave down and half a sweep behind, which is what stops the
            // repetition being predictable.
            + sawValue(upper.advance(frequency * 0.5), partials: 10) * 0.4
        out[i] = saturate(value, drive: 1.7) * smoothstep(t / 0.01) * smoothstep((seconds - t) / 0.04)
    }
    return out
}

// MARK: - Loudness

/// Integrated loudness in LUFS, to ITU-R BS.1770-4: K-weighting, 400 ms blocks at 75 % overlap, an
/// absolute gate at -70 LUFS and a relative gate 10 LU below the ungated mean.
///
/// This is here because peak normalisation is the reason the old tones sounded quiet. `radar` is
/// eight 110 ms beeps inside four seconds: peak-normalised to 0.95 it measures around -23 LUFS,
/// which is quieter than a podcast, while a continuous tone at the same peak measures around -10.
/// The ear hears the average, not the maximum, and an alarm is judged entirely by the average.
///
/// The filter coefficients in the standard are given for 48 kHz, so the signal is resampled to
/// 48 kHz first. Linear interpolation is enough: the error it puts on an integrated loudness
/// measurement is a few hundredths of a LU, and the gain decisions here are made to a tenth.
func integratedLoudness(_ samples: [Double]) -> Double {
    let target = 48_000.0
    var resampled = [Double](repeating: 0, count: Int(Double(samples.count) * target / sampleRate))
    for i in resampled.indices {
        let position = Double(i) * sampleRate / target
        let index = Int(position)
        let fraction = position - Double(index)
        let a = samples[min(index, samples.count - 1)]
        let b = samples[min(index + 1, samples.count - 1)]
        resampled[i] = a + (b - a) * fraction
    }

    // Stage 1, the shelving filter that stands in for a head; stage 2, the RLB high-pass.
    func biquad(_ input: [Double], _ b: (Double, Double, Double), _ a: (Double, Double)) -> [Double] {
        var out = [Double](repeating: 0, count: input.count)
        var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0
        for i in input.indices {
            let x0 = input[i]
            let y0 = b.0 * x0 + b.1 * x1 + b.2 * x2 - a.0 * y1 - a.1 * y2
            out[i] = y0
            x2 = x1; x1 = x0; y2 = y1; y1 = y0
        }
        return out
    }
    let shelved = biquad(resampled,
                         (1.53512485958697, -2.69169618940638, 1.19839281085285),
                         (-1.69065929318241, 0.73248077421585))
    let weighted = biquad(shelved,
                          (1.0, -2.0, 1.0),
                          (-1.99004745483398, 0.99007225036621))

    let block = Int(0.4 * target)
    let step = Int(0.1 * target)
    guard weighted.count >= block else { return -.infinity }
    var powers: [Double] = []
    var start = 0
    while start + block <= weighted.count {
        var sum = 0.0
        for i in start..<(start + block) { sum += weighted[i] * weighted[i] }
        powers.append(sum / Double(block))
        start += step
    }

    func loudness(_ power: Double) -> Double { power > 0 ? -0.691 + 10 * log10(power) : -.infinity }

    let aboveAbsolute = powers.filter { loudness($0) > -70 }
    guard !aboveAbsolute.isEmpty else { return -.infinity }
    let ungatedMean = aboveAbsolute.reduce(0, +) / Double(aboveAbsolute.count)
    let relativeGate = loudness(ungatedMean) - 10
    let gated = aboveAbsolute.filter { loudness($0) > relativeGate }
    guard !gated.isEmpty else { return -.infinity }
    return loudness(gated.reduce(0, +) / Double(gated.count))
}

/// An estimate of the true peak: the sample peak of a 4× linearly interpolated copy.
///
/// Sample peak alone understates a signal that peaks between two samples, and a file mastered to
/// exactly 0 dBFS sample peak can still clip a resampler on the way to the speaker.
func truePeak(_ samples: [Double]) -> Double {
    var peak = 0.0
    for i in samples.indices {
        let a = samples[i]
        let b = samples[min(i + 1, samples.count - 1)]
        for step in 0..<4 {
            let value = abs(a + (b - a) * Double(step) / 4)
            if value > peak { peak = value }
        }
    }
    return peak
}

func decibels(_ amplitude: Double) -> Double { 20 * log10(max(amplitude, 1e-12)) }

/// How loud a tone is meant to be, as an integrated loudness target.
///
/// Four classes rather than one number, because "gentle" that arrives at full scale is a
/// contradiction and "savage" that arrives politely is a broken promise. The spread from gentle to
/// savage is ten decibels, which is heard as roughly twice as loud.
///
/// -4 LUFS is not a taste, it is the ceiling. With true peak held at -1 dBTP, a tone can only be
/// louder than that by having a crest factor under 3 dB, and a crest factor under 3 dB is a
/// waveform squashed flat: all distortion, no impact. Every savage tone here sits on that wall.
enum Loudness: Double {
    case gentle = -14.0
    case standard = -10.0
    case harsh = -6.0
    case savage = -4.0
}

/// Brings a tone to its loudness class, keeps it under the true-peak ceiling, and writes 16-bit
/// mono CAF.
///
/// The old version of this normalised to a per-tone peak, which is why the alarms were quiet: peak
/// says nothing about how loud something is heard to be. This measures integrated loudness, applies
/// the gain that would hit the target, saturates whatever then exceeds the ceiling instead of
/// clipping it, and repeats until the measurement agrees with the target. Saturation rather than a
/// clean limiter is a deliberate choice for the harsh classes: folding peaks over adds odd
/// harmonics, and odd harmonics are what the ear files under "angry".
///
/// It fails the build rather than shipping a tone that missed. A silent or quiet alarm is the one
/// bug in this app nobody can work around at six in the morning.
func write(_ samples: [Double], named name: String, loudness class: Loudness) {
    let ceiling = pow(10.0, -1.0 / 20)  // -1 dBTP, so nothing downstream clips.
    var working = samples
    let start = truePeak(working)
    guard start > 0 else { fatalError("make-sounds: \(name) rendered silence") }

    // Start from the ceiling, then walk the loudness in. Six passes is more than convergence
    // needs; the loop exits as soon as it is within a tenth of a LU.
    working = working.map { $0 * ceiling / start }
    var measured = integratedLoudness(working)
    for _ in 0..<6 {
        let error = `class`.rawValue - measured
        if abs(error) < 0.1 { break }
        let gain = pow(10.0, error / 20)
        working = working.map { $0 * gain }
        let peak = truePeak(working)
        if peak > ceiling {
            // Everything above the ceiling is folded rather than cut. The drive is derived from
            // how far over it went, so a tone that only just clips is barely coloured and one
            // pushed hard is coloured hard.
            let drive = min(4.0, 1.0 + (peak / ceiling - 1) * 2.5)
            working = working.map { saturate($0 / peak, drive: drive) * ceiling }
        }
        measured = integratedLoudness(working)
    }

    let peak = truePeak(working)
    let crest = decibels(peak) - measured
    let missed = abs(measured - `class`.rawValue)
    guard missed < 0.6 else {
        fatalError("make-sounds: \(name) landed at \(String(format: "%.2f", measured)) LUFS, "
            + "\(String(format: "%.2f", missed)) LU off its \(`class`) target")
    }
    guard peak <= ceiling * 1.001 else {
        fatalError("make-sounds: \(name) peaks at \(String(format: "%.2f", decibels(peak))) dBTP")
    }
    guard crest > 1.5 else {
        fatalError("make-sounds: \(name) has a crest factor of \(String(format: "%.2f", crest)) dB, "
            + "which is a tone squashed flat rather than a loud one")
    }

    let fade = frames(0.012)
    var floats = [Float](repeating: 0, count: working.count)
    for i in working.indices {
        var value = working[i]
        // The loop in `AlarmAudio` is seamless only if both ends are silent.
        if i < fade { value *= Double(i) / Double(fade) }
        if i >= working.count - fade { value *= Double(working.count - i) / Double(fade) }
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
    let klass = "\(`class`)".padding(toLength: 9, withPad: " ", startingAt: 0)
    print(padded + klass + String(format: "%.2fs  %6.2f LUFS  peak %6.2f dBTP  crest %4.1f dB  %4d KB",
                                  duration, measured, decibels(peak), crest, bytes / 1024))
}

let folder = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appending(path: "Resources/Sounds")
try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

// The order the editor shows them in: gentle first for people who want to be woken, savage last for
// people who have learned to sleep through everything else. `AlarmSound.allCases` is the same order.
write(sunrise(), named: "sunrise", loudness: .gentle)
write(birdsong(), named: "birdsong", loudness: .gentle)
write(marimba(), named: "marimba", loudness: .standard)
write(cascade(), named: "cascade", loudness: .standard)
write(bellhop(), named: "bellhop", loudness: .standard)
write(radar(), named: "radar", loudness: .harsh)
write(klaxon(), named: "klaxon", loudness: .harsh)
write(hammer(), named: "hammer", loudness: .harsh)
write(spiral(), named: "spiral", loudness: .harsh)
// The five that exist for someone who sleeps through everything. `siren` moves up rather than down:
// peak-normalised it already measured -4.1 LUFS, and a rewrite that made the loudest tone in the app
// quieter would be a strange answer to "add louder ones".
write(siren(), named: "siren", loudness: .savage)
write(pulse(), named: "pulse", loudness: .savage)
write(hornet(), named: "hornet", loudness: .savage)
write(buzzer(), named: "buzzer", loudness: .savage)
write(cicada(), named: "cicada", loudness: .savage)
