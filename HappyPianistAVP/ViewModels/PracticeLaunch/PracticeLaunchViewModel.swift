import Foundation
import Observation

@MainActor
protocol PracticeLaunchApplying: AnyObject, Sendable {
    func applyPreparedPracticeForLaunch(
        _ prepared: PreparedPractice,
        restorePolicy: PracticeLaunchRestorePolicy,
        isCurrent: @escaping @MainActor () -> Bool
    ) async -> PracticeLaunchApplyOutcome?
    func clearPreparedPracticeForLaunch() async
    func suspendPracticeAndFlushProgress() async
    func leavePracticeStep() async
}

@MainActor
@Observable
final class PracticeLaunchViewModel {
    private let resolver: any SongLibraryEntryResolving
    private let preparationService: any PracticePreparationServiceProtocol
    private let applicator: any PracticeLaunchApplying
    private let diagnosticsReporter: any DiagnosticsReporting
    private let progressRepository: any PracticeProgressRepositoryProtocol
    private let historicalPreferencesResolver: PracticeHistoricalPreferencesResolver
    private let now: @Sendable () -> Date

    @ObservationIgnored private var activationTask: Task<Void, Never>?
    @ObservationIgnored private var metadataWriteTasks: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var returnOperationID: UUID?

    private(set) var state: PracticeLaunchState = .noRequest
    private(set) var requestedSongID: UUID?
    private(set) var activationIdentity: PracticeLaunchActivationIdentity?

    init(
        resolver: any SongLibraryEntryResolving,
        preparationService: any PracticePreparationServiceProtocol,
        applicator: any PracticeLaunchApplying,
        diagnosticsReporter: any DiagnosticsReporting,
        progressRepository: any PracticeProgressRepositoryProtocol,
        historicalPreferencesResolver: PracticeHistoricalPreferencesResolver = PracticeHistoricalPreferencesResolver(),
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.resolver = resolver
        self.preparationService = preparationService
        self.applicator = applicator
        self.diagnosticsReporter = diagnosticsReporter
        self.progressRepository = progressRepository
        self.historicalPreferencesResolver = historicalPreferencesResolver
        self.now = now
    }

    func request(songID: UUID) {
        if requestedSongID == songID {
            switch state {
            case .requested, .loading, .ready:
                return
            case .noRequest, .failure:
                break
            }
        }
        registerRequest(songID: songID)
    }

