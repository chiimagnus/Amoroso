import Foundation
import Observation

@MainActor
@Observable
final class SongLibraryViewModel {
    private let appModel: AppModel
    private let indexStore: SongLibraryIndexStoreProtocol
    private let fileStore: SongFileStoreProtocol

    var index: SongLibraryIndex = .empty
    var errorMessage: String?

    init(
        appModel: AppModel,
        indexStore: SongLibraryIndexStoreProtocol? = nil,
        fileStore: SongFileStoreProtocol? = nil
    ) {
        self.appModel = appModel
        self.indexStore = indexStore ?? SongLibraryIndexStore()
        self.fileStore = fileStore ?? SongFileStore()
        reload()
    }

    var entries: [SongLibraryEntry] {
        index.entries
    }

    func reload() {
        do {
            index = try indexStore.load()
        } catch {
            errorMessage = "加载乐曲库失败：\(error.localizedDescription)"
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    func didTapImportMusicXML() {
        // 由 View 层触发 fileImporter
    }

    func importMusicXML(from selectedURLs: [URL]) {
        guard selectedURLs.isEmpty == false else { return }

        do {
            var updatedIndex = try indexStore.load()

            for url in selectedURLs {
                let imported = try fileStore.importMusicXML(from: url)
                let entry = SongLibraryEntry(
                    id: UUID(),
                    displayName: URL(fileURLWithPath: imported.sourceFileName)
                        .deletingPathExtension()
                        .lastPathComponent,
                    musicXMLFileName: imported.storedFileName,
                    importedAt: imported.importedAt,
                    audioFileName: nil
                )
                updatedIndex.entries.append(entry)
            }

            try indexStore.save(updatedIndex)
            index = updatedIndex
        } catch {
            errorMessage = "导入失败：\(error.localizedDescription)"
        }
    }

    func didTapStartPractice(entryID: UUID) {
        guard index.entries.contains(where: { $0.id == entryID }) else { return }
        errorMessage = "开始练习流程将在下一步接入。"
    }
}
