import Foundation

enum SyntheticAudioFixtures {
    static func sine(midiNote: Int, sampleRate: Double = 48_000, sampleCount: Int = 4096, amplitude: Float = 0.3) -> [Float] {
        let frequency = 440.0 * pow(2.0, Double(midiNote - 69) / 12.0)
        return (0..<sampleCount).map { index in
            amplitude * Float(sin(2.0 * Double.pi * frequency * Double(index) / sampleRate))
        }
    }

    static func harmonic(midiNote: Int, sampleRate: Double = 48_000, sampleCount: Int = 4096) -> [Float] {
        let base = 440.0 * pow(2.0, Double(midiNote - 69) / 12.0)
        return (0..<sampleCount).map { index in
            let t = Double(index) / sampleRate
            let value = sin(2 * .pi * base * t) * 0.25 + sin(2 * .pi * base * 2 * t) * 0.18 + sin(2 * .pi * base * 3 * t) * 0.12
            return Float(value)
        }
    }

    static func chord(_ notes: [Int], sampleRate: Double = 48_000, sampleCount: Int = 4096) -> [Float] {
        guard notes.isEmpty == false else { return Array(repeating: 0, count: sampleCount) }
        let signals = notes.map { harmonic(midiNote: $0, sampleRate: sampleRate, sampleCount: sampleCount) }
        return (0..<sampleCount).map { index in
            signals.reduce(Float.zero) { $0 + $1[index] } / Float(notes.count)
        }
    }

    static func broadbandNoise(sampleCount: Int = 4096, amplitude: Float = 0.02) -> [Float] {
        (0..<sampleCount).map { index in
            let value = sin(Double(index) * 12.9898).truncatingRemainder(dividingBy: 1.0)
            return Float(value) * amplitude
        }
    }
}
