import Foundation

extension PracticeSessionViewModel {
    func refreshPracticeInputForCurrentState() {
        practiceMIDIInputCoordinator?.refresh(
            for: .init(
                practiceState: state,
                autoplayState: autoplayState,
                isManualReplayPlaying: isManualReplayPlaying,
                currentStepIndex: currentStepIndex,
                expectedNotes: currentStep?.notes ?? []
            )
        )
    }

    func stopPracticeInput() {
        practiceMIDIInputCoordinator?.stop()
    }
}
