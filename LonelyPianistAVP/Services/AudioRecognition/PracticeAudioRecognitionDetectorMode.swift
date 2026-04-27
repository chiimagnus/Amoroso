import Foundation

enum PracticeAudioRecognitionDetectorMode: String, CaseIterable, Sendable, Equatable {
    case automatic
    case harmonicTemplate
    case simpleGoertzel
}
