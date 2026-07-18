import Foundation

struct MusicXMLInterpretationProfile: Equatable, Sendable {
    static let generic = MusicXMLInterpretationProfile(
        id: "generic-score-v1",
        staccatissimoDurationMultiplier: 0.25,
        staccatoDurationMultiplier: 0.5,
        detachedLegatoDurationMultiplier: 0.75,
        marcatoDurationMultiplier: 0.75,
        fermataExtraDurationMultiplier: 0.5,
        fermataMaximumExtraTicks: MusicXMLTempoMap.ticksPerQuarter * 2
    )

    let id: String
    let staccatissimoDurationMultiplier: Double
    let staccatoDurationMultiplier: Double
    let detachedLegatoDurationMultiplier: Double
    let marcatoDurationMultiplier: Double
    let fermataExtraDurationMultiplier: Double
    let fermataMaximumExtraTicks: Int

    func durationMultiplier(for articulations: Set<MusicXMLArticulation>) -> Double {
        if articulations.contains(.staccatissimo) {
            return staccatissimoDurationMultiplier
        }
        if articulations.contains(.staccato) {
            return staccatoDurationMultiplier
        }
        if articulations.contains(.detachedLegato) {
            return detachedLegatoDurationMultiplier
        }
        if articulations.contains(.marcato) {
            return marcatoDurationMultiplier
        }
        return 1
    }

    func fermataExtraTicks(forBaseDurationTicks durationTicks: Int) -> Int {
        let base = max(1, durationTicks)
        let proposed = max(1, Int((Double(base) * fermataExtraDurationMultiplier).rounded()))
        return min(proposed, max(1, fermataMaximumExtraTicks))
    }
}
