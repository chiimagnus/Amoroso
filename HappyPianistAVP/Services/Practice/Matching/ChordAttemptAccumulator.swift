import Foundation

enum ChordOnsetExpectation: Equatable {
    case simultaneous
    case rolled
}

protocol ChordAttemptAccumulatorProtocol {
    func register(
        pressedNotes: Set<Int>,
        expectedNotes: [Int],
        tolerance: Int,
        at timestamp: PerformanceMonotonicInstant
    ) -> StepAttemptMatchResult

    func registerHandSeparated(
        pressedNotes: Set<Int>,
        expectedRightNotes: [Int],
        expectedLeftNotes: [Int],
        tolerance: Int,
        at timestamp: PerformanceMonotonicInstant
    ) -> StepAttemptMatchResult
    func reset()
}

extension ChordAttemptAccumulatorProtocol {
    func registerHandSeparated(
        pressedNotes: Set<Int>,
        expectedRightNotes: [Int],
        expectedLeftNotes: [Int],
        tolerance: Int,
        at timestamp: PerformanceMonotonicInstant
    ) -> StepAttemptMatchResult {
        register(
            pressedNotes: pressedNotes,
            expectedNotes: Set(expectedRightNotes + expectedLeftNotes).sorted(),
            tolerance: tolerance,
            at: timestamp
        )
    }
}

final class ChordAttemptAccumulator: ChordAttemptAccumulatorProtocol {
    private let simultaneousSpreadSeconds: TimeInterval
    private let rolledSpanSeconds: TimeInterval
    private let matcher: StepMatcherProtocol

    private var onsetByNote: [Int: PerformanceMonotonicInstant] = [:]

    init(
        windowSeconds: TimeInterval = 0.6,
        simultaneousSpreadSeconds: TimeInterval = 0.08,
        matcher: StepMatcherProtocol = StepMatcher()
    ) {
        rolledSpanSeconds = max(0, windowSeconds)
        self.simultaneousSpreadSeconds = max(0, simultaneousSpreadSeconds)
        self.matcher = matcher
    }

    func register(
        pressedNotes: Set<Int>,
        expectedNotes: [Int],
        tolerance: Int,
        at timestamp: PerformanceMonotonicInstant
    ) -> StepAttemptMatchResult {
        registerHandSeparated(
            pressedNotes: pressedNotes,
            expectedRightNotes: expectedNotes,
            expectedLeftNotes: [],
            tolerance: tolerance,
            onsetExpectation: .rolled,
            at: timestamp
        )
    }

    func registerHandSeparated(
        pressedNotes: Set<Int>,
        expectedRightNotes: [Int],
        expectedLeftNotes: [Int],
        tolerance: Int,
        at timestamp: PerformanceMonotonicInstant
    ) -> StepAttemptMatchResult {
        registerHandSeparated(
            pressedNotes: pressedNotes,
            expectedRightNotes: expectedRightNotes,
            expectedLeftNotes: expectedLeftNotes,
            tolerance: tolerance,
            onsetExpectation: .rolled,
            at: timestamp
        )
    }

    func registerHandSeparated(
        pressedNotes: Set<Int>,
        expectedRightNotes: [Int],
        expectedLeftNotes: [Int],
        tolerance: Int,
        onsetExpectation: ChordOnsetExpectation,
        at timestamp: PerformanceMonotonicInstant
    ) -> StepAttemptMatchResult {
        let expectedUnion = Set(expectedRightNotes + expectedLeftNotes)
        guard pressedNotes.isEmpty == false, expectedUnion.isEmpty == false else {
            return .insufficientEvidence
        }

        if let firstOnset = onsetByNote.values.min(),
           timestamp < firstOnset || timestamp.seconds - firstOnset.seconds > maximumSpan(for: onsetExpectation)
        {
            reset()
        }
        for note in pressedNotes where onsetByNote[note] == nil {
            onsetByNote[note] = timestamp
        }

        let observedNotes = Set(onsetByNote.keys)
        let rightMatched = expectedRightNotes.isEmpty || matcher.matches(
            expectedNotes: expectedRightNotes,
            pressedNotes: observedNotes,
            tolerance: tolerance
        )
        let leftMatched = expectedLeftNotes.isEmpty || matcher.matches(
            expectedNotes: expectedLeftNotes,
            pressedNotes: observedNotes,
            tolerance: tolerance
        )

        guard rightMatched, leftMatched else { return .insufficientEvidence }
        guard onsetSpread <= maximumSpan(for: onsetExpectation) else {
            reset(keeping: pressedNotes, at: timestamp)
            return .insufficientEvidence
        }

        reset()
        return .matched
    }

    func reset() {
        onsetByNote.removeAll(keepingCapacity: true)
    }

    private var onsetSpread: TimeInterval {
        guard let first = onsetByNote.values.min(), let last = onsetByNote.values.max() else { return 0 }
        return last.seconds - first.seconds
    }

    private func maximumSpan(for expectation: ChordOnsetExpectation) -> TimeInterval {
        switch expectation {
        case .simultaneous:
            simultaneousSpreadSeconds
        case .rolled:
            rolledSpanSeconds
        }
    }

    private func reset(keeping notes: Set<Int>, at timestamp: PerformanceMonotonicInstant) {
        reset()
        for note in notes {
            onsetByNote[note] = timestamp
        }
    }
}
