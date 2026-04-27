import Foundation

struct TemplateMatchResult: Equatable {
    let midiNote: Int
    let role: HarmonicTemplateCandidateRole
    let confidence: Double
    let harmonicScore: Double
    let tonalRatio: Double
    let dominanceOverWrong: Double
    let strongestPartials: [HarmonicPartialDebugValue]
}
