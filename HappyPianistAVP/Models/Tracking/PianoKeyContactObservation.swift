import Foundation
import simd

struct PianoKeyContactID: Hashable, Sendable {
    let finger: TrackedFingerID
    let sequence: UInt64
}

enum PianoKeyCandidate: Equatable, Sendable {
    case exact(Int)
    case ambiguous([Int])
    case unknown

    var exactMIDINote: Int? {
        guard case let .exact(midiNote) = self else { return nil }
        return midiNote
    }
}

struct PianoKeyContactObservation: Equatable, Sendable {
    enum Phase: Hashable, Sendable {
        case started
        case held
        case ended
    }

    let id: PianoKeyContactID
    let phase: Phase
    let keyCandidate: PianoKeyCandidate
    let timestamp: PerformanceMonotonicInstant
    let confidence: Float
    let worldPosition: SIMD3<Float>
    let planeDistanceMeters: Float
    let normalVelocityMetersPerSecond: Float?
    let calibrationID: UUID

    var hand: TrackedHandSide { id.finger.hand }
    var finger: TrackedFinger { id.finger.finger }
}

extension Collection where Element == PianoKeyContactObservation {
    var activeMIDINotes: Set<Int> {
        exactMIDINotes(for: [.started, .held])
    }

    var startedMIDINotes: Set<Int> {
        exactMIDINotes(for: [.started])
    }

    var endedMIDINotes: Set<Int> {
        exactMIDINotes(for: [.ended])
    }

    private func exactMIDINotes(for phases: Set<PianoKeyContactObservation.Phase>) -> Set<Int> {
        Set(
            lazy.compactMap { observation in
                phases.contains(observation.phase) ? observation.keyCandidate.exactMIDINote : nil
            }
        )
    }
}
