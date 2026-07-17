import Observation

@MainActor
@Observable
final class PianoSetupCoordinator {
    let practiceSetupState: PracticeSetupState
    let pianoModeRegistry: PianoModeRegistryProtocol

    init(practiceSetupState: PracticeSetupState, pianoModeRegistry: PianoModeRegistryProtocol) {
        self.practiceSetupState = practiceSetupState
        self.pianoModeRegistry = pianoModeRegistry
    }

    func reset() {
        practiceSetupState.clearSongAndSteps()
        practiceSetupState.isCalibrationCompleted = false
        practiceSetupState.isVirtualPianoPlaced = false
        practiceSetupState.bluetoothMIDISourceCount = 0
        practiceSetupState.selectedPianoModeID = nil
    }
}
