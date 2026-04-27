import Foundation
@testable import LonelyPianistAVP

struct FakeHarmonicBandEnergyProvider: HarmonicBandEnergyProviding {
    var bandEnergies: [Int: Double] = [:]
    var surroundingEnergies: [Int: Double] = [:]

    func bandEnergy(centerFrequency: Double, toleranceCents: Double) -> Double {
        bandEnergies[Self.key(centerFrequency)] ?? 0
    }

    func surroundingEnergy(centerFrequency: Double, toleranceCents: Double) -> Double {
        surroundingEnergies[Self.key(centerFrequency)] ?? 1
    }

    static func key(_ frequency: Double) -> Int { Int(round(frequency)) }
}
