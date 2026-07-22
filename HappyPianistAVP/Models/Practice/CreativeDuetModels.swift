import Foundation

/// Observed musical material supplied to an AI creative-duet backend.
///
/// This deliberately contains no `ScorePerformancePlan`, reference performance,
/// assessment target, or teacher fact. It is only the user's observable input.
struct CreativeDuetPhrase: Equatable, Sendable {
    let events: [ImprovEvent]
    let provenance: CreativeDuetPhraseProvenance
}

struct CreativeDuetPhraseProvenance: Equatable, Sendable {
    struct Observation: Equatable, Sendable {
        let id: UUID
        let source: PerformanceObservation.Source
        let timingProvenance: PerformanceClockCorrectionProvenance

        var capabilities: PerformanceInputCapabilities {
            source.capabilities
        }
    }

    let observations: [Observation]

    init(observations: [Observation]) {
        self.observations = observations.reduce(into: []) { unique, observation in
            if unique.contains(observation) == false {
                unique.append(observation)
            }
        }
    }

    static var empty: Self {
        Self(observations: [])
    }

    func merging(_ other: Self) -> Self {
        Self(observations: observations + other.observations)
    }
}

/// Identifies one cancellable creative generation, never a score-derived target.
struct CreativeDuetGeneration: Equatable, Sendable {
    let requestID: Int
    let activationID: Int
    let seed: UInt64
    let sessionID: String
    let parameters: ImprovGenerateParams
}

struct CreativeDuetResponse: Equatable, Sendable {
    let schedule: [PracticeSequencerMIDIEvent]
    let provider: ImprovBackendKind
    let generation: CreativeDuetGeneration
    let provenance: CreativeDuetResponseProvenance
}

enum CreativeDuetResponseProvenance: Equatable, Sendable {
    case backendGenerated(latencyMS: Int?)
}
