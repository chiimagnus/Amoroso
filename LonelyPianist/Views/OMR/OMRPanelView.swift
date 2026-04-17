import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct OMRPanelView: View {
    @State private var isImporterPresented = false
    @State private var selectedInputURL: URL?
    @State private var outputMusicXMLURL: URL?
    @State private var statusMessage = "Select a score and convert to MusicXML."
    @State private var isConverting = false

    private let conversionService: OMRConversionServiceProtocol = OMRConversionService()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("OMR Converter")
                .font(.title2.bold())

            Text("1. Choose a PDF/image  2. Click Convert  3. Open generated score.musicxml")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Select Score…") {
                    isImporterPresented = true
                }

                Button("Convert") {
                    convertSelectedFile()
                }
                .disabled(selectedInputURL == nil || isConverting)
            }

            if let selectedInputURL {
                Text("Input: \(selectedInputURL.path)")
                    .font(.callout)
                    .textSelection(.enabled)
            }

            if let outputMusicXMLURL {
                Text("Output: \(outputMusicXMLURL.path)")
                    .font(.callout)
                    .textSelection(.enabled)
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([outputMusicXMLURL])
                }
            }

            Text(statusMessage)
                .font(.callout)
                .foregroundStyle(isConverting ? .secondary : .primary)

            Spacer()
        }
        .padding(20)
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.pdf, .png, .jpeg],
            allowsMultipleSelection: false
        ) { result in
            do {
                selectedInputURL = try result.get().first
                outputMusicXMLURL = nil
                statusMessage = "Ready to convert."
            } catch {
                statusMessage = "File selection failed: \(error.localizedDescription)"
            }
        }
    }

    private func convertSelectedFile() {
        guard let selectedInputURL else { return }
        isConverting = true
        statusMessage = "Converting..."
        Task {
            do {
                let output = try conversionService.convert(inputURL: selectedInputURL)
                await MainActor.run {
                    outputMusicXMLURL = output
                    statusMessage = "Convert succeeded."
                    isConverting = false
                }
            } catch {
                await MainActor.run {
                    statusMessage = "Convert failed: \(error.localizedDescription)"
                    isConverting = false
                }
            }
        }
    }
}
