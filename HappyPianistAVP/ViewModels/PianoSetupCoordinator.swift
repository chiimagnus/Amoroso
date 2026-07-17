import Observation

@MainActor
@Observable
final class PianoSetupCoordinator {
    let practiceSetupState: PracticeSetupState
    private let pianoModeRegistry: PianoModeRegistryProtocol

    var modes: [any PianoModeProtocol] {
        pianoModeRegistry.modes
    }

    var selectedMode: (any PianoModeProtocol)? {
        pianoModeRegistry.mode(for: practiceSetupState.selectedPianoModeID)
    }

    var isSetupReady: Bool {
        selectedMode?.isSetupReady(
            context: PianoModeReadinessContext(practiceSetupState: practiceSetupState)
        ) ?? false
    }

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
