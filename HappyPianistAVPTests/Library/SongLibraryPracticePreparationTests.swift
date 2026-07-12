import Foundation
@testable import HappyPianistAVP
import Testing

private actor DelayedPreparationService: PracticePreparationServiceProtocol {
    let delays: [UUID: Duration]
    let includesMeasureSpans: Bool

    init(delays: [UUID: Duration], includesMeasureSpans: Bool = true) {
        self.delays = delays
        self.includesMeasureSpans = includesMeasureSpans
    }

    func prepare(songID: UUID, from _: URL, file: ImportedMusicXMLFile) async throws -> PreparedPractice {
        if let delay = delays[songID] {
            try await Task.sleep(for: delay)
        }
        return PreparedPractice(
            identity: PracticeSongIdentity(songID: songID, scoreRevision: songID.uuidString),
            steps: [PracticeStep(tick: 0, notes: [PracticeStepNote(midiNote: 60, staff: 1)])],
            file: file,
            tempoMap: MusicXMLTempoMap(tempoEvents: []),
            pedalTimeline: nil,
            fermataTimeline: nil,
            attributeTimeline: nil,
            slurTimeline: nil,
            highlightGuides: [],
            measureSpans: includesMeasureSpans ? [MusicXMLMeasureSpan(
                partID: "P1",
                measureNumber: 1,
                sourceMeasureIndex: 0,
                sourceMeasureNumberToken: "1",
                occurrenceIndex: 0,
                startTick: 0,
                endTick: 1
            )] : [],
            unsupportedNoteCount: 0
        )
    }
}

private struct PreparationTestBundledProvider: BundledSongLibraryProviderProtocol {
    let entries: [SongLibraryEntry]
    let scoreURL: URL

    func bundledEntries() -> [SongLibraryEntry] { entries }
    func musicXMLURL(fileName _: String) -> URL? { scoreURL }
    func audioURL(fileName _: String) -> URL? { nil }
}

@Test
@MainActor
func latestPreparationGenerationWins() async throws {
    let url = FileManager.default.temporaryDirectory.appending(path: "generation-\(UUID().uuidString).musicxml")
    try Data("<score-partwise/>".utf8).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }

    let firstID = UUID()
    let secondID = UUID()
    let entries = [
        SongLibraryEntry(id: firstID, displayName: "First", musicXMLFileName: "first.musicxml", importedAt: .now, audioFileName: nil, isBundled: true),
        SongLibraryEntry(id: secondID, displayName: "Second", musicXMLFileName: "second.musicxml", importedAt: .now, audioFileName: nil, isBundled: true),
    ]
    let service = DelayedPreparationService(delays: [firstID: .milliseconds(80), secondID: .milliseconds(5)])
    let appState = AppState()
    let viewModel = SongLibraryViewModel(
        appState: appState,
        practicePreparationService: service,
        indexStore: PreparationTestIndexStore(),
        fileStore: PreparationTestFileStore(),
        audioImportService: PreparationTestAudioImporter(),
        bundledProvider: PreparationTestBundledProvider(entries: entries, scoreURL: url),
        audioPlayer: PreparationTestAudioPlayer(),
        practiceProgressRepository: PreparationTestProgressRepository(),
        diagnosticsReporter: InMemoryDiagnosticsReporter()
    )

    viewModel.selectEntryForPractice(firstID)
    try await Task.sleep(for: .milliseconds(10))
    viewModel.selectEntryForPractice(secondID)
    try await waitForPreparation(viewModel, entryID: secondID)

    #expect(viewModel.practicePreparationState == .ready(
        entryID: secondID,
        identity: PracticeSongIdentity(songID: secondID, scoreRevision: secondID.uuidString)
    ))
    #expect(appState.practiceSetupState.preparedPracticeIdentity?.songID == secondID)
}


