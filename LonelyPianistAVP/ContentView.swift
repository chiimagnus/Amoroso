import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(AppModel.self) private var appModel

    @State private var isImporterPresented = false

    private let importService: MusicXMLImportServiceProtocol = MusicXMLImportService()
    private let parser: MusicXMLParserProtocol = MusicXMLParser()
    private let stepBuilder: PracticeStepBuilderProtocol = PracticeStepBuilder()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("LonelyPianist")
                .font(.largeTitle)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
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

            VStack(alignment: .leading, spacing: 8) {
                Text("Calibration")
                    .font(.headline)

                Text(appModel.calibration == nil ? "Not calibrated" : "Calibrated")
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

            VStack(alignment: .leading, spacing: 8) {
                Text("Practice")
                    .font(.headline)

                Text(practiceStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    ToggleImmersiveSpaceButton()

                    Button("Skip") {
                        appModel.practiceSessionViewModel.skip()
                    }

                    Button("Mark Correct") {
                        appModel.practiceSessionViewModel.markCorrect()
                    }
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
        .onAppear {
            appModel.loadStoredCalibrationIfPossible()
        }
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

