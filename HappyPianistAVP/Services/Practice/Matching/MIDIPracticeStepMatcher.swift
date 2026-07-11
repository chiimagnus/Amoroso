import Foundation

@MainActor
protocol MIDIPracticeStepMatchingProtocol: AnyObject {
    func reset(stepIndex: Int, expectedNotes: [PracticeStepNote], configuredAt now: Date)
    func registerNoteOn(note: Int, at timestamp: Date) -> StepAttemptMatchResult
    func registerNoteOff(note: Int, at timestamp: Date)
}

@MainActor
final class MIDIPracticeStepMatcher: MIDIPracticeStepMatchingProtocol {
    struct Configuration: Equatable {
        var chordWindow: TimeInterval = 0.55
        var rearmSilenceWindow: TimeInterval = 0.08
        var noteOffRequired: Bool = false
    }

    private(set) var configuration: Configuration

    private var stepIndex: Int = -1
    private var expectedRight: Set<Int> = []
    private var expectedLeft: Set<Int> = []
    private var expectedUnion: Set<Int> = []
    private var windowStart: Date?
    private var accumulatedNotes: Set<Int> = []
    private var rearmBlockedUntil: [Int: Date] = [:]

    init(configuration: Configuration = .init()) {
        self.configuration = configuration
    }

    func reset(stepIndex: Int, expectedNotes: [PracticeStepNote], configuredAt now: Date) {
        self.stepIndex = stepIndex
        expectedRight.removeAll(keepingCapacity: true)
        expectedLeft.removeAll(keepingCapacity: true)

        for note in expectedNotes {
            if note.hand == .left {
                expectedLeft.insert(note.midiNote)
            } else {
                expectedRight.insert(note.midiNote)
            }
        }
        expectedUnion = expectedRight.union(expectedLeft)
        windowStart = nil
        accumulatedNotes.removeAll(keepingCapacity: true)
        rearmBlockedUntil.removeAll(keepingCapacity: true)
        pruneRearm(now: now)
    }

    func registerNoteOn(note: Int, at timestamp: Date) -> StepAttemptMatchResult {
        guard expectedUnion.isEmpty == false else {
            return .insufficientEvidence(evidence: evidence(observed: [], message: "no expected notes"))
        }

        pruneRearm(now: timestamp)
        guard isRearmSatisfied(note: note, at: timestamp) else {
            return .insufficientEvidence(evidence: evidence(observed: accumulatedNotes, message: "rearm blocked"))
        }

        if windowStart == nil {
            windowStart = timestamp
            accumulatedNotes.removeAll(keepingCapacity: true)
        }

        if let windowStart, timestamp.timeIntervalSince(windowStart) > configuration.chordWindow {
            self.windowStart = timestamp
            accumulatedNotes.removeAll(keepingCapacity: true)
        }

        guard expectedUnion.contains(note) else {
            let observed = accumulatedNotes.union([note])
            return .wrongNote(
                evidence: evidence(observed: observed, message: "unexpected note"),
                unexpectedNotes: [note]
            )
        }

        accumulatedNotes.insert(note)
        return evaluate(at: timestamp)
    }

    func registerNoteOff(note: Int, at timestamp: Date) {
        guard configuration.noteOffRequired else { return }
        rearmBlockedUntil[note] = timestamp.addingTimeInterval(configuration.rearmSilenceWindow)
    }

    private func evaluate(at timestamp: Date) -> StepAttemptMatchResult {
        let rightSatisfied = expectedRight.isSubset(of: accumulatedNotes)
        let leftSatisfied = expectedLeft.isSubset(of: accumulatedNotes)

        if rightSatisfied, leftSatisfied {
            for note in expectedUnion {
                rearmBlockedUntil[note] = timestamp.addingTimeInterval(configuration.rearmSilenceWindow)
            }
            return .matched(evidence: evidence(observed: accumulatedNotes, message: "midi deterministic matched"))
        }

        return .insufficientEvidence(
            evidence: evidence(
                observed: accumulatedNotes,
                message: "pending \(accumulatedNotes.count)/\(expectedUnion.count)"
            )
        )
    }

    private func evidence(observed: Set<Int>, message: String) -> PracticeAttemptEvidence {
        PracticeAttemptEvidence(
            expectedNotes: expectedUnion,
            observedNotes: observed,
            handMode: handMode,
            source: .midi,
            isPartialEvidence: false,
            debugMessage: message
        )
    }

    private var handMode: PracticeHandMode {
        if expectedRight.isEmpty == false, expectedLeft.isEmpty == false { return .both }
        if expectedLeft.isEmpty == false { return .left }
        return .right
    }

    private func isRearmSatisfied(note: Int, at timestamp: Date) -> Bool {
        guard let blockedUntil = rearmBlockedUntil[note] else { return true }
        return timestamp >= blockedUntil
    }

    private func pruneRearm(now: Date) {
        rearmBlockedUntil = rearmBlockedUntil.filter { _, blockedUntil in
            blockedUntil > now
        }
    }
}
