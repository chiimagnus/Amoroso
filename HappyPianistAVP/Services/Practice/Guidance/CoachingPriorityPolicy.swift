import Foundation

struct CoachingDecisionSignature: Equatable, Hashable, Sendable {
    let actionKind: CoachingActionKind
    let scoreRange: Range<Int>

    init(_ decision: CoachingDecision) {
        actionKind = decision.action.kind
        scoreRange = decision.action.scoreRange
    }
}

struct CoachingPriorityContext: Equatable, Sendable {
    let skippedDecisions: Set<CoachingDecisionSignature>
    let previousDecision: CoachingDecision?
    let consecutiveUnimprovedAssessments: Int

    init(
        skippedDecisions: Set<CoachingDecisionSignature> = [],
        previousDecision: CoachingDecision? = nil,
        consecutiveUnimprovedAssessments: Int = 0
    ) {
        self.skippedDecisions = skippedDecisions
        self.previousDecision = previousDecision
        self.consecutiveUnimprovedAssessments = max(0, consecutiveUnimprovedAssessments)
    }
}

struct CoachingPriorityPolicy: Sendable {
    private let maximumUnimprovedAssessments = 2

    func primaryDecision(
        from candidates: [CoachingDecision],
        context: CoachingPriorityContext = CoachingPriorityContext()
    ) -> CoachingDecision? {
        var eligible = candidates.filter {
            context.skippedDecisions.contains(CoachingDecisionSignature($0)) == false
        }
        if context.consecutiveUnimprovedAssessments >= maximumUnimprovedAssessments,
           let previousDecision = context.previousDecision
        {
            let previousSignature = CoachingDecisionSignature(previousDecision)
            eligible.removeAll { CoachingDecisionSignature($0) == previousSignature }
        }
        guard eligible.isEmpty == false else { return nil }

        let evidencePrerequisites = eligible.filter { $0.issue.kind == .evidence }
        if let evidenceDecision = ordered(evidencePrerequisites).first {
            return evidenceDecision
        }

        if context.consecutiveUnimprovedAssessments < maximumUnimprovedAssessments,
           let previousDecision = context.previousDecision,
           let continuingDecision = eligible.first(where: {
               CoachingDecisionSignature($0) == CoachingDecisionSignature(previousDecision)
           })
        {
            return continuingDecision
        }

        // ponytail: emit one primary action; add combinations only with an explicit shared-range prerequisite.
        return ordered(eligible).first
    }

    private func ordered(_ candidates: [CoachingDecision]) -> [CoachingDecision] {
        candidates.sorted { lhs, rhs in
            let lhsSeverity = severity(of: lhs.issue.kind)
            let rhsSeverity = severity(of: rhs.issue.kind)
            if lhsSeverity != rhsSeverity { return lhsSeverity > rhsSeverity }

            let lhsConfidence = lhs.issue.confidence ?? -1
            let rhsConfidence = rhs.issue.confidence ?? -1
            if lhsConfidence != rhsConfidence { return lhsConfidence > rhsConfidence }

            let lhsCoverage = evidenceCoverage(of: lhs.issue)
            let rhsCoverage = evidenceCoverage(of: rhs.issue)
            if lhsCoverage != rhsCoverage { return lhsCoverage > rhsCoverage }

            let lhsActionability = actionability(of: lhs)
            let rhsActionability = actionability(of: rhs)
            if lhsActionability != rhsActionability { return lhsActionability > rhsActionability }

            if lhs.action.scoreRange.lowerBound != rhs.action.scoreRange.lowerBound {
                return lhs.action.scoreRange.lowerBound < rhs.action.scoreRange.lowerBound
            }
            if lhs.action.scoreRange.upperBound != rhs.action.scoreRange.upperBound {
                return lhs.action.scoreRange.upperBound < rhs.action.scoreRange.upperBound
            }
            return lhs.action.kind.rawValue < rhs.action.kind.rawValue
        }
    }

    private func severity(of kind: MusicalIssueKind) -> Int {
        switch kind {
        case .pitch: 10
        case .onset, .chordSpread: 9
        case .tempo: 8
        case .duration, .articulation: 7
        case .voicing, .dynamicContour: 6
        case .pedal: 5
        case .phrase: 4
        case .evidence: 0
        }
    }

    private func evidenceCoverage(of issue: MusicalIssue) -> Double {
        guard issue.dimensionResults.isEmpty == false else { return 0 }
        let total: Double = issue.dimensionResults.map { result -> Double in
            switch result.evidenceStatus {
            case .observed: 1.0
            case .degraded: 0.5
            case .notObserved, .insufficient: 0
            }
        }.reduce(0, +)
        return total / Double(issue.dimensionResults.count)
    }

    private func actionability(of decision: CoachingDecision) -> Int {
        guard decision.action.scoreRange.isEmpty == false else { return 0 }
        let dimension = switch decision.action.completionCondition.target {
        case let .dimensionOutcome(dimension, _), let .evidenceAvailable(dimension):
            dimension
        }
        return decision.issue.dimensionResults.contains { $0.dimension == dimension } ? 1 : 0
    }
}
