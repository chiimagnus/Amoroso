import Foundation

struct IncrementalPerformanceAligner: Sendable {
    enum State: Equatable, Sendable {
        case idle
        case running
        case finished
    }

    struct Configuration: Equatable, Sendable {
        let maximumBufferedObservations: Int
        let commitHorizonSeconds: TimeInterval

        init(maximumBufferedObservations: Int = 4_096, commitHorizonSeconds: TimeInterval = 0.3) {
            self.maximumBufferedObservations = max(32, maximumBufferedObservations)
            self.commitHorizonSeconds = commitHorizonSeconds.isFinite
                ? max(0, commitHorizonSeconds)
                : 0.3
        }
    }

    private let engine: PerformanceAlignmentEngine
    private let configuration: Configuration
    private(set) var state: State = .idle
    private var plan: ScorePerformancePlan?
    private var generation: UInt64 = 0
    private var performanceStart = PerformanceMonotonicInstant(seconds: 0)
    private var activeTickRange: Range<Int>?
    private var observations: [PerformanceObservation] = []
    private var lastTimestamp: PerformanceMonotonicInstant?
    private var committedLinks: [ScorePerformanceNoteEventID: PerformanceAlignmentLink] = [:]

    init(
        engine: PerformanceAlignmentEngine = .init(),
        configuration: Configuration = .init()
    ) {
        self.engine = engine
        self.configuration = configuration
    }

    mutating func start(
        plan: ScorePerformancePlan,
        generation: UInt64,
        performanceStart: PerformanceMonotonicInstant,
        activeTickRange: Range<Int>? = nil
    ) {
        reset()
        self.plan = plan
        self.generation = generation
        self.performanceStart = performanceStart
        self.activeTickRange = activeTickRange
        state = .running
    }

    mutating func append(_ observation: PerformanceObservation) -> PerformanceAlignment? {
        guard state == .running,
              observation.source.generation == generation,
              observation.source.role != .systemPlayback,
              lastTimestamp.map({ observation.alignmentTimestamp >= $0 }) ?? true
        else {
            return nil
        }
        observations.append(observation)
        lastTimestamp = observation.alignmentTimestamp
        let snapshot = liveSnapshot()
        commitMatureLinks(from: snapshot, now: observation.alignmentTimestamp)
        trimBuffer()
        return liveSnapshot()
    }

    mutating func seek(to performanceStart: PerformanceMonotonicInstant) {
        guard state == .running else { return }
        self.performanceStart = performanceStart
        clearRunEvidence()
    }

    mutating func rangeChange(_ range: Range<Int>?) {
        guard state == .running else { return }
        activeTickRange = range
        clearRunEvidence()
    }

    mutating func finish() -> PerformanceAlignment? {
        guard state == .running, let plan else { return nil }
        let final = engine.align(
            plan: plan,
            observations: observations,
            performanceStart: performanceStart,
            activeTickRange: activeTickRange,
            generation: generation
        )
        state = .finished
        return mergingCommitted(into: final, includeMissing: true)
    }

    mutating func reset() {
        state = .idle
        plan = nil
        generation = 0
        performanceStart = .init(seconds: 0)
        activeTickRange = nil
        clearRunEvidence()
    }

    private func liveSnapshot() -> PerformanceAlignment? {
        guard let plan else { return nil }
        let alignment = engine.align(
            plan: plan,
            observations: observations,
            performanceStart: performanceStart,
            activeTickRange: activeTickRange,
            generation: generation
        )
        return mergingCommitted(into: provisionalizing(alignment), includeMissing: false)
    }

    private func provisionalizing(_ alignment: PerformanceAlignment) -> PerformanceAlignment {
        let horizon = (lastTimestamp?.seconds ?? 0) - configuration.commitHorizonSeconds
        let links = alignment.links.map { link -> PerformanceAlignmentLink in
            guard case let .aligned(score, observation, evidence) = link,
                  observation.correctedTime.seconds > horizon
            else { return link }
            return .provisional(
                score: score,
                observation: observation,
                candidates: [.init(
                    score: score,
                    totalCost: evidence.compactMap(\.cost).reduce(0, +),
                    evidence: evidence
                )]
            )
        }
        return PerformanceAlignment(
            planID: alignment.planID,
            sourceGeneration: alignment.sourceGeneration,
            links: links,
            controllerLinks: alignment.controllerLinks
        )
    }

    private func mergingCommitted(
        into alignment: PerformanceAlignment,
        includeMissing: Bool
    ) -> PerformanceAlignment {
        let live = alignment.links.filter { link in
            if includeMissing == false, case .missing = link { return false }
            guard let eventID = link.scoreEventID else { return true }
            return committedLinks[eventID] == nil
        }
        return PerformanceAlignment(
            planID: alignment.planID,
            sourceGeneration: alignment.sourceGeneration,
            links: committedLinks.values.sorted(by: Self.linkOrder) + live,
            controllerLinks: alignment.controllerLinks
        )
    }

    private mutating func commitMatureLinks(
        from alignment: PerformanceAlignment?,
        now: PerformanceMonotonicInstant
    ) {
        guard let alignment else { return }
        let horizon = now.seconds - configuration.commitHorizonSeconds
        for link in alignment.links {
            guard case let .aligned(score, observation, _) = link,
                  observation.correctedTime.seconds <= horizon
            else { continue }
            committedLinks[score.eventID] = link
        }
    }

    private mutating func trimBuffer() {
        guard observations.count > configuration.maximumBufferedObservations else { return }
        // ponytail: bounded replay window; retain an explicit open-note registry if >4096 events per commit horizon becomes real.
        observations.removeFirst(observations.count - configuration.maximumBufferedObservations)
    }

    private mutating func clearRunEvidence() {
        observations.removeAll(keepingCapacity: true)
        lastTimestamp = nil
        committedLinks.removeAll(keepingCapacity: true)
    }

    private static func linkOrder(_ lhs: PerformanceAlignmentLink, _ rhs: PerformanceAlignmentLink) -> Bool {
        (lhs.scoreEventID?.description ?? "") < (rhs.scoreEventID?.description ?? "")
    }
}

private extension PerformanceAlignmentLink {
    var scoreEventID: ScorePerformanceNoteEventID? {
        switch self {
        case let .aligned(score, _, _),
             let .missing(score, _),
             let .provisional(score, _, _):
            score.eventID
        case .extra, .ambiguous, .unknown:
            nil
        }
    }
}
