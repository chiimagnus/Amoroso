import Foundation

struct TargetedHarmonicDetectionFrame: Sendable, Equatable {
    let events: [DetectedNoteEvent]
    let templateMatchResults: [TemplateMatchResult]
    let processingDurationMs: Double
    let suppressing: Bool
    let fallbackReason: String?
    let activeDetectorMode: PracticeAudioRecognitionDetectorMode
    let rollingWindowSize: Int
}
