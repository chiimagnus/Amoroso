import Observation

@MainActor
@Observable
final class PianoSetupCoordinator {
    let practiceSetupState: PracticeSetupState
    private let pianoModeRegistry: PianoModeRegistryProtocol
    private let storedTouchCalibration: @MainActor () -> PianoTouchCalibration?
    private let defaultRealTouchCalibration: PianoTouchCalibration
    private let defaultVirtualTouchCalibration: PianoTouchCalibration

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

    var touchCalibration: PianoTouchCalibration {
        let modeID = selectedMode?.descriptor.id
        if modeID != .virtualPiano, let stored = storedTouchCalibration() {
            return stored
        }
        return modeID == .virtualPiano ? defaultVirtualTouchCalibration : defaultRealTouchCalibration
    }

    init(
        practiceSetupState: PracticeSetupState,
        pianoModeRegistry: PianoModeRegistryProtocol,
        storedTouchCalibration: @escaping @MainActor () -> PianoTouchCalibration?
    ) {
        self.practiceSetupState = practiceSetupState
        self.pianoModeRegistry = pianoModeRegistry
        self.storedTouchCalibration = storedTouchCalibration
        defaultRealTouchCalibration = PianoModeTouchCalibrationService.conservativeDefault(for: .realAudio)
        defaultVirtualTouchCalibration = PianoModeTouchCalibrationService.conservativeDefault(for: .virtualPiano)
    }

    func reset() {
        practiceSetupState.clearSongAndSteps()
        practiceSetupState.isCalibrationCompleted = false
        practiceSetupState.isVirtualPianoPlaced = false
        practiceSetupState.bluetoothMIDISourceCount = 0
        practiceSetupState.selectedPianoModeID = nil
    }
}
