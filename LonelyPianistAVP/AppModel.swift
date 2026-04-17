//
//  AppModel.swift
//  LonelyPianistAVP
//
//  Created by chii_magnus on 2026/4/6.
//

import SwiftUI

/// Maintains app-wide state
@MainActor
@Observable
class AppModel {
    let immersiveSpaceID = "ImmersiveSpace"
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    var immersiveSpaceState = ImmersiveSpaceState.closed

    var practiceSessionViewModel = PracticeSessionViewModel()
    var handTrackingService = HandTrackingService()

    var importedFile: ImportedMusicXMLFile?
    var importedSteps: [PracticeStep] = []
    var importErrorMessage: String?

    var calibration: PianoCalibration? {
        didSet { applySessionIfPossible() }
    }
    var calibrationCaptureService = CalibrationPointCaptureService()
    var pendingCalibrationCaptureAnchor: CalibrationAnchorPoint?
    var calibrationStatusMessage: String?

    private let calibrationStore: PianoCalibrationStoreProtocol
    private let keyGeometryService: PianoKeyGeometryServiceProtocol

    init(
        calibrationStore: PianoCalibrationStoreProtocol = PianoCalibrationStore(),
        keyGeometryService: PianoKeyGeometryServiceProtocol = PianoKeyGeometryService()
    ) {
        self.calibrationStore = calibrationStore
        self.keyGeometryService = keyGeometryService
    }

    func setImportedSteps(_ steps: [PracticeStep], file: ImportedMusicXMLFile?) {
        importedSteps = steps
        importedFile = file
        importErrorMessage = nil
        applySessionIfPossible()
    }

    func loadStoredCalibrationIfPossible() {
        do {
            guard let stored = try calibrationStore.load() else { return }
            calibration = stored
            calibrationCaptureService.a0Point = stored.a0.simdValue
            calibrationCaptureService.c8Point = stored.c8.simdValue
            calibrationCaptureService.updateReticleEstimate(stored.a0.simdValue)
            calibrationStatusMessage = "Calibration loaded"
        } catch {
            calibrationStatusMessage = "Failed to load calibration: \(error.localizedDescription)"
        }
    }

    func saveCalibrationIfPossible() {
        guard let built = calibrationCaptureService.buildCalibration() else {
            calibrationStatusMessage = "Calibration is incomplete"
            return
        }
        do {
            try calibrationStore.save(built)
            calibration = built
            calibrationStatusMessage = "Calibration saved"
        } catch {
            calibrationStatusMessage = "Failed to save calibration: \(error.localizedDescription)"
        }
    }

    private func applySessionIfPossible() {
        guard let calibration, importedSteps.isEmpty == false else { return }
        let keyRegions = keyGeometryService.generateKeyRegions(from: calibration)
        practiceSessionViewModel.configure(steps: importedSteps, calibration: calibration, keyRegions: keyRegions)
    }
}
