import ARKit
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

    enum ImmersiveMode {
        case calibration
        case practice
    }

    var immersiveSpaceState = ImmersiveSpaceState.closed
    var immersiveMode: ImmersiveMode = .practice

    let practiceSessionViewModel: PracticeSessionViewModel
    let arTrackingService: ARTrackingServiceProtocol

    var importedFile: ImportedMusicXMLFile?
    var importedSteps: [PracticeStep] = []
    var importErrorMessage: String?

    var storedCalibration: StoredWorldAnchorCalibration?

    var calibration: PianoCalibration? {
        didSet { applySessionIfPossible() }
    }
    let calibrationCaptureService: CalibrationPointCaptureService
    var pendingCalibrationCaptureAnchor: CalibrationAnchorPoint?
    var calibrationStatusMessage: String?

    private let worldAnchorCalibrationStore: WorldAnchorCalibrationStoreProtocol
    private let keyGeometryService: PianoKeyGeometryServiceProtocol
    private let importService: MusicXMLImportServiceProtocol
    private let parser: MusicXMLParserProtocol
    private let stepBuilder: PracticeStepBuilderProtocol

    init(
        worldAnchorCalibrationStore: WorldAnchorCalibrationStoreProtocol? = nil,
        keyGeometryService: PianoKeyGeometryServiceProtocol? = nil,
        importService: MusicXMLImportServiceProtocol? = nil,
        parser: MusicXMLParserProtocol? = nil,
        stepBuilder: PracticeStepBuilderProtocol? = nil,
        practiceSessionViewModel: PracticeSessionViewModel? = nil,
        arTrackingService: ARTrackingServiceProtocol? = nil,
        calibrationCaptureService: CalibrationPointCaptureService? = nil
    ) {
        self.worldAnchorCalibrationStore = worldAnchorCalibrationStore ?? WorldAnchorCalibrationStore()
        self.keyGeometryService = keyGeometryService ?? PianoKeyGeometryService()
        self.importService = importService ?? MusicXMLImportService()
        self.parser = parser ?? MusicXMLParser()
        self.stepBuilder = stepBuilder ?? PracticeStepBuilder()
        self.practiceSessionViewModel = practiceSessionViewModel ?? PracticeSessionViewModel()
        self.arTrackingService = arTrackingService ?? ARTrackingService()
        self.calibrationCaptureService = calibrationCaptureService ?? CalibrationPointCaptureService()
    }

    func beginCalibrationRecapture() {
        let persistedAnchorIDs = Set([
            storedCalibration?.a0AnchorID,
            storedCalibration?.c8AnchorID
        ].compactMap { $0 })
        let capturedAnchorIDs = Set([
            calibrationCaptureService.a0AnchorID,
            calibrationCaptureService.c8AnchorID
        ].compactMap { $0 }).subtracting(persistedAnchorIDs)

        guard capturedAnchorIDs.isEmpty == false else {
            resetCalibrationCaptureState()
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.removeCapturedAnchorsIfPossible(capturedAnchorIDs)
            self.resetCalibrationCaptureState()
        }
    }

    func setImportedSteps(_ steps: [PracticeStep], file: ImportedMusicXMLFile?) {
        importedSteps = steps
        importedFile = file
        importErrorMessage = nil
        applySessionIfPossible()
    }

    func importMusicXML(from selectedURL: URL) {
        do {
            let importedFile = try importService.importFile(from: selectedURL)
            let score = try parser.parse(fileURL: importedFile.storedURL)
            let buildResult = stepBuilder.buildSteps(from: score)
            if buildResult.unsupportedNoteCount > 0 {
                importErrorMessage = "已导入（忽略了 \(buildResult.unsupportedNoteCount) 个不支持的音符）。"
            } else {
                importErrorMessage = nil
            }
            setImportedSteps(buildResult.steps, file: importedFile)
        } catch {
            importErrorMessage = "导入失败：\(error.localizedDescription)"
        }
    }

    func loadStoredCalibrationIfPossible() {
        do {
            guard let stored = try worldAnchorCalibrationStore.load() else { return }
            storedCalibration = stored
            calibrationStatusMessage = "已加载校准（待定位）"
        } catch {
            calibrationStatusMessage = "加载校准失败：\(error.localizedDescription)"
        }
    }

    func saveCalibrationIfPossible() {
        guard
            let a0AnchorID = calibrationCaptureService.a0AnchorID,
            let c8AnchorID = calibrationCaptureService.c8AnchorID,
            a0AnchorID != c8AnchorID
        else {
            calibrationStatusMessage = "校准信息不完整"
            return
        }

        let savedCalibration = StoredWorldAnchorCalibration(
            a0AnchorID: a0AnchorID,
            c8AnchorID: c8AnchorID,
            whiteKeyWidth: calibration?.whiteKeyWidth ?? storedCalibration?.whiteKeyWidth ?? 0.0235
        )
        let previousStoredCalibration = storedCalibration

        do {
            try worldAnchorCalibrationStore.save(savedCalibration)
            storedCalibration = savedCalibration
            calibration = nil
            pendingCalibrationCaptureAnchor = nil
            calibrationCaptureService.reset()
            calibrationStatusMessage = "已保存校准（待定位）"

            if let previousStoredCalibration {
                Task { @MainActor [weak self] in
                    await self?.removeOldAnchorsIfPossible(
                        previous: previousStoredCalibration,
                        current: savedCalibration
                    )
                }
            }
        } catch {
            calibrationStatusMessage = "保存校准失败：\(error.localizedDescription)"
        }
    }

    private func removeOldAnchorsIfPossible(
        previous: StoredWorldAnchorCalibration,
        current: StoredWorldAnchorCalibration
    ) async {
        let oldIDs = Set([previous.a0AnchorID, previous.c8AnchorID])
        let currentIDs = Set([current.a0AnchorID, current.c8AnchorID])

        for oldID in oldIDs where currentIDs.contains(oldID) == false {
            guard let oldAnchor = arTrackingService.worldAnchorsByID[oldID] else {
                print("未在当前环境恢复该锚点，无法删除（UUID=\(oldID.uuidString)）")
                continue
            }

            do {
                try await arTrackingService.worldTrackingProvider.removeAnchor(oldAnchor)
            } catch {
                print("删除旧锚点失败（UUID=\(oldID.uuidString)）：\(error.localizedDescription)")
            }
        }
    }

    private func removeCapturedAnchorsIfPossible(_ anchorIDs: Set<UUID>) async {
        for anchorID in anchorIDs {
            guard let anchor = arTrackingService.worldAnchorsByID[anchorID] else {
                continue
            }

            do {
                try await arTrackingService.worldTrackingProvider.removeAnchor(anchor)
            } catch {
                print("删除临时校准锚点失败（UUID=\(anchorID.uuidString)）：\(error.localizedDescription)")
            }
        }
    }

    private func resetCalibrationCaptureState() {
        pendingCalibrationCaptureAnchor = nil
        calibrationStatusMessage = "请重新校准"
        calibration = nil
        calibrationCaptureService.reset()
        practiceSessionViewModel.resetSession()
    }

    private func applySessionIfPossible() {
        guard let calibration, importedSteps.isEmpty == false else { return }
        let keyRegions = keyGeometryService.generateKeyRegions(from: calibration)
        practiceSessionViewModel.configure(steps: importedSteps, calibration: calibration, keyRegions: keyRegions)
    }
}
