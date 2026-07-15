import Foundation

protocol SongPracticeLibrarySnapshotBuilding: Sendable {
    @concurrent
    nonisolated func build(
        entry: SongLibraryEntry,
        history: PracticeSongHistory
    ) async -> SongPracticeLibrarySnapshotBuildResult
}

struct SongPracticeLibrarySnapshotBuilder: SongPracticeLibrarySnapshotBuilding {
    private let isolationObserver: (@Sendable ((any Actor)?) -> Void)?

    init(isolationObserver: (@Sendable ((any Actor)?) -> Void)? = nil) {
        self.isolationObserver = isolationObserver
    }

    @concurrent
    nonisolated func build(
        entry: SongLibraryEntry,
        history: PracticeSongHistory
    ) async -> SongPracticeLibrarySnapshotBuildResult {
        let isolation: (any Actor)? = #isolation
        isolationObserver?(isolation)
        let progresses = deduplicatedProgresses(
            history.progresses.filter { $0.identity.songID == entry.id }
        )
        let realHistoricalFacts = progresses.flatMap(\.measureFacts).filter(
            SongPracticeMeasureFactOrder.hasRealAttempt
        )
        guard realHistoricalFacts.isEmpty == false else {
            return .neverPracticed
        }
        let latestPracticeDate = realHistoricalFacts.compactMap(\.lastAttemptAt).max()

        let identity = SongPracticeLibrarySelectionIdentity(
            songID: entry.id,
            scoreFileVersionID: entry.scoreFileVersionID
        )

        let metadata = SongScorePracticeMetadataOrder.preferred(
            in: history.scoreMetadata.filter {
                $0.songID == entry.id && $0.scoreFileVersionID == entry.scoreFileVersionID
            }
        )
        guard let metadata else {
            return .current(SongPracticeLibrarySnapshot(
                identity: identity,
                status: .currentVersionNotPracticed,
                latestPracticeDate: latestPracticeDate,
                totalSourceMeasureCount: 0,
                measureProgress: .metadataUnavailable,
                currentFacts: nil,
                hasHistory: true
            ))
        }

        let currentProgress = PracticeProgressRecordOrder.preferred(
            in: progresses.filter { $0.identity.scoreRevision == metadata.scoreRevision }
        )
        let currentFacts = deriveCurrentFacts(
            currentProgress,
            totalSourceMeasureCount: metadata.totalSourceMeasureCount
        )
        let measureProgress = SongPracticeMeasureProgress(
            stableSourceMeasureCount: currentFacts.stableSourceMeasureCount,
            learningSourceMeasureCount: currentFacts.learningSourceMeasureCount,
            unpracticedSourceMeasureCount: currentFacts.unpracticedSourceMeasureCount
        )

        return .current(SongPracticeLibrarySnapshot(
            identity: identity,
            status: currentFacts.stableSourceMeasureCount + currentFacts.learningSourceMeasureCount == 0
                ? .currentVersionNotPracticed
                : .practicedCurrentVersion,
            latestPracticeDate: latestPracticeDate,
            totalSourceMeasureCount: metadata.totalSourceMeasureCount,
            measureProgress: .available(measureProgress),
            currentFacts: currentFacts,
            hasHistory: true
        ))
    }

    private nonisolated func deduplicatedProgresses(
        _ progresses: [SongPracticeProgress]
    ) -> [SongPracticeProgress] {
        Dictionary(grouping: progresses, by: \.identity)
            .values
            .compactMap { PracticeProgressRecordOrder.preferred(in: $0) }
    }

    private nonisolated func deriveCurrentFacts(
        _ progress: SongPracticeProgress?,
        totalSourceMeasureCount: Int
    ) -> SongPracticeCurrentFacts {
        let uniqueFacts = SongPracticeMeasureFactOrder.uniqueRealFacts(
            in: progress?.measureFacts ?? []
        )
        let currentFact = uniqueFacts.sorted(by: currentFactComesFirst).first
        let sourceGroups = Dictionary(grouping: uniqueFacts, by: \.sourceMeasureID)
        let stableSourceIDs = Set(sourceGroups.compactMap { sourceID, facts in
            let stableHands = Set(facts.filter { $0.state == .stable }.map(\.handMode))
            return stableHands.contains(.both) || (stableHands.contains(.left) && stableHands.contains(.right))
                ? sourceID
                : nil
        })
        let attemptedSourceIDs = Set(sourceGroups.keys)
        let learningSourceIDs = attemptedSourceIDs.subtracting(stableSourceIDs)
        let stableCount = min(totalSourceMeasureCount, stableSourceIDs.count)
        let learningCount = min(
            max(0, totalSourceMeasureCount - stableCount),
            learningSourceIDs.count
        )
        let unpracticedCount = max(0, totalSourceMeasureCount - stableCount - learningCount)
        let recentIssues = Dictionary(
            grouping: uniqueFacts.filter { $0.recentIssue != nil && $0.lastAttemptAt != nil },
            by: \.sourceMeasureID
        ).values.compactMap { facts -> SongPracticeRecentIssue? in
            guard let fact = preferredFact(facts),
                  let kind = fact.recentIssue,
                  let attemptedAt = fact.lastAttemptAt
            else { return nil }
            return SongPracticeRecentIssue(
                sourceMeasureID: fact.sourceMeasureID,
                kind: kind,
                attemptedAt: attemptedAt
            )
        }.sorted { lhs, rhs in
            if lhs.attemptedAt != rhs.attemptedAt { return lhs.attemptedAt > rhs.attemptedAt }
            return PracticeSourceMeasureOrder.comesFirst(lhs.sourceMeasureID, rhs.sourceMeasureID)
        }

        return SongPracticeCurrentFacts(
            handMode: currentFact?.handMode ?? .both,
            stableSourceMeasureCount: stableCount,
            learningSourceMeasureCount: learningCount,
            unpracticedSourceMeasureCount: unpracticedCount,
            resumeSourceMeasureID: validResumeSourceMeasureID(
                progress: progress,
                currentFacts: uniqueFacts
            ),
            highestStableTempoScale: uniqueFacts
                .filter { $0.state == .stable }
                .compactMap(\.highestStableTempoScale)
                .max(),
            recentIssues: recentIssues
        )
    }

    private nonisolated func validResumeSourceMeasureID(
        progress: SongPracticeProgress?,
        currentFacts: [MeasurePracticeFacts]
    ) -> PracticeSourceMeasureID? {
        guard let source = progress?.resumePoint?.occurrenceID.sourceMeasureID,
              currentFacts.contains(where: { $0.sourceMeasureID == source })
        else { return nil }
        return source
    }

    private nonisolated func preferredFact(
        _ facts: [MeasurePracticeFacts]
    ) -> MeasurePracticeFacts? {
        facts.sorted(by: SongPracticeMeasureFactOrder.comesFirst).first
    }

    private nonisolated func currentFactComesFirst(
        _ lhs: MeasurePracticeFacts,
        _ rhs: MeasurePracticeFacts
    ) -> Bool {
        if lhs.lastAttemptAt != rhs.lastAttemptAt {
            return (lhs.lastAttemptAt ?? .distantPast) > (rhs.lastAttemptAt ?? .distantPast)
        }
        if lhs.sourceMeasureID != rhs.sourceMeasureID {
            return PracticeSourceMeasureOrder.comesFirst(lhs.sourceMeasureID, rhs.sourceMeasureID)
        }
        return lhs.handMode.rawValue < rhs.handMode.rawValue
    }

}