@Test
@MainActor
func preparationWithoutMeasureSpansIsRejectedAtTheLibraryBoundary() async throws {
    let url = FileManager.default.temporaryDirectory.appending(path: "missing-measures-\(UUID().uuidString).musicxml")
    try Data("<score-partwise/>".utf8).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }

    let entryID = UUID()
    let entry = SongLibraryEntry(
        id: entryID,
        displayName: "Missing Measures",
        musicXMLFileName: "missing.musicxml",
        importedAt: .now,
        audioFileName: nil,
        isBundled: true
    )
    let appState = AppState()
    let viewModel = SongLibraryViewModel(
        appState: appState,
        practicePreparationService: DelayedPreparationService(delays: [:], includesMeasureSpans: false),
        indexStore: PreparationTestIndexStore(),
        fileStore: PreparationTestFileStore(),
        audioImportService: PreparationTestAudioImporter(),
        bundledProvider: PreparationTestBundledProvider(entries: [entry], scoreURL: url),
        audioPlayer: PreparationTestAudioPlayer(),
        practiceProgressRepository: PreparationTestProgressRepository(),
        diagnosticsReporter: InMemoryDiagnosticsReporter()
    )

    viewModel.selectEntryForPractice(entryID)
    try await waitForPreparationFailure(viewModel, entryID: entryID)

    guard case let .failure(failure) = viewModel.practicePreparationState else {
        Issue.record("Expected preparation failure")
        return
    }
    #expect(failure.code == .practiceMissingMeasureStructure)
    #expect(appState.practiceSetupState.preparedPracticeIdentity == nil)
}

private func waitForPreparation(
    _ viewModel: SongLibraryViewModel,
    entryID: UUID
) async throws {
    for _ in 0..<100 {
        if case let .ready(readyEntryID, _) = viewModel.practicePreparationState,
           readyEntryID == entryID {
            return
        }
        try await Task.sleep(for: .milliseconds(5))
    }
    Issue.record("Timed out waiting for ready preparation")
}

private func waitForPreparationFailure(
    _ viewModel: SongLibraryViewModel,
    entryID: UUID
) async throws {
    for _ in 0..<100 {
        if case let .failure(failure) = viewModel.practicePreparationState,
           failure.entryID == entryID {
            return
        }
        try await Task.sleep(for: .milliseconds(5))
    }
    Issue.record("Timed out waiting for preparation failure")
}

private final class PreparationTestIndexStore: SongLibraryIndexStoreProtocol {
    var value = SongLibraryIndex.empty
    func load() throws -> SongLibraryIndex { value }
    func save(_ index: SongLibraryIndex) throws { value = index }
}

private struct PreparationTestFileStore: SongFileStoreProtocol {
    func importMusicXML(from _: URL) throws -> ImportedSongScoreFile { throw CocoaError(.fileNoSuchFile) }
    func scoreFileURL(fileName _: String) throws -> URL { throw CocoaError(.fileNoSuchFile) }
    func audioFileURL(fileName _: String) throws -> URL { throw CocoaError(.fileNoSuchFile) }
    func deleteScoreFile(named _: String) throws {}
    func deleteAudioFile(named _: String) throws {}
}

private struct PreparationTestAudioImporter: AudioImportServiceProtocol {
    func importAudio(from _: URL) throws -> String { throw CocoaError(.fileNoSuchFile) }
}

private final class PreparationTestAudioPlayer: SongAudioPlayerProtocol {
    var onPlaybackFinished: ((UUID?) -> Void)?
    var currentEntryID: UUID?
    func play(entryID _: UUID, url _: URL) throws {}
    func pause() {}
    func stop() {}
    func isPlaying(entryID _: UUID) -> Bool { false }
}


private actor PreparationTestProgressRepository: PracticeProgressRepositoryProtocol {
    func load() -> PracticeProgressLoadResult { .loaded(PracticeProgressDocument()) }
    func progress(for _: PracticeSongIdentity) -> SongPracticeProgress? { nil }
    func upsert(_: SongPracticeProgress) {}
    func remove(songID _: UUID) {}
}
