import Foundation
@testable import HappyPianistAVP
import Testing

@Test
@MainActor
func resetPianoSetupClearsPracticeSetupState() {
    let practiceSetupState = PracticeSetupState()
    practiceSetupState.selectedPianoModeID = "dummy"
    practiceSetupState.isCalibrationCompleted = true
    practiceSetupState.isVirtualPianoPlaced = true
    practiceSetupState.bluetoothMIDISourceCount = 2
    practiceSetupState.importErrorMessage = "error"
    practiceSetupState.setImportedSteps(from: makeTestPreparedPractice())

    let registry = PianoModeRegistryService(modes: [])
    let coordinator = PianoSetupCoordinator(
        practiceSetupState: practiceSetupState,
        pianoModeRegistry: registry,
        storedTouchCalibration: { nil }
    )
    coordinator.reset()

    #expect(practiceSetupState.selectedPianoModeID == nil)
    #expect(practiceSetupState.isCalibrationCompleted == false)
    #expect(practiceSetupState.isVirtualPianoPlaced == false)
    #expect(practiceSetupState.bluetoothMIDISourceCount == 0)
    #expect(practiceSetupState.importedSteps.isEmpty)
    #expect(practiceSetupState.importedFile == nil)
    #expect(practiceSetupState.importErrorMessage == nil)
}

@Test
@MainActor
func setupReadinessUsesOnlySelectedModeRequirements() {
    let state = PracticeSetupState()
    let coordinator = PianoSetupCoordinator(
        practiceSetupState: state,
        pianoModeRegistry: PianoModeRegistryService(
            modes: PianoModeCatalogService.makeDefaultModes()
        ),
        storedTouchCalibration: { nil }
    )

    #expect(coordinator.isSetupReady == false)

    state.selectedPianoModeID = PianoModeID.realAudio.rawValue
    #expect(coordinator.isSetupReady == false)
    state.isCalibrationCompleted = true
    #expect(coordinator.isSetupReady)

    state.selectedPianoModeID = PianoModeID.bluetoothMIDI.rawValue
    #expect(coordinator.isSetupReady == false)
    state.bluetoothMIDISourceCount = 1
    #expect(coordinator.isSetupReady)

    state.selectedPianoModeID = PianoModeID.virtualPiano.rawValue
    #expect(coordinator.isSetupReady == false)
    state.isVirtualPianoPlaced = true
    #expect(coordinator.isSetupReady)
}

@Test
@MainActor
func setupCoordinatorUsesStoredCalibrationForPhysicalPianoOnly() {
    let stored = PianoTouchCalibration(
        planeOffsetMeters: 0.006,
        releaseHysteresisMeters: 0.01,
        minimumStrikeSpeedMetersPerSecond: 0.2,
        fullScaleStrikeSpeedMetersPerSecond: 2,
        minimumVelocity: 40,
        maximumVelocity: 120,
        curveExponent: 1,
        retriggerDebounceSeconds: 0.04
    )
    let state = PracticeSetupState()
    let coordinator = PianoSetupCoordinator(
        practiceSetupState: state,
        pianoModeRegistry: PianoModeRegistryService(modes: PianoModeCatalogService.makeDefaultModes()),
        storedTouchCalibration: { stored }
    )

    state.selectedPianoModeID = PianoModeID.realAudio.rawValue
    #expect(coordinator.touchCalibration == stored)

    state.selectedPianoModeID = PianoModeID.virtualPiano.rawValue
    #expect(coordinator.touchCalibration.id != stored.id)
    #expect(coordinator.touchCalibration.planeOffsetMeters == 0.002)
}

@Test
func touchVelocityCurveIsDeterministicAndBounded() {
    let calibration = PianoTouchCalibration(
        planeOffsetMeters: 0.004,
        releaseHysteresisMeters: 0.012,
        minimumStrikeSpeedMetersPerSecond: 0.1,
        fullScaleStrikeSpeedMetersPerSecond: 1.1,
        minimumVelocity: 30,
        maximumVelocity: 110,
        curveExponent: 1,
        retriggerDebounceSeconds: 0.03
    )
    let resolver = PianoTouchVelocityResolver(calibration: calibration)

    #expect(resolver.resolve(normalVelocityMetersPerSecond: -0.09) == nil)
    #expect(resolver.resolve(normalVelocityMetersPerSecond: -0.1) == 30)
    #expect(resolver.resolve(normalVelocityMetersPerSecond: -0.6) == 70)
    #expect(resolver.resolve(normalVelocityMetersPerSecond: -1.1) == 110)
    #expect(resolver.resolve(normalVelocityMetersPerSecond: -4) == 110)
}
