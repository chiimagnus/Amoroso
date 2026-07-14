import Foundation

enum PracticeProgressLoadResult: Equatable, Sendable {
    case loaded(PracticeProgressDocument)
    case corrupted(description: String)
}

enum PracticeProgressRepositoryError: Error, Equatable {
    case corrupted(description: String)
}

protocol PracticeProgressRepositoryProtocol: Sendable {
    func load() async -> PracticeProgressLoadResult
    func progress(for identity: PracticeSongIdentity) async -> SongPracticeProgress?
    func history(for songID: UUID) async -> PracticeSongHistoryLoadResult
    func upsert(_ progress: SongPracticeProgress) async throws
    func upsert(_ metadata: SongScorePracticeMetadata) async throws
    func remove(songID: UUID) async throws
}

actor FilePracticeProgressRepository: PracticeProgressRepositoryProtocol {
    private let fileManager: FileManager
    private let paths: PracticeProgressPaths

    init(
        fileManager: FileManager = .default,
        paths: PracticeProgressPaths = PracticeProgressPaths()
    ) {
        self.fileManager = fileManager
        self.paths = paths
    }

    func load() -> PracticeProgressLoadResult {
        do {
            return .loaded(try loadDocument())
        } catch {
            return .corrupted(description: error.localizedDescription)
        }
    }

    func progress(for identity: PracticeSongIdentity) -> SongPracticeProgress? {
        guard case let .loaded(document) = load() else { return nil }
        return PracticeProgressRecordOrder.preferred(
            in: document.songs.filter { $0.identity == identity }
        )
    }

    func history(for songID: UUID) -> PracticeSongHistoryLoadResult {
        switch load() {
        case let .loaded(document):
            return .loaded(
                PracticeSongHistory(
                    songID: songID,
                    progresses: PracticeProgressRecordOrder.sorted(
                        document.songs.filter { $0.identity.songID == songID }
                    ),
                    scoreMetadata: Self.sortedMetadata(
                        document.scoreMetadata.filter { $0.songID == songID }
                    )
                )
            )
        case let .corrupted(description):
            return .corrupted(description: description)
        }
    }

    func upsert(_ progress: SongPracticeProgress) throws {
        var document = try loadDocument()
        document.songs.removeAll { $0.identity == progress.identity }
        document.songs.append(progress)
        document.songs = PracticeProgressRecordOrder.sorted(document.songs)
        try saveDocument(document)
    }

    func upsert(_ metadata: SongScorePracticeMetadata) throws {
        var document = try loadDocument()
        document.scoreMetadata.removeAll {
            $0.songID == metadata.songID
                && $0.scoreFileVersionID == metadata.scoreFileVersionID
                && $0.scoreRevision == metadata.scoreRevision
        }
        document.scoreMetadata.append(metadata)
        document.scoreMetadata = Self.sortedMetadata(document.scoreMetadata)
        try saveDocument(document)
    }

    func remove(songID: UUID) throws {
        var document = try loadDocument()
        document.songs.removeAll(where: { $0.identity.songID == songID })
        document.scoreMetadata.removeAll(where: { $0.songID == songID })
        try saveDocument(document)
    }

    private func loadDocument() throws -> PracticeProgressDocument {
        let fileURL = paths.fileURL
        guard fileManager.fileExists(atPath: fileURL.path()) else {
            return PracticeProgressDocument()
        }

        let data = try Data(contentsOf: fileURL)
        guard data.isEmpty == false,
              String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        else {
            return PracticeProgressDocument()
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(PracticeProgressDocument.self, from: data)
        } catch {
            throw PracticeProgressRepositoryError.corrupted(description: error.localizedDescription)
        }
    }

    private func saveDocument(_ document: PracticeProgressDocument) throws {
        try fileManager.createDirectory(at: paths.rootDirectoryURL, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(document).write(to: paths.fileURL, options: .atomic)
    }

    private static func sortedMetadata(
        _ metadata: [SongScorePracticeMetadata]
    ) -> [SongScorePracticeMetadata] {
        metadata.sorted { lhs, rhs in
            if lhs.songID != rhs.songID {
                return lhs.songID.uuidString < rhs.songID.uuidString
            }
            if lhs.scoreFileVersionID != rhs.scoreFileVersionID {
                switch (lhs.scoreFileVersionID, rhs.scoreFileVersionID) {
                case (nil, .some): return true
                case (.some, nil): return false
                case let (.some(lhsToken), .some(rhsToken)):
                    return lhsToken.uuidString < rhsToken.uuidString
                case (nil, nil): break
                }
            }
            if lhs.scoreRevision != rhs.scoreRevision {
                return lhs.scoreRevision < rhs.scoreRevision
            }
            if lhs.preparedAt != rhs.preparedAt {
                return lhs.preparedAt < rhs.preparedAt
            }
            return lhs.totalSourceMeasureCount < rhs.totalSourceMeasureCount
        }
    }
}
