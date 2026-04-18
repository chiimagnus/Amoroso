import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(AppModel.self) private var appModel

    @State private var isImporterPresented = false
    @State private var isARGuideSheetPresented = false

    private let importService: MusicXMLImportServiceProtocol = MusicXMLImportService()
    private let parser: MusicXMLParserProtocol = MusicXMLParser()
    private let stepBuilder: PracticeStepBuilderProtocol = PracticeStepBuilder()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("LonelyPianist")
                .font(.largeTitle)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 10) {
                Text("AR Guide")
                    .font(.headline)

                HStack(spacing: 12) {
                    ToggleImmersiveSpaceButton()

                    Text(appModel.immersiveSpaceState == .open ? "Running" : "Stopped")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(appModel.calibration == nil ? "Calibration: not set" : "Calibration: loaded")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(nextActionHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let calibrationStatusMessage = appModel.calibrationStatusMessage {
                    Text(calibrationStatusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                Text("Score")
                    .font(.headline)

                HStack(spacing: 12) {
                    Button("Import MusicXML…") {
                        isImporterPresented = true
                    }

                    if let importedFile = appModel.importedFile {
                        Text(importedFile.fileName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No score imported")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let importErrorMessage = appModel.importErrorMessage {
                    Text(importErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if appModel.importedSteps.isEmpty == false {
                    Text("Steps: \(appModel.importedSteps.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                Text("Practice")
                    .font(.headline)

                Text(practiceStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if appModel.importedSteps.isEmpty == false {
                    HStack(spacing: 12) {
                        Button("Skip") { appModel.practiceSessionViewModel.skip() }
                            .disabled(appModel.immersiveSpaceState != .open)

                        Button("Mark Correct") { appModel.practiceSessionViewModel.markCorrect() }
                            .disabled(appModel.immersiveSpaceState != .open)
                    }
                } else {
                    Text("Import a score to enable step controls.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Spacer()
        }
        .padding(24)
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.xml, .musicXML],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .sheet(isPresented: $isARGuideSheetPresented) {
            ARGuideSheetView()
                .environment(appModel)
        }
        .onChange(of: appModel.immersiveSpaceState) { oldValue, newValue in
            if oldValue == .closed, newValue == .inTransition {
                isARGuideSheetPresented = true
                return
            }
            if oldValue == .open, newValue == .inTransition {
                isARGuideSheetPresented = false
                return
            }
            if newValue == .closed {
                isARGuideSheetPresented = false
                return
            }
            if newValue == .open {
                isARGuideSheetPresented = true
            }
        }
        .onAppear {
            appModel.loadStoredCalibrationIfPossible()
        }
    }

    private var nextActionHint: String {
        if appModel.calibration == nil {
            return "Next: Enter AR Guide, then use the HUD buttons: Set A0 → Set C8 → Save."
        }
        if appModel.importedSteps.isEmpty {
            return "Next: Import MusicXML in this window."
        }
        return "Next: Enter AR Guide to see highlighted keys and start guiding."
    }

    private var practiceStatusText: String {
        switch appModel.practiceSessionViewModel.state {
        case .idle:
            return "Idle"
        case .ready:
            return "Ready (enter AR guide)"
        case .guiding(let index):
            return "Guiding (step \(index + 1))"
        case .completed:
            return "Completed"
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        do {
            guard let selectedURL = try result.get().first else {
                return
            }
            let importedFile = try importService.importFile(from: selectedURL)
            let score = try parser.parse(fileURL: importedFile.storedURL)
            let buildResult = stepBuilder.buildSteps(from: score)
            if buildResult.unsupportedNoteCount > 0 {
                appModel.importErrorMessage = "Imported with \(buildResult.unsupportedNoteCount) unsupported notes ignored."
            }
            appModel.setImportedSteps(buildResult.steps, file: importedFile)
        } catch {
            appModel.importErrorMessage = "Import failed: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ContentView()
        .environment(AppModel())
}

private struct ARGuideSheetView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Text("AR Guide")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Stop") {
                    Task { @MainActor in
                        await dismissImmersiveSpace()
                    }
                }
                .fontWeight(.semibold)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(handTrackingStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(practiceStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if appModel.calibration == nil {
                calibrationControls
            } else if appModel.importedSteps.isEmpty {
                Text("Import MusicXML in the main window to start guiding.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                practiceControls
            }

            if let message = appModel.calibrationStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(20)
        .presentationDetents([.medium, .large])
    }

    private var calibrationControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Calibration")
                .font(.headline)

            Text(appModel.pendingCalibrationCaptureAnchor == nil ? "Tap in space to preview the reticle." : "Tap in space to capture the selected anchor.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Set A0") { appModel.pendingCalibrationCaptureAnchor = .a0 }
                Button("Set C8") { appModel.pendingCalibrationCaptureAnchor = .c8 }
                Button("Save") { appModel.saveCalibrationIfPossible() }
                    .fontWeight(.semibold)
            }

            Button("Manual Fallback") {
                appModel.calibrationCaptureService.updateReticleEstimate(nil)
            }

            if appModel.calibrationCaptureService.mode == .manualFallback {
                HStack(spacing: 8) {
                    Button("A0 ◀︎") {
                        appModel.calibrationCaptureService.adjust(anchor: .a0, delta: SIMD3<Float>(-0.01, 0, 0))
                    }
                    Button("A0 ▶︎") {
                        appModel.calibrationCaptureService.adjust(anchor: .a0, delta: SIMD3<Float>(0.01, 0, 0))
                    }
                    Button("C8 ◀︎") {
                        appModel.calibrationCaptureService.adjust(anchor: .c8, delta: SIMD3<Float>(-0.01, 0, 0))
                    }
                    Button("C8 ▶︎") {
                        appModel.calibrationCaptureService.adjust(anchor: .c8, delta: SIMD3<Float>(0.01, 0, 0))
                    }
                }
            }
        }
    }

    private var practiceControls: some View {
        HStack(spacing: 12) {
            Button("Skip") { appModel.practiceSessionViewModel.skip() }
            Button("Mark Correct") { appModel.practiceSessionViewModel.markCorrect() }
        }
    }

    private var handTrackingStatusText: String {
        switch appModel.handTrackingService.state {
        case .idle:
            return "Hands: idle"
        case .running:
            return "Hands: running (\(appModel.handTrackingService.fingerTipPositions.count) tips)"
        case .unavailable(let reason):
            return "Hands: unavailable (\(reason))"
        }
    }

    private var practiceStatusText: String {
        switch appModel.practiceSessionViewModel.state {
        case .idle:
            return "Practice: idle"
        case .ready:
            return "Practice: ready"
        case .guiding(let index):
            return "Practice: guiding (step \(index + 1))"
        case .completed:
            return "Practice: completed"
        }
    }
}
