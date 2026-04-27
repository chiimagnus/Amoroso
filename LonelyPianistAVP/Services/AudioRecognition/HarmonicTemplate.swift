import Foundation

enum HarmonicTemplateCandidateRole: String, Sendable, Equatable, CaseIterable {
    case expected
    case wrongCandidate
    case octaveDebug

    var priority: Int {
        switch self {
            case .expected: 3
            case .wrongCandidate: 2
            case .octaveDebug: 1
        }
    }
}

struct HarmonicPartialTemplate: Sendable, Equatable {
    let harmonicIndex: Int
    let centerFrequency: Double
    let toleranceCents: Double
    let weight: Double
}

struct HarmonicTemplate: Sendable, Equatable {
    let midiNote: Int
    let role: HarmonicTemplateCandidateRole
    let partials: [HarmonicPartialTemplate]
}

struct HarmonicPartialDebugValue: Sendable, Equatable {
    let harmonicIndex: Int
    let centerFrequency: Double
    let bandEnergy: Double
    let surroundingEnergy: Double
    let weightedEnergy: Double
}
