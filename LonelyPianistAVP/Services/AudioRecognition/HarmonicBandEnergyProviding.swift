import Foundation

protocol HarmonicBandEnergyProviding: Sendable {
    func bandEnergy(centerFrequency: Double, toleranceCents: Double) -> Double
    func surroundingEnergy(centerFrequency: Double, toleranceCents: Double) -> Double
}
