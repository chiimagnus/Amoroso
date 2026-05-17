import Observation
import os

@MainActor
@Observable
final class WindowCoordinator {
    private static let logger = Logger(subsystem: "LonelyPianistAVP", category: "WindowCoordinator")

    enum Window: Hashable {
        case preparation
        case library
        case practice

        var id: String {
            switch self {
            case .preparation:
                WindowIDs.preparation
            case .library:
                WindowIDs.library
            case .practice:
                WindowIDs.practice
            }
        }
    }

    let flowState: FlowState
    let pianoModeRegistry: PianoModeRegistryProtocol
    var pendingPushTarget: Window?

    init(flowState: FlowState, pianoModeRegistry: PianoModeRegistryProtocol) {
        self.flowState = flowState
        self.pianoModeRegistry = pianoModeRegistry
    }

    func consumePendingPushTarget() -> Window? {
        defer { pendingPushTarget = nil }
        return pendingPushTarget
    }

    func resetToPreparation(reason: String) {
        Self.logger.info("resetToPreparation: \(reason)")
        flowState.clearSongAndSteps()
        flowState.isCalibrationCompleted = false
        flowState.isVirtualPianoPlaced = false
        flowState.bluetoothMIDISourceCount = 0
        flowState.selectedPianoModeID = nil
    }
}
