import Foundation

enum PracticeSessionEffect: Equatable, Sendable {
    case refreshPracticeInput
    case refreshAudioRecognition
    case playCurrentStepSound(applyRecognitionSuppress: Bool)
    case stopTransientWork
    case stopAudioRecognition
    case stopPracticeInput
}

