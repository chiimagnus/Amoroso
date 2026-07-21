import Foundation

struct PerformanceAlignmentConfiguration: Equatable, Sendable {
    let candidateWindowSeconds: TimeInterval

    init(candidateWindowSeconds: TimeInterval = 1.5) {
        self.candidateWindowSeconds = candidateWindowSeconds.isFinite
            ? max(0.01, candidateWindowSeconds)
            : 1.5
    }
}

struct PerformanceAlignmentEngine: Sendable {
    private let configuration: PerformanceAlignmentConfiguration

    init(configuration: PerformanceAlignmentConfiguration = .init()) {
        self.configuration = configuration
    }

    func candidates(
        plan: ScorePerformancePlan,
        observations: [PerformanceObservation],
        performanceStart: PerformanceMonotonicInstant,
        activeTickRange: Range<Int>? = nil,
        generation: UInt64? = nil
    ) -> [PerformanceAlignmentCandidateSnapshot] {
        let timeMap = PlanTimeMap(plan: plan)
        return observations.map { observation in
            candidateSnapshot(
                for: observation,
                plan: plan,
                timeMap: timeMap,
                performanceStart: performanceStart,
                activeTickRange: activeTickRange,
                generation: generation
            )
        }
    }

    private func candidateSnapshot(
        for observation: PerformanceObservation,
        plan: ScorePerformancePlan,
        timeMap: PlanTimeMap,
        performanceStart: PerformanceMonotonicInstant,
        activeTickRange: Range<Int>?,
        generation: UInt64?
    ) -> PerformanceAlignmentCandidateSnapshot {
        let reference = PerformanceAlignmentObservationReference(observation: observation)
        if let generation, observation.source.generation != generation {
            return .init(observation: reference, candidates: [], noCandidateReason: .staleGeneration)
        }
        guard case let .noteOn(observedNote, _) = observation.event else {
            return .init(observation: reference, candidates: [], noCandidateReason: .unsupportedObservation)
        }

        let activeNotes = plan.noteEvents.filter { event in
            activeTickRange?.contains(event.performedOnTick) ?? true
        }
        guard activeNotes.isEmpty == false else {
            return .init(observation: reference, candidates: [], noCandidateReason: .outsideActiveRange)
        }

        let observedSeconds = max(0, observation.alignmentTimestamp.seconds - performanceStart.seconds)
        let temporal = activeNotes.filter { event in
            abs(timeMap.seconds(at: event.performedOnTick) - observedSeconds)
                <= configuration.candidateWindowSeconds
        }
        guard temporal.isEmpty == false else {
            return .init(observation: reference, candidates: [], noCandidateReason: .noTemporalCandidate)
        }

        let pitchEvidence = observation.source.capabilities.pitch
        let matching = pitchEvidence == .observed
            ? temporal.filter { $0.midiNote == observedNote }
            : temporal
        guard matching.isEmpty == false else {
            return .init(observation: reference, candidates: [], noCandidateReason: .noPitchCandidate)
        }

        let candidates = matching.map { event in
            let onsetDeviation = observedSeconds - timeMap.seconds(at: event.performedOnTick)
            return PerformanceAlignmentCandidate(
                score: .init(event: event),
                totalCost: abs(onsetDeviation),
                evidence: [
                    .init(
                        dimension: .pitch,
                        status: Self.evidenceStatus(pitchEvidence),
                        cost: event.midiNote == observedNote ? 0 : 1
                    ),
                    .init(
                        dimension: .onset,
                        status: Self.evidenceStatus(observation.source.capabilities.onset),
                        cost: abs(onsetDeviation),
                        deviationSeconds: onsetDeviation
                    ),
                ]
            )
        }.sorted { lhs, rhs in
            if lhs.totalCost != rhs.totalCost { return lhs.totalCost < rhs.totalCost }
            return lhs.score.eventID.description < rhs.score.eventID.description
        }
        return .init(observation: reference, candidates: candidates, noCandidateReason: nil)
    }

    private static func evidenceStatus(
        _ evidence: PerformanceInputCapabilities.Evidence
    ) -> PerformanceAlignmentEvidenceStatus {
        switch evidence {
        case .observed: .observed
        case .degraded: .degraded
        case .unavailable: .notObserved
        }
    }
}

private struct PlanTimeMap: Sendable {
    private let scale: Double
    private let map: MusicXMLTempoMap

    init(plan: ScorePerformancePlan) {
        let resolution = max(1, plan.resolution.ticksPerQuarter)
        let tickScale = Double(MusicXMLTempoMap.ticksPerQuarter) / Double(resolution)
        scale = tickScale
        map = MusicXMLTempoMap(performanceEvents: plan.tempoEvents.map { event in
            ScorePerformanceTempoEvent(
                sourceDirectionID: event.sourceDirectionID,
                performedOccurrenceIndex: event.performedOccurrenceIndex,
                tick: Self.scaled(event.tick, by: tickScale),
                quarterBPM: event.quarterBPM,
                endTick: event.endTick.map { Self.scaled($0, by: tickScale) },
                endQuarterBPM: event.endQuarterBPM
            )
        })
    }

    func seconds(at tick: Int) -> TimeInterval {
        map.timeSeconds(atTick: Self.scaled(tick, by: scale))
    }

    private static func scaled(_ tick: Int, by scale: Double) -> Int {
        let value = Double(max(0, tick)) * scale
        return value >= Double(Int.max) ? .max : Int(value.rounded())
    }
}
