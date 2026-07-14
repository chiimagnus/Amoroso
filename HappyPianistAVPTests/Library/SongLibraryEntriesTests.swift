import Foundation
@testable import HappyPianistAVP
import Testing

@Test
@MainActor
func libraryKeepsUserEntryThatSharesBundledDisplayName() {
    let sharedName = "Same Title"
    let bundled = SongLibraryEntry(
        id: UUID(),
        displayName: sharedName,
        musicXMLFileName: "bundled.musicxml",
        importedAt: .distantPast,
        audioFileName: nil,
        isBundled: true
    )
    let imported = SongLibraryEntry(
        id: UUID(),
        displayName: sharedName,
        musicXMLFileName: "imported.musicxml",
        importedAt: .now,
        audioFileName: nil
    )
    let viewModel = SongLibraryViewModelTestHarness.make(
        index: SongLibraryIndex(entries: [imported], lastSelectedEntryID: nil),
        bundledEntries: [bundled]
    )

    #expect(viewModel.entries.map(\.id) == [bundled.id, imported.id])
}

@Test
@MainActor
func libraryDeduplicatesOnlyIdenticalEntryIDs() {
    let id = UUID()
    let bundled = SongLibraryEntry(
        id: id,
        displayName: "Bundled",
        musicXMLFileName: "bundled.musicxml",
        importedAt: .distantPast,
        audioFileName: nil,
        isBundled: true
    )
    let duplicateID = SongLibraryEntry(
        id: id,
        displayName: "Imported",
        musicXMLFileName: "imported.musicxml",
        importedAt: .now,
        audioFileName: nil
    )
    let viewModel = SongLibraryViewModelTestHarness.make(
        index: SongLibraryIndex(entries: [duplicateID], lastSelectedEntryID: nil),
        bundledEntries: [bundled]
    )

    #expect(viewModel.entries == [bundled])
}

@Test
@MainActor
func batchImportKeepsSuccessfulEntriesVisibleWhenLaterPersistenceFails() async {
    let indexStore = FailingSecondSaveSongLibraryIndexStore()
    let fileStore = RecordingSongFileStore()
    let viewModel = SongLibraryViewModelTestHarness.make(
        indexStore: indexStore,
        fileStore: fileStore
    )

    await viewModel.importMusicXML(from: [
        URL(fileURLWithPath: "/tmp/first.musicxml"),
        URL(fileURLWithPath: "/tmp/second.musicxml"),
    ])

    #expect(viewModel.index.entries.map(\.displayName) == ["first"])
    let storedIndex = await indexStore.index
    #expect(storedIndex.entries.map(\.displayName) == ["first"])
    #expect(fileStore.deletedScoreNames == ["second.musicxml"])
    #expect(viewModel.errorMessage != nil)
}

private actor FailingSecondSaveSongLibraryIndexStore: SongLibraryIndexStoreProtocol {
    private(set) var index = SongLibraryIndex.empty
    private var saveCount = 0

    func load() throws -> SongLibraryIndex { index }

    func save(_ index: SongLibraryIndex) throws {
        saveCount += 1
        guard saveCount == 1 else { throw CocoaError(.fileWriteUnknown) }
        self.index = index
    }
}

private final class RecordingSongFileStore: SongFileStoreProtocol {
    private(set) var deletedScoreNames: [String] = []

    func importMusicXML(from sourceURL: URL) throws -> ImportedSongScoreFile {
        ImportedSongScoreFile(
            sourceFileName: sourceURL.lastPathComponent,
            storedFileName: sourceURL.lastPathComponent,
            storedURL: sourceURL,
            importedAt: .distantPast
        )
    }

    func scoreFileURL(fileName: String) throws -> URL { URL(fileURLWithPath: "/tmp/\(fileName)") }
    func audioFileURL(fileName: String) throws -> URL { URL(fileURLWithPath: "/tmp/\(fileName)") }
    func deleteScoreFile(named fileName: String) throws { deletedScoreNames.append(fileName) }
    func deleteAudioFile(named _: String) throws {}
}
