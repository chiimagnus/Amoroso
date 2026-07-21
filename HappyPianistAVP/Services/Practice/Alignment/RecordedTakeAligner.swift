import Foundation

struct RecordedTakeAligner: Sendable {
    private let engine: PerformanceAlignmentEngine

    init(engine: PerformanceAlignmentEngine = .init()) {
        self.engine = engine
    }

    func candidateSnapshots(
        take: RecordingTake,
        plan: ScorePerformancePlan,
        activeTickRange: Range<Int>? = nil
    ) -> [PerformanceAlignmentCandidateSnapshot] {
        let observations = take.alignmentObservations()
        return engine.candidates(
            plan: plan,
            observations: observations,
            performanceStart: .init(seconds: 0),
            activeTickRange: activeTickRange
        )
    }

    func align(
        take: RecordingTake,
        plan: ScorePerformancePlan,
        activeTickRange: Range<Int>? = nil
    ) -> PerformanceAlignment {
        var incremental = IncrementalPerformanceAligner(engine: engine)
        incremental.start(
            plan: plan,
            generation: take.alignmentObservations().first?.source.generation ?? 0,
            performanceStart: .init(seconds: 0),
            activeTickRange: activeTickRange
        )
        for observation in take.alignmentObservations() {
            _ = incremental.append(observation)
        }
        return incremental.finish() ?? PerformanceAlignment(
            planID: plan.id,
            sourceGeneration: 0,
            links: []
        )
    }
}
