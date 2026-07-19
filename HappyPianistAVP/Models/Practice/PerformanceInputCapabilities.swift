struct PerformanceInputCapabilities: Codable, Equatable, Hashable, Sendable {
    enum Evidence: String, Codable, Sendable {
        case observed
        case unavailable
        case degraded
    }

    let pitch: Evidence
    let onset: Evidence
    let release: Evidence
    let velocity: Evidence
    let controllers: Evidence
    let polyphony: Evidence
    let hand: Evidence
    let finger: Evidence
    let position: Evidence
    let confidence: Evidence

    static let midi = Self(
        pitch: .observed,
        onset: .observed,
        release: .observed,
        velocity: .observed,
        controllers: .observed,
        polyphony: .observed,
        hand: .unavailable,
        finger: .unavailable,
        position: .unavailable,
        confidence: .unavailable
    )

    static let targetAudio = Self(
        pitch: .degraded,
        onset: .degraded,
        release: .unavailable,
        velocity: .unavailable,
        controllers: .unavailable,
        polyphony: .degraded,
        hand: .unavailable,
        finger: .unavailable,
        position: .unavailable,
        confidence: .observed
    )

    static let handContact = Self(
        pitch: .degraded,
        onset: .observed,
        release: .observed,
        velocity: .degraded,
        controllers: .unavailable,
        polyphony: .observed,
        hand: .observed,
        finger: .observed,
        position: .observed,
        confidence: .observed
    )
}

extension PerformanceObservation.Source.Kind {
    var defaultCapabilities: PerformanceInputCapabilities {
        switch self {
        case .midi1, .midi2:
            .midi
        case .targetAudio:
            .targetAudio
        case .realPianoContact, .virtualPianoContact:
            .handContact
        }
    }
}
