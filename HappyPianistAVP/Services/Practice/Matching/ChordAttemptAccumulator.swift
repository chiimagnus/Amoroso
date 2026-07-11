import Foundation

protocol ChordAttemptAccumulatorProtocol {
    func register(
        pressedNotes: Set<Int>,
        expectedNotes: [Int],
        tolerance: Int,
        at timestamp: Date
    ) -> StepAttemptMatchResult

    func registerHandSeparated(
        pressedNotes: Set<Int>,
        expectedRightNotes: [Int],
        expectedLeftNotes: [Int],
        tolerance: Int,
        at timestamp: Date
    ) -> StepAttemptMatchResult
    func reset()
}

extension ChordAttemptAccumulatorProtocol {
    func registerHandSeparated(
        pressedNotes: Set<Int>,
        expectedRightNotes: [Int],
        expectedLeftNotes: [Int],
        tolerance: Int,
        at timestamp: Date
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
    private let windowSeconds: TimeInterval
    private let matcher: StepMatcherProtocol

    private var windowStart: Date?
    private var accumulatedPressedNotes: Set<Int> = []

    init(windowSeconds: TimeInterval = 0.6, matcher: StepMatcherProtocol = StepMatcher()) {
        self.windowSeconds = windowSeconds
        self.matcher = matcher
    }

    func register(
        pressedNotes: Set<Int>,
        expectedNotes: [Int],
        tolerance: Int,
        at timestamp: Date
    ) -> StepAttemptMatchResult {
        registerHandSeparated(
            pressedNotes: pressedNotes,
            expectedRightNotes: expectedNotes,
            expectedLeftNotes: [],
            tolerance: tolerance,
            at: timestamp
        )
    }

    func registerHandSeparated(
        pressedNotes: Set<Int>,
        expectedRightNotes: [Int],
        expectedLeftNotes: [Int],
        tolerance: Int,
        at timestamp: Date
    ) -> StepAttemptMatchResult {
        let expectedUnion = Set(expectedRightNotes + expectedLeftNotes)
        let handMode: PracticeHandMode = if expectedRightNotes.isEmpty {
            .left
        } else if expectedLeftNotes.isEmpty {
            .right
        } else {
            .both
        }

        guard pressedNotes.isEmpty == false, expectedUnion.isEmpty == false else {
            return .insufficientEvidence(evidence: evidence(
                expected: expectedUnion,
                observed: accumulatedPressedNotes,
                handMode: handMode,
                message: "no contact evidence"
            ))
        }

        if let windowStart, timestamp.timeIntervalSince(windowStart) > windowSeconds {
            reset()
        }
        if windowStart == nil { windowStart = timestamp }
        accumulatedPressedNotes.formUnion(pressedNotes)

        let rightMatched = expectedRightNotes.isEmpty || matcher.matches(
            expectedNotes: expectedRightNotes,
            pressedNotes: accumulatedPressedNotes,
            tolerance: tolerance
        )
        let leftMatched = expectedLeftNotes.isEmpty || matcher.matches(
            expectedNotes: expectedLeftNotes,
            pressedNotes: accumulatedPressedNotes,
            tolerance: tolerance
        )

        let currentEvidence = evidence(
            expected: expectedUnion,
            observed: accumulatedPressedNotes,
            handMode: handMode,
            message: rightMatched && leftMatched ? "hand contact matched" : "hand contact pending"
        )
        if rightMatched, leftMatched {
            reset()
            return .matched(evidence: currentEvidence)
        }
        return .insufficientEvidence(evidence: currentEvidence)
    }

    func reset() {
        windowStart = nil
        accumulatedPressedNotes.removeAll()
    }

    private func evidence(
        expected: Set<Int>,
        observed: Set<Int>,
        handMode: PracticeHandMode,
        message: String
    ) -> PracticeAttemptEvidence {
        PracticeAttemptEvidence(
            expectedNotes: expected,
            observedNotes: observed,
            handMode: handMode,
            source: .handContact,
            isPartialEvidence: false,
            debugMessage: message
        )
    }
}
