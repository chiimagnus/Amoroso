import CryptoKit
import Foundation

protocol SongLibraryImportTransactionRecovering: Actor {
    func recoverPendingTransactions() async -> SongLibraryTransactionRecoveryResult
}

actor SongLibraryImportTransactionService: SongLibraryImportTransactionRecovering {
    private let indexStore: any SongLibraryImportIndexStoreProtocol
    private let paths: SongLibraryPaths
    private let fileManager: FileManager
    private let now: @Sendable () -> Date
    private let makeUUID: @Sendable () -> UUID
    private let diagnostics: any DiagnosticsReporting

    init(
        indexStore: any SongLibraryImportIndexStoreProtocol,
        paths: SongLibraryPaths? = nil,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { .now },
        makeUUID: @escaping @Sendable () -> UUID = { UUID() },
        diagnostics: any DiagnosticsReporting
    ) {
        self.indexStore = indexStore
        self.paths = paths ?? SongLibraryPaths(fileManager: fileManager)
        self.fileManager = fileManager
        self.now = now
        self.makeUUID = makeUUID
        self.diagnostics = diagnostics
    }

    func recoverPendingTransactions() async -> SongLibraryTransactionRecoveryResult {
        do {
            try ensureRecoveryDirectoriesAreSafe()
            let root = try paths.transactionsDirectoryURL()
            let operationDirectories = try fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: []
            )
            for operationDirectory in operationDirectories.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                guard let operationID = UUID(uuidString: operationDirectory.lastPathComponent),
                      operationDirectory.lastPathComponent == operationID.uuidString.lowercased(),
                      try isPlainDirectory(operationDirectory)
                else {
                    return await blocked(operationID: nil, reason: "发现未知事务目录")
                }

                let result: SongLibraryTransactionRecoveryResult
                do {
                    result = try await recoverOperationDirectory(
                        operationDirectory,
                        operationID: operationID
                    )
                } catch {
                    return await blocked(operationID: operationID, reason: "事务内容无法安全读取")
                }
                if case .blocked = result {
                    return result
                }
            }
            return .recovered
        } catch {
            return await blocked(operationID: nil, reason: "事务恢复失败")
        }
    }

    private func ensureRecoveryDirectoriesAreSafe() throws {
        try ensurePlainDirectory(at: paths.rootDirectoryURL())
        try ensurePlainDirectory(at: paths.scoresDirectoryURL())
        try ensurePlainDirectory(at: paths.transactionsDirectoryURL())
    }

    private func ensurePlainDirectory(at url: URL) throws {
        if fileManager.fileExists(atPath: url.path()) {
            guard try isPlainDirectory(url) else {
                throw SongLibraryTransactionServiceError.unsafePath
            }
            return
        }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: false)
        guard try isPlainDirectory(url) else {
            throw SongLibraryTransactionServiceError.unsafePath
        }
    }

    private func recoverOperationDirectory(
        _ operationDirectory: URL,
        operationID: UUID
    ) async throws -> SongLibraryTransactionRecoveryResult {
        let journalURL = try paths.transactionJournalFileURL(operationID: operationID)
        guard fileManager.fileExists(atPath: journalURL.path()) else {
            guard try isSafeJournalLessScratch(operationDirectory) else {
                return await blocked(operationID: operationID, reason: "无法确认未记录事务的所有权")
            }
            try fileManager.removeItem(at: operationDirectory)
            return .recovered
        }

        let journal = try decodeJournal(at: journalURL)
        guard journal.operationID == operationID else {
            return await blocked(operationID: operationID, reason: "事务标识不一致")
        }
        guard try isSafeRecordedOperationDirectory(operationDirectory, journal: journal) else {
            return await blocked(operationID: operationID, reason: "事务目录包含未知内容")
        }
        return try await recover(journal: journal)
    }

    private func recover(journal: SongLibraryImportJournal) async throws -> SongLibraryTransactionRecoveryResult {
        for _ in 0..<8 {
            let facts = try await recoveryFacts(for: journal)
            switch SongLibraryTransactionRecoveryPlanner.action(journal: journal, facts: facts) {
            case .cleanup:
                try removeOperationDirectory(for: journal, facts: facts)
                return .recovered
            case .rollForwardTarget:
                try moveStageToTarget(journal: journal, facts: facts)
            case .commitIndex:
                guard try await commitIndex(journal: journal) else {
                    return await blocked(operationID: journal.operationID, reason: "索引事实已变化")
                }
            case .restoreBackup:
                try restoreBackup(journal: journal, facts: facts)
            case .removeUncommittedTarget:
                try removeUncommittedTarget(journal: journal, facts: facts)
            case .block:
                return await blocked(operationID: journal.operationID, reason: "事务文件或索引事实不一致")
            }
        }
        return await blocked(operationID: journal.operationID, reason: "事务恢复未能收敛")
    }

    private func recoveryFacts(for journal: SongLibraryImportJournal) async throws -> SongLibraryTransactionRecoveryFacts {
        let stageURL = try paths.transactionStageFileURL(
            operationID: journal.operationID,
            safeFileName: journal.safeFileName
        )
        let backupURL = try paths.transactionBackupFileURL(
            operationID: journal.operationID,
            safeFileName: journal.safeFileName
        )
        let targetURL = try paths.scoreFileURL(safeFileName: journal.safeFileName)
        return SongLibraryTransactionRecoveryFacts(
            stage: try observedFile(at: stageURL),
            backup: try observedFile(at: backupURL),
            target: try observedFile(at: targetURL),
            indexState: try await indexState(for: journal)
        )
    }

    private func indexState(for journal: SongLibraryImportJournal) async throws -> SongLibraryRecoveryIndexState {
        let index = try await indexStore.load()
        guard let payload = journal.newEntry else {
            return .neither
        }
        let matchingEntries = index.entries.filter { $0.id == payload.songID && $0.isBundled != true }
        guard matchingEntries.count <= 1 else { return .conflicting }
        guard let actual = matchingEntries.first else { return .neither }
        if SongLibraryFileNameIdentity.isExact(
            actual.musicXMLFileName,
            payload.musicXMLFileName
        ),
           actual.scoreFileVersionID == payload.scoreFileVersionID
        {
            return .newEntryPresent
        }
        if let expected = journal.expectedEntry,
           actual.id == expected.songID,
           SongLibraryFileNameIdentity.isExact(
            actual.musicXMLFileName,
            expected.musicXMLFileName
           ),
           actual.scoreFileVersionID == expected.scoreFileVersionID
        {
            return .expectedEntryPresent
        }
        return .conflicting
    }

    private func commitIndex(journal: SongLibraryImportJournal) async throws -> Bool {
        guard let payload = journal.newEntry else { return false }
        switch journal.kind {
        case .newImport, .orphanAdopt:
            _ = try await indexStore.appendUserEntry(payload.entry)
            return true
        case .indexedReplace, .missingTargetRepair:
            guard let expected = journal.expectedEntry else { return false }
            let result = try await indexStore.replaceUserScore(
                expectedSongID: expected.songID,
                expectedScoreFileVersionID: expected.scoreFileVersionID,
                expectedMusicXMLFileName: expected.musicXMLFileName,
                with: SongLibraryScoreReplacement(
                    musicXMLFileName: payload.musicXMLFileName,
                    importedAt: payload.importedAt,
                    scoreFileVersionID: payload.scoreFileVersionID
                )
            )
            if case .applied = result { return true }
            return false
        case .unclassified:
            return false
        }
    }

    private func moveStageToTarget(
        journal: SongLibraryImportJournal,
        facts: SongLibraryTransactionRecoveryFacts
    ) throws {
        let currentStage = try observedFile(
            at: paths.transactionStageFileURL(
                operationID: journal.operationID,
                safeFileName: journal.safeFileName
            )
        )
        let currentTarget = try observedFile(
            at: paths.scoreFileURL(safeFileName: journal.safeFileName)
        )
        guard facts.target.exists == false,
              currentTarget.exists == false,
              facts.stage.fingerprint == journal.stagedFingerprint,
              currentStage.fingerprint == journal.stagedFingerprint
        else { throw SongLibraryTransactionServiceError.changedFile }
        try fileManager.moveItem(
            at: paths.transactionStageFileURL(operationID: journal.operationID, safeFileName: journal.safeFileName),
            to: paths.scoreFileURL(safeFileName: journal.safeFileName)
        )
    }

    private func restoreBackup(
        journal: SongLibraryImportJournal,
        facts: SongLibraryTransactionRecoveryFacts
    ) throws {
        let currentBackup = try observedFile(
            at: paths.transactionBackupFileURL(
                operationID: journal.operationID,
                safeFileName: journal.safeFileName
            )
        )
        let currentTarget = try observedFile(
            at: paths.scoreFileURL(safeFileName: journal.safeFileName)
        )
        guard facts.target.exists == false,
              currentTarget.exists == false,
              facts.backup.fingerprint == journal.backupFingerprint,
              currentBackup.fingerprint == journal.backupFingerprint
        else { throw SongLibraryTransactionServiceError.changedFile }
        try fileManager.moveItem(
            at: paths.transactionBackupFileURL(operationID: journal.operationID, safeFileName: journal.safeFileName),
            to: paths.scoreFileURL(safeFileName: journal.safeFileName)
        )
    }

    private func removeUncommittedTarget(
        journal: SongLibraryImportJournal,
        facts: SongLibraryTransactionRecoveryFacts
    ) throws {
        let currentTarget = try observedFile(
            at: paths.scoreFileURL(safeFileName: journal.safeFileName)
        )
        guard facts.target.fingerprint == journal.stagedFingerprint,
              currentTarget.fingerprint == journal.stagedFingerprint
        else {
            throw SongLibraryTransactionServiceError.changedFile
        }
        try fileManager.removeItem(at: paths.scoreFileURL(safeFileName: journal.safeFileName))
    }

    private func removeOperationDirectory(
        for journal: SongLibraryImportJournal,
        facts: SongLibraryTransactionRecoveryFacts
    ) throws {
        let currentStage = try observedFile(
            at: paths.transactionStageFileURL(
                operationID: journal.operationID,
                safeFileName: journal.safeFileName
            )
        )
        let currentBackup = try observedFile(
            at: paths.transactionBackupFileURL(
                operationID: journal.operationID,
                safeFileName: journal.safeFileName
            )
        )
        guard facts.stage == currentStage,
              facts.backup == currentBackup,
              currentStage.exists == false
                || journal.phase == .preparing
                || currentStage.fingerprint == journal.stagedFingerprint,
              currentBackup.exists == false || currentBackup.fingerprint == journal.backupFingerprint,
              try containsNoSymbolicLinks(
                paths.transactionOperationDirectoryURL(operationID: journal.operationID)
              )
        else { throw SongLibraryTransactionServiceError.changedFile }
        try fileManager.removeItem(
            at: paths.transactionOperationDirectoryURL(operationID: journal.operationID)
        )
    }

    private func decodeJournal(at url: URL) throws -> SongLibraryImportJournal {
        guard try isPlainFile(url) else { throw SongLibraryTransactionServiceError.unsafePath }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        return try decoder.decode(SongLibraryImportJournal.self, from: Data(contentsOf: url))
    }

    private func observedFile(at url: URL) throws -> SongLibraryObservedTransactionFile {
        guard fileManager.fileExists(atPath: url.path()) else { return .missing }
        guard try isPlainFile(url) else { throw SongLibraryTransactionServiceError.unsafePath }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        var byteCount: Int64 = 0
        while let data = try handle.read(upToCount: 64 * 1024), data.isEmpty == false {
            byteCount += Int64(data.count)
            hasher.update(data: data)
        }
        let digits = Array("0123456789abcdef")
        let digest = hasher.finalize().flatMap { byte in
            [digits[Int(byte >> 4)], digits[Int(byte & 0x0f)]]
        }
        let digestText = String(digest)
        let fingerprint = try TransactionFileFingerprint(byteCount: byteCount, sha256: digestText)
        let values = try url.resourceValues(forKeys: [.fileResourceIdentifierKey])
        return SongLibraryObservedTransactionFile(
            exists: true,
            fingerprint: fingerprint,
            resourceIdentifier: values.fileResourceIdentifier.map { String(describing: $0) }
        )
    }

    private func isSafeJournalLessScratch(_ directory: URL) throws -> Bool {
        guard try containsNoSymbolicLinks(directory) else { return false }
        let children = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        guard children.count <= 1 else { return false }
        guard let stageDirectory = children.first else { return true }
        guard stageDirectory.lastPathComponent == "stage" else { return false }
        return try isPlainDirectory(stageDirectory)
    }

    private func isSafeRecordedOperationDirectory(
        _ directory: URL,
        journal: SongLibraryImportJournal
    ) throws -> Bool {
        guard try containsNoSymbolicLinks(directory) else { return false }
        let children = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let allowedNames = Set(["journal.json", "stage", "backup"])
        guard children.allSatisfy({ allowedNames.contains($0.lastPathComponent) }) else {
            return false
        }
        for child in children where child.lastPathComponent == "stage" || child.lastPathComponent == "backup" {
            guard try isPlainDirectory(child) else { return false }
            let files = try fileManager.contentsOfDirectory(at: child, includingPropertiesForKeys: nil)
            guard files.count <= 1,
                  files.allSatisfy({ $0.lastPathComponent == journal.safeFileName })
            else { return false }
        }
        return true
    }

    private func containsNoSymbolicLinks(_ directory: URL) throws -> Bool {
        guard try isPlainDirectory(directory) else { return false }
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isSymbolicLinkKey],
            options: []
        ) else { return false }
        for case let url as URL in enumerator {
            if try url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true {
                return false
            }
        }
        return true
    }

    private func isPlainDirectory(_ url: URL) throws -> Bool {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        return values.isDirectory == true && values.isSymbolicLink != true
    }

    private func isPlainFile(_ url: URL) throws -> Bool {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        return values.isRegularFile == true && values.isSymbolicLink != true
    }

    private func blocked(operationID: UUID?, reason: String) async -> SongLibraryTransactionRecoveryResult {
        _ = await diagnostics.record(
            DiagnosticEvent(
                severity: .error,
                code: .libraryImportRecoveryBlocked,
                category: .library,
                stage: "importRecovery",
                summary: "曲谱导入事务恢复被阻止",
                reason: reason,
                songID: nil,
                persistence: .systemOnly
            )
        )
        return .blocked(
            SongLibraryBlockedImport(
                operationID: operationID,
                message: "曲谱导入恢复需要处理，请修复文件后重试。"
            )
        )
    }
}

private enum SongLibraryTransactionServiceError: Error {
    case unsafePath
    case changedFile
}
