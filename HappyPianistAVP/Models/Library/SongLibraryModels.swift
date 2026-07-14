import Foundation

struct SongLibraryEntry: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var displayName: String
    var musicXMLFileName: String
    var scoreFileVersionID: UUID?
    var importedAt: Date
    var audioFileName: String?
    var isBundled: Bool?

    init(
        id: UUID,
        displayName: String,
        musicXMLFileName: String,
        scoreFileVersionID: UUID? = nil,
        importedAt: Date,
        audioFileName: String?,
        isBundled: Bool? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.musicXMLFileName = musicXMLFileName
        self.scoreFileVersionID = scoreFileVersionID
        self.importedAt = importedAt
        self.audioFileName = audioFileName
        self.isBundled = isBundled
    }
}

struct SongLibraryIndex: Codable, Equatable, Sendable {
    var entries: [SongLibraryEntry]
    var lastSelectedEntryID: UUID?

    static var empty: SongLibraryIndex {
        SongLibraryIndex(entries: [], lastSelectedEntryID: nil)
    }
}

enum SongLibraryLayout {
    static let rootDirectoryName = "SongLibrary"
    static let scoresDirectoryName = "scores"
    static let audioDirectoryName = "audio"
    static let indexFileName = "index.json"
}
