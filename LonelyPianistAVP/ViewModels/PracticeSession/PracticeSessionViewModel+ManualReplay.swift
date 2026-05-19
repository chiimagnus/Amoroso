import Foundation

extension PracticeSessionViewModel {
    func startManualReplay(with plan: ManualReplayPlan) {
        stopVirtualPianoInput()
        manualReplayCoordinator?.startManualReplay(with: plan)
    }

    func stopManualReplayTask(restoreAudioRecognition: Bool = true) {
        manualReplayCoordinator?.stopManualReplayTask(restoreAudioRecognition: restoreAudioRecognition)
    }
}

