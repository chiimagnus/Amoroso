import Foundation

enum HarmonicTemplateCandidateRole: String, Equatable, CaseIterable {
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

struct HarmonicPartialTemplate: Equatable {
    let harmonicIndex: Int
    let centerFrequency: Double
    let toleranceCents: Double
    let weight: Double
}

struct HarmonicTemplate: Equatable {
    let midiNote: Int
    let role: HarmonicTemplateCandidateRole
    let partials: [HarmonicPartialTemplate]
}

struct HarmonicPartialDebugValue: Equatable {
    let harmonicIndex: Int
    let centerFrequency: Double
    let bandEnergy: Double
    let surroundingEnergy: Double
    let weightedEnergy: Double
}
