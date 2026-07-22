import Foundation
@testable import HappyPianistAVP
import Testing

@MainActor
@Test
func recordingTeardownCancelsPendingOfflineAlignment() async {
    let probe = RecordingAlignmentCancellationProbe()
    let library = TakeLibraryViewModel(
        store: InMemoryRecordingTakeStore(),
        midiExportService: StubRecordingMIDIExportService()
    )
    let playback = TakePlaybackViewModel(
        controller: TakePlaybackController(
            playbackService: NoopPracticeSequencerPlaybackService()
        )
    )
    let viewModel = ARGuideRecordingViewModel(
        takeLibraryViewModel: library,
        takePlaybackViewModel: playback,
        alignRecordedTake: { _, _ in await probe.run() }
    )
    let plan = ScorePerformancePlan(
        id: .init(rawValue: "recording-cancellation"),
        sourceScoreIdentity: .init(
            songID: UUID(),
            scoreRevision: "1",
            logicalInstrumentID: "piano"
        ),
        order: .init(requested: .performed, applied: .performed),
        resolution: .init(ticksPerQuarter: 480),
        noteEvents: [],
        tempoEvents: [],
        controllerEvents: [],
        annotations: [],
        approximations: []
    )

    await viewModel.startRecording(canRecord: true, performancePlan: plan)
    viewModel.recordTakeFromKeyContactIfNeeded(
        usesBluetoothMIDIInput: false,
        isVirtualPianoEnabled: true,
        observations: [makeTestKeyContactObservation(midiNote: 60, phase: .started)]
    )
    viewModel.stopRecording()
    #expect(await probe.waitUntilStarted())

    viewModel.stop()

    #expect(await probe.waitUntilCancelled())
    #expect(viewModel.alignmentDiagnosticsByTakeID.isEmpty)
}

private actor RecordingAlignmentCancellationProbe {
    private var started = false
    private var cancelled = false

    func run() async -> RecordedTakeAlignmentDiagnostics? {
        started = true
        do {
            try await Task.sleep(for: .seconds(30))
        } catch {
            cancelled = true
        }
        return nil
    }

    func waitUntilStarted() async -> Bool {
        for _ in 0 ..< 1_000 {
            if started { return true }
            await Task.yield()
        }
        return false
    }

    func waitUntilCancelled() async -> Bool {
        for _ in 0 ..< 1_000 {
            if cancelled { return true }
            await Task.yield()
        }
        return false
    }
}

private final class InMemoryRecordingTakeStore: RecordingTakeStoreProtocol {
    private var takes: [RecordingTake] = []

    func load() throws -> [RecordingTake] { takes }
    func save(_ takes: [RecordingTake]) throws { self.takes = takes }
}

private struct StubRecordingMIDIExportService: RecordingMIDIExportServiceProtocol {
    func makeMIDIExport(from _: RecordingTake) throws -> RecordingMIDIExport {
        .init(data: Data(), fileName: "take.mid")
    }
}
