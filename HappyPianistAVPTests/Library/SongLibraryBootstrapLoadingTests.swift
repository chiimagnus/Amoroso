@testable import HappyPianistAVP
import Testing

@MainActor
@Test
func songLibraryBootstrapLoadsOnceWithoutBlockingViewModelConstruction() async {
    let entry = SongLibraryEntry(
        id: UUID(),
        displayName: "Bundled",
        musicXMLFileName: "Bundled.musicxml",
        importedAt: .now,
        audioFileName: nil,
        isBundled: true
    )
    let loader = TestSongLibraryBootstrapLoader(
        snapshot: .loaded(index: .empty, bundledEntries: [entry])
    )
    let viewModel = SongLibraryViewModelTestHarness.make(
        bootstrapLoader: loader,
        deferInitialLoad: true
    )

    #expect(viewModel.hasLoadedLibrary == false)
    #expect(viewModel.entries.isEmpty)

    await viewModel.loadLibraryIfNeeded()
    await viewModel.loadLibraryIfNeeded()

    #expect(viewModel.hasLoadedLibrary)
    #expect(viewModel.entries == [entry])
    #expect(await loader.loadCount() == 1)
}

private actor TestSongLibraryBootstrapLoader: SongLibraryBootstrapLoading {
    private let snapshot: SongLibraryBootstrapSnapshot
    private var count = 0

    init(snapshot: SongLibraryBootstrapSnapshot) {
        self.snapshot = snapshot
    }

    func load() -> SongLibraryBootstrapSnapshot {
        count += 1
        return snapshot
    }

    func loadCount() -> Int {
        count
    }
}