    func activateCurrentRequest() async {
        guard activationTask == nil,
              let songID = requestedSongID,
              case .requested(songID) = state
        else { return }
        let currentGeneration = generation
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performActivation(songID: songID, generation: currentGeneration)
        }
        activationTask = task
        await task.value
        if generation == currentGeneration {
            activationTask = nil
        }
    }

    func retry() async {
        guard let songID = requestedSongID else { return }
        registerRequest(songID: songID)
        await activateCurrentRequest()
    }

    func suspendForInactiveScene() async {
        activationTask?.cancel()
        activationTask = nil
        generation += 1
        if let songID = requestedSongID {
            state = .requested(songID: songID)
            activationIdentity = PracticeLaunchActivationIdentity(
                songID: songID,
                revision: generation
            )
        }
        await applicator.suspendPracticeAndFlushProgress()
    }

    func beginReturn() -> UUID {
        if let returnOperationID { return returnOperationID }
        activationTask?.cancel()
        activationTask = nil
        generation += 1
        requestedSongID = nil
        activationIdentity = nil
        state = .noRequest
        let operationID = UUID()
        returnOperationID = operationID
        return operationID
    }

    func finishReturn(operationID: UUID) async {
        guard returnOperationID == operationID else { return }
        returnOperationID = nil
        await applicator.clearPreparedPracticeForLaunch()
    }

    private func registerRequest(songID: UUID) {
        activationTask?.cancel()
        activationTask = nil
        generation += 1
        returnOperationID = nil
        requestedSongID = songID
        state = .requested(songID: songID)
        activationIdentity = PracticeLaunchActivationIdentity(
            songID: songID,
            revision: generation
        )
    }

    private func performActivation(songID: UUID, generation: Int) async {
        guard isCurrent(songID: songID, generation: generation) else { return }
        state = .loading(songID: songID)
        await applicator.clearPreparedPracticeForLaunch()
        guard isCurrent(songID: songID, generation: generation) else { return }

        var fileReference: DiagnosticFileReference?
        do {
            let resolved = try await resolver.resolve(songID: songID)
            fileReference = resolved.diagnosticFileReference
            let history = await progressRepository.history(for: songID)
            if case .corrupted = history {
                _ = await diagnosticsReporter.record(
                    DiagnosticEvent(
                        severity: .warning,
                        code: .practiceHistoryLoadFailed,
                        category: .persistence,
                        stage: "practiceHistoryLoad",
                        summary: "无法读取练习历史",
                        reason: "The practice progress document could not be decoded.",
                        songID: songID,
                        file: fileReference,
                        persistence: .exportable
                    )
                )
            }
            guard isCurrent(songID: songID, generation: generation) else { return }
            _ = await diagnosticsReporter.record(
                DiagnosticEvent(
                    severity: .info,
                    code: .practicePreparationStarted,
                    category: .practicePreparation,
                    stage: "practiceLaunchActivation",
                    summary: "开始准备曲谱练习数据",
                    reason: "A registered practice request became active.",
                    songID: songID,
                    file: fileReference,
                    persistence: .exportable
                )
            )
            guard isCurrent(songID: songID, generation: generation) else { return }
            let prepared = try await preparationService.prepare(
                songID: songID,
                from: resolved.scoreURL,
                file: ImportedMusicXMLFile(
                    fileName: resolved.entry.displayName,
                    storedURL: resolved.scoreURL,
                    importedAt: resolved.entry.importedAt
                )
            )
            try Task.checkCancellation()
            guard prepared.steps.isEmpty == false else {
                throw PracticePreparationError.noPlayableNotes
            }
            guard prepared.measureSpans.isEmpty == false else {
                throw PracticePreparationError.missingMeasureStructure
            }
            let restorePolicy = await historicalPreferencesResolver.resolve(
                identity: prepared.identity,
                history: history
            )
            guard isCurrent(songID: songID, generation: generation) else { return }
            let applyOutcome = await applicator.applyPreparedPracticeForLaunch(
                prepared,
                restorePolicy: restorePolicy,
                isCurrent: { [weak self] in
                    self?.isCurrent(songID: songID, generation: generation) == true
                }
            )
            guard let applyOutcome else {
                guard isCurrent(songID: songID, generation: generation) else { return }
                registerRequest(songID: songID)
                return
            }

            let metadata = SongScorePracticeMetadata(
                songID: songID,
                scoreFileVersionID: resolved.entry.scoreFileVersionID,
                scoreRevision: prepared.identity.scoreRevision,
                totalSourceMeasureCount: Set(prepared.measureSpans.map(\.sourceMeasureID)).count,
                preparedAt: now()
            )
            guard isCurrent(songID: songID, generation: generation) else {
                scheduleMetadataWrite(metadata)
                return
            }

            state = .ready(prepared.identity)
            scheduleMetadataWrite(metadata)
            _ = await diagnosticsReporter.record(
                DiagnosticEvent(
                    severity: .info,
                    code: .practicePreparationSucceeded,
                    category: .practicePreparation,
                    stage: "practiceLaunchActivation",
                    summary: "曲谱练习数据已准备完成",
                    reason: "Prepared \(prepared.steps.count) steps and \(prepared.measureSpans.count) measure occurrences.",
                    songID: songID,
                    scoreRevision: prepared.identity.scoreRevision,
                    file: fileReference,
                    persistence: .exportable
                )
            )
            switch applyOutcome {
            case .applied:
                break
            case .appliedWithRepairedSavedState:
                _ = await diagnosticsReporter.record(
                    DiagnosticEvent(
                        severity: .warning,
                        code: .practiceSavedConfigurationRepaired,
                        category: .practiceSession,
                        stage: "practiceProgressRestore",
                        summary: "已修复无效的练习恢复位置",
                        reason: "Saved passage or resume data did not match the current score revision and was replaced with a valid full-score state.",
                        songID: songID,
                        scoreRevision: prepared.identity.scoreRevision,
                        persistence: .exportable
                    )
                )
            case .appliedWithUnpersistedRepair:
                _ = await diagnosticsReporter.record(
                    DiagnosticEvent(
                        severity: .warning,
                        code: .practiceSavedConfigurationRepairFailed,
                        category: .practiceSession,
                        stage: "practiceProgressRestore",
                        summary: "无法保存练习恢复位置修复",
                        reason: "The in-memory fallback is safe, but its repaired configuration could not be persisted and may need repair again on the next launch.",
                        songID: songID,
                        scoreRevision: prepared.identity.scoreRevision,
                        persistence: .exportable
                    )
                )
            }
        } catch is CancellationError {
            return
        } catch {
            guard isCurrent(songID: songID, generation: generation) else { return }
            let preparationError: PracticePreparationError
            if let resolutionError = error as? SongLibraryEntryResolutionError {
                preparationError = resolutionError.preparationError
                fileReference = resolutionError.diagnosticFileReference
            } else {
                preparationError = (error as? PracticePreparationError) ?? .unexpected(
                    stage: "practiceLaunchActivation",
                    reason: PracticePreparationErrorDetails.safeErrorSummary(error)
                )
            }
            let failure = PracticeLaunchFailure.map(
                preparationError,
                entryID: songID,
                file: fileReference
            )
            state = .failure(failure)
            _ = await diagnosticsReporter.record(failure.diagnosticEvent)
        }
    }

    private func isCurrent(songID: UUID, generation: Int) -> Bool {
        self.generation == generation &&
            requestedSongID == songID &&
            Task.isCancelled == false
    }

    private func scheduleMetadataWrite(_ metadata: SongScorePracticeMetadata) {
        let operationID = UUID()
        let repository = progressRepository
        let reporter = diagnosticsReporter
        metadataWriteTasks[operationID] = Task { @MainActor [weak self] in
            do {
                try await repository.upsert(metadata)
            } catch {
                _ = await reporter.record(
                    DiagnosticEvent(
                        severity: .warning,
                        code: .practiceScoreMetadataWriteFailed,
                        category: .persistence,
                        stage: "practiceScoreMetadataWrite",
                        summary: "无法保存曲谱练习元数据",
                        reason: "token=\(metadata.scoreFileVersionID?.uuidString ?? "legacy-nil"); measureCount=\(metadata.totalSourceMeasureCount); \(PracticePreparationErrorDetails.safeErrorSummary(error))",
                        songID: metadata.songID,
                        scoreRevision: metadata.scoreRevision,
                        persistence: .exportable
                    )
                )
            }
            self?.metadataWriteTasks[operationID] = nil
        }
    }
}
