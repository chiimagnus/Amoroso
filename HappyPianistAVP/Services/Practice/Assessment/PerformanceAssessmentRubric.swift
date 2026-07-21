import Foundation

struct PerformanceAssessmentRubric: Sendable {
    let version = PerformanceAssessmentRubricVersion.capabilityAware

    func tolerance(
        for dimension: PerformanceAssessmentDimension,
        capabilities: PerformanceInputCapabilities
    ) -> Double {
        let base: Double = switch dimension {
        case .onset: 0.08
        case .tempoRelativeTiming: 0.2
        case .chordSpread: 0.08
        case .duration: 0.15
        case .release: 0.08
        case .articulation: 0.05
        case .velocity: 12
        case .dynamicContour: 8
        case .voicing: 8
        case .pedalTiming: 0.1
        case .pedalValue: 0.1
        case .tempoContinuity: 0.25
        case .phraseContinuity: 0.1
        case .exactPitch, .extraNotes, .missingNotes: 0
        }
        return evidence(for: dimension, capabilities: capabilities) == .degraded ? base * 1.5 : base
    }

    func select(
        _ results: [PerformanceAssessmentDimensionResult],
        capabilities: PerformanceInputCapabilities
    ) -> [PerformanceAssessmentDimensionResult] {
        results.filter { result in
            evidence(for: result.dimension, capabilities: capabilities) != .unavailable
                && result.evidenceStatus != .notObserved
        }
    }

    func evidence(
        for dimension: PerformanceAssessmentDimension,
        capabilities: PerformanceInputCapabilities
    ) -> PerformanceInputCapabilities.Evidence {
        switch dimension {
        case .exactPitch, .extraNotes, .missingNotes:
            capabilities.pitch
        case .onset, .tempoRelativeTiming, .tempoContinuity, .phraseContinuity:
            capabilities.onset
        case .chordSpread:
            .required(capabilities.onset, capabilities.polyphony)
        case .duration, .release:
            capabilities.release
        case .articulation:
            .required(capabilities.onset, capabilities.release)
        case .velocity, .dynamicContour, .voicing:
            capabilities.velocity
        case .pedalTiming, .pedalValue:
            capabilities.controllers
        }
    }
}

private extension PerformanceInputCapabilities.Evidence {
    static func required(_ values: Self...) -> Self {
        if values.contains(.unavailable) { return .unavailable }
        if values.contains(.degraded) { return .degraded }
        return .observed
    }
}
