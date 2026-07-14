import Foundation

struct SongLibraryBootstrapSnapshot: Sendable {
    let index: SongLibraryIndex
    let bundledEntries: [SongLibraryEntry]
    let errorMessage: String?

    static func loaded(
        index: SongLibraryIndex,
        bundledEntries: [SongLibraryEntry]
    ) -> SongLibraryBootstrapSnapshot {
        SongLibraryBootstrapSnapshot(
            index: index,
            bundledEntries: bundledEntries,
            errorMessage: nil
        )
    }
}

protocol SongLibraryBootstrapLoading: Actor {
    func load() -> SongLibraryBootstrapSnapshot
}

actor LiveSongLibraryBootstrapLoader: SongLibraryBootstrapLoading {
    private let indexStore = SongLibraryIndexStore()
    private let bundledProvider = BundledSongLibraryProvider()

    func load() -> SongLibraryBootstrapSnapshot {
        let bundledEntries = bundledProvider.bundledEntries()
        do {
            return .loaded(
                index: try indexStore.load(),
                bundledEntries: bundledEntries
            )
        } catch {
            return SongLibraryBootstrapSnapshot(
                index: .empty,
                bundledEntries: bundledEntries,
                errorMessage: "加载乐曲库失败：\(error.localizedDescription)"
            )
        }
    }
}
