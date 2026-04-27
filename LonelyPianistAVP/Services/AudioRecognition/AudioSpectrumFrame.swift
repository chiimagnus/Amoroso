import Foundation

struct AudioSpectrumFrame: Sendable, Equatable, HarmonicBandEnergyProviding {
    let sampleRate: Double
    let windowSize: Int
    let rms: Double
    let noiseFloor: Double
    let onsetScore: Double
    let isOnset: Bool
    let timestamp: Date
    private let frequencyBins: [Double]
    private let magnitudes: [Double]

    init(
        sampleRate: Double,
        windowSize: Int,
        rms: Double,
        noiseFloor: Double,
        onsetScore: Double,
        isOnset: Bool,
        timestamp: Date,
        frequencyBins: [Double] = [],
        magnitudes: [Double] = []
    ) {
        self.sampleRate = sampleRate
        self.windowSize = windowSize
        self.rms = rms
        self.noiseFloor = noiseFloor
        self.onsetScore = onsetScore
        self.isOnset = isOnset
        self.timestamp = timestamp
        self.frequencyBins = frequencyBins
        self.magnitudes = magnitudes
    }

    func bandEnergy(centerFrequency: Double, toleranceCents: Double) -> Double {
        guard centerFrequency.isFinite, centerFrequency > 0 else { return 0 }
        guard frequencyBins.isEmpty == false, frequencyBins.count == magnitudes.count else { return 0 }
        let lower = centerFrequency * pow(2.0, -abs(toleranceCents) / 1200.0)
        let upper = centerFrequency * pow(2.0, abs(toleranceCents) / 1200.0)
        var energy = 0.0
        for index in frequencyBins.indices where frequencyBins[index] >= lower && frequencyBins[index] <= upper {
            energy += magnitudes[index]
        }
        return energy
    }

    func surroundingEnergy(centerFrequency: Double, toleranceCents: Double) -> Double {
        guard centerFrequency.isFinite, centerFrequency > 0 else { return 0 }
        guard frequencyBins.isEmpty == false, frequencyBins.count == magnitudes.count else { return 0 }
        let innerLower = centerFrequency * pow(2.0, -abs(toleranceCents) / 1200.0)
        let innerUpper = centerFrequency * pow(2.0, abs(toleranceCents) / 1200.0)
        let outerLower = centerFrequency * pow(2.0, -abs(toleranceCents) * 3.0 / 1200.0)
        let outerUpper = centerFrequency * pow(2.0, abs(toleranceCents) * 3.0 / 1200.0)
        var energy = 0.0
        var count = 0
        for index in frequencyBins.indices where frequencyBins[index] >= outerLower && frequencyBins[index] <= outerUpper {
            if frequencyBins[index] >= innerLower && frequencyBins[index] <= innerUpper { continue }
            energy += magnitudes[index]
            count += 1
        }
        if count == 0 { return 0 }
        return energy / Double(count)
    }
}
