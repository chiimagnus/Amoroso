import Foundation
@testable import HappyPianistAVP
import Testing

@Test
func songFileStoreImportsMusicXMLIntoScoresDirectory() async throws {
    let documentsURL = try makeTemporaryDirectory(prefix: "SongFileStoreTests-docs")
    let externalURL = try makeTemporaryDirectory(prefix: "SongFileStoreTests-external")
    defer {
        try? FileManager.default.removeItem(at: documentsURL)
        try? FileManager.default.removeItem(at: externalURL)
    }

    let sourceURL = externalURL.appendingPathComponent("sample.musicxml")
    try Data("<score-partwise version=\"3.1\"></score-partwise>".utf8).write(to: sourceURL)

    let fileManager: FileManager = TestDocumentsFileManager(documentsURL: documentsURL)
    let paths = SongLibraryPaths(fileManager: fileManager)
    let scoresDirectory = try paths.scoresDirectoryURL().path()
    let fileStore = SongFileStore(
        fileManager: fileManager,
        paths: paths,
        now: { Date(timeIntervalSince1970: 1_700_000_000) }
    )

    let imported = try await fileStore.importMusicXML(from: sourceURL)

    #expect(imported.sourceFileName == "sample.musicxml")
    #expect(imported.storedFileName.contains("sample.musicxml"))
    #expect(FileManager.default.fileExists(atPath: imported.storedURL.path()))

    #expect(imported.storedURL.path().hasPrefix(scoresDirectory))
}

@Test
func songFileStoreDeleteRemovesScoreAndAudioFiles() async throws {
    let documentsURL = try makeTemporaryDirectory(prefix: "SongFileStoreTests-delete")
    defer { try? FileManager.default.removeItem(at: documentsURL) }

    let fileManager: FileManager = TestDocumentsFileManager(documentsURL: documentsURL)
    let paths = SongLibraryPaths(fileManager: fileManager)
    try paths.ensureDirectoriesExist()

    let scoreFileName = "to-delete.musicxml"
    let audioFileName = "to-delete.m4a"

    let scoreURL = try paths.scoresDirectoryURL().appendingPathComponent(scoreFileName)
    let audioURL = try paths.audioDirectoryURL().appendingPathComponent(audioFileName)

    try Data("score".utf8).write(to: scoreURL)
    try Data("audio".utf8).write(to: audioURL)

    let fileStore = SongFileStore(fileManager: fileManager, paths: paths)

    try await fileStore.deleteScoreFile(named: scoreFileName)
    try await fileStore.deleteAudioFile(named: audioFileName)

    #expect(FileManager.default.fileExists(atPath: scoreURL.path()) == false)
    #expect(FileManager.default.fileExists(atPath: audioURL.path()) == false)
}

@Test(arguments: ["", ".", "..", "../outside.musicxml", "folder/score.musicxml", "folder\\score.musicxml"])
func songFileStoreRejectsUnsafeIndexFileNames(fileName: String) async throws {
    let documentsURL = try makeTemporaryDirectory(prefix: "SongFileStoreTests-invalid")
    defer { try? FileManager.default.removeItem(at: documentsURL) }
    let fileManager: FileManager = TestDocumentsFileManager(documentsURL: documentsURL)
    let fileStore = SongFileStore(
        fileManager: fileManager,
        paths: SongLibraryPaths(fileManager: fileManager)
    )

    await #expect(throws: SongFileStoreError.invalidFileName(fileName)) {
        _ = try await fileStore.scoreFileURL(fileName: fileName)
    }
}

private func makeTemporaryDirectory(prefix: String) throws -> URL {
    let directoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    return directoryURL
}

private final class TestDocumentsFileManager: FileManager {
    private let documentsURL: URL

    init(documentsURL: URL) {
        self.documentsURL = documentsURL
        super.init()
    }

    override func urls(for directory: SearchPathDirectory, in domainMask: SearchPathDomainMask) -> [URL] {
        if directory == .documentDirectory {
            return [documentsURL]
        }
        return super.urls(for: directory, in: domainMask)
    }
}
