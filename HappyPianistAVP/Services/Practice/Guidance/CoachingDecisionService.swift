import Foundation

actor CoachingDecisionService {
    private enum Disposition {
        case pending
        case accepted
    }

    private struct TrackedDecision {
        let id: UUID
        let decision: CoachingDecision
        let before: PianoPerformanceCoachingMetricSnapshot
        var disposition: Disposition
    }

    private let exercisePolicy: PracticeExercisePolicy
    private let priorityPolicy: CoachingPriorityPolicy
    private let diagnosticsReporter: (any DiagnosticsReporting)?
    private var trackedDecision: TrackedDecision?

    init(
        exercisePolicy: PracticeExercisePolicy = PracticeExercisePolicy(),
        priorityPolicy: CoachingPriorityPolicy = CoachingPriorityPolicy(),
        diagnosticsReporter: (any DiagnosticsReporting)? = nil
    ) {
        self.exercisePolicy = exercisePolicy
        self.priorityPolicy = priorityPolicy
        self.diagnosticsReporter = diagnosticsReporter
    }

    func decision(
        for assessment: PassagePerformanceAssessment,
        scoreEvents: [ScorePerformanceNoteEvent] = [],
        context: CoachingPriorityContext = CoachingPriorityContext()
    ) async -> CoachingDecision? {
        await remeasureAcceptedDecision(with: assessment)
        let decision = priorityPolicy.primaryDecision(
            from: candidates(for: assessment, scoreEvents: scoreEvents),
            context: context
        )
        if let decision,
           let before = metric(
               in: decision.issue.dimensionResults,
               for: decision.action.completionCondition.target
           )
        {
            let tracked = TrackedDecision(
                id: UUID(),
                decision: decision,
                before: before,
                disposition: .pending
            )
            trackedDecision = tracked
            await report(tracked, outcome: .issued)
        } else {
            trackedDecision = nil
        }
        return decision
    }

    func accept(_ decision: CoachingDecision) async {
        guard var trackedDecision,
              trackedDecision.decision == decision,
              trackedDecision.disposition == .pending
        else { return }
        trackedDecision.disposition = .accepted
        self.trackedDecision = trackedDecision
        await report(trackedDecision, outcome: .accepted)
    }

    func skip(_ decision: CoachingDecision) async {
        guard let trackedDecision,
              trackedDecision.decision == decision,
              trackedDecision.disposition == .pending
        else { return }
        self.trackedDecision = nil
        await report(trackedDecision, outcome: .skipped)
    }

    func candidates(
        for assessment: PassagePerformanceAssessment,
        scoreEvents: [ScorePerformanceNoteEvent] = []
    ) -> [CoachingDecision] {
        issues(from: assessment).compactMap { issue in
            exercisePolicy.action(for: issue, scoreEvents: scoreEvents).map {
                CoachingDecision(issue: issue, action: $0)
            }
        }
    }

    private func issues(from assessment: PassagePerformanceAssessment) -> [MusicalIssue] {
        assessmentScopes(assessment).flatMap { scope in
            issues(
                in: scope.dimensions,
                scoreRange: scope.scoreRange,
                measureOccurrenceIDs: scope.measureOccurrenceIDs,
                provenance: MusicalIssueProvenance(
                    planID: assessment.planID,
                    sourceGeneration: assessment.sourceGeneration,
                    rubricVersion: assessment.rubricVersion
                )
            )
        }
    }

    private func remeasureAcceptedDecision(
        with assessment: PassagePerformanceAssessment
    ) async {
        guard let trackedDecision,
              trackedDecision.disposition == .accepted
        else { return }
        guard assessment.planID == trackedDecision.decision.issue.provenance.planID else {
            self.trackedDecision = nil
            return
        }
        let after = metric(
            in: assessmentDimensions(
                assessment,
                scoreRange: trackedDecision.decision.action.scoreRange
            ),
            for: trackedDecision.decision.action.completionCondition.target
        )
        self.trackedDecision = nil
        await report(
            trackedDecision,
            outcome: .remeasured,
            after: after,
            completionMet: after.map {
                completes(trackedDecision.decision.action.completionCondition.target, with: $0)
            }
        )
    }

    private func assessmentDimensions(
        _ assessment: PassagePerformanceAssessment,
        scoreRange: Range<Int>
    ) -> [PerformanceAssessmentDimensionResult] {
        let measureDimensions = assessment.measures
            .filter { $0.tickRange == scoreRange }
            .flatMap(\.dimensions)
        if measureDimensions.isEmpty == false {
            return measureDimensions
        }
        return assessment.tickRange == scoreRange ? assessment.dimensions : []
    }

    private func metric(
        in dimensions: [PerformanceAssessmentDimensionResult],
        for target: CoachingCompletionTarget
    ) -> PianoPerformanceCoachingMetricSnapshot? {
        let targetDimension = switch target {
        case let .dimensionOutcome(dimension, _), let .evidenceAvailable(dimension):
            dimension
        }
        return dimensions.first { $0.dimension == targetDimension }
            .map(PianoPerformanceCoachingMetricSnapshot.init)
    }

    private func completes(
        _ target: CoachingCompletionTarget,
        with metric: PianoPerformanceCoachingMetricSnapshot
    ) -> Bool {
        switch target {
        case let .dimensionOutcome(_, outcome):
            metric.outcome == outcome
        case .evidenceAvailable:
            metric.evidenceStatus == .observed || metric.evidenceStatus == .degraded
        }
    }

    private func report(
        _ trackedDecision: TrackedDecision,
        outcome: PianoPerformanceCoachingDiagnosticOutcome,
        after: PianoPerformanceCoachingMetricSnapshot? = nil,
        completionMet: Bool? = nil
    ) async {
        guard let diagnosticsReporter else { return }
        _ = await diagnosticsReporter.record(PianoPerformanceCoachingDiagnosticSample(
            decisionID: trackedDecision.id,
            outcome: outcome,
            issueKind: trackedDecision.decision.issue.kind,
            confidenceBucket: PianoPerformanceConfidenceBucket(
                trackedDecision.decision.issue.confidence
            ),
            actionKind: trackedDecision.decision.action.kind,
            before: trackedDecision.before,
            after: after,
            completionMet: completionMet
        ).diagnosticEvent)
    }

    private func assessmentScopes(
        _ assessment: PassagePerformanceAssessment
    ) -> [(
        scoreRange: Range<Int>,
        measureOccurrenceIDs: [PracticeMeasureOccurrenceID],
        dimensions: [PerformanceAssessmentDimensionResult]
    )] {
        guard assessment.measures.isEmpty == false else {
            return [(assessment.tickRange, [], assessment.dimensions)]
        }
        return Dictionary(grouping: assessment.measures, by: \.tickRange)
            .map { range, measures in
                (
                    range,
                    measures.map(\.occurrenceID).sorted(by: Self.occurrenceOrder),
                    measures.flatMap(\.dimensions)
                )
            }
            .sorted { lhs, rhs in
                if lhs.0.lowerBound != rhs.0.lowerBound {
                    return lhs.0.lowerBound < rhs.0.lowerBound
                }
                return lhs.0.upperBound < rhs.0.upperBound
            }
    }

    private func issues(
        in dimensions: [PerformanceAssessmentDimensionResult],
        scoreRange: Range<Int>,
        measureOccurrenceIDs: [PracticeMeasureOccurrenceID],
        provenance: MusicalIssueProvenance
    ) -> [MusicalIssue] {
        var orderedKinds: [MusicalIssueKind] = []
        var resultsByKind: [MusicalIssueKind: [PerformanceAssessmentDimensionResult]] = [:]

        for result in dimensions {
            let kind: MusicalIssueKind
            switch result.outcome {
            case .correct:
                continue
            case .incorrect:
                kind = result.dimension.musicalIssueKind
            case .unknown, .insufficientEvidence:
                kind = .evidence
            }
            if resultsByKind[kind] == nil {
                orderedKinds.append(kind)
            }
            resultsByKind[kind, default: []].append(result)
        }

        return orderedKinds.compactMap { kind in
            guard let results = resultsByKind[kind], results.isEmpty == false else { return nil }
            let confidenceValues = results.compactMap(\.confidence)
            let confidence = confidenceValues.count == results.count ? confidenceValues.min() : nil
            return MusicalIssue(
                kind: kind,
                scoreRange: scoreRange,
                measureOccurrenceIDs: measureOccurrenceIDs,
                dimensionResults: results,
                confidence: confidence,
                provenance: provenance
            )
        }
    }

    private static func occurrenceOrder(
        _ lhs: PracticeMeasureOccurrenceID,
        _ rhs: PracticeMeasureOccurrenceID
    ) -> Bool {
        if lhs.occurrenceIndex != rhs.occurrenceIndex {
            return lhs.occurrenceIndex < rhs.occurrenceIndex
        }
        if lhs.sourceMeasureID.partID != rhs.sourceMeasureID.partID {
            return lhs.sourceMeasureID.partID < rhs.sourceMeasureID.partID
        }
        return lhs.sourceMeasureID.sourceMeasureIndex < rhs.sourceMeasureID.sourceMeasureIndex
    }
}
