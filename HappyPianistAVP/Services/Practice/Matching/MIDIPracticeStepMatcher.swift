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
            return .insufficientEvidence
        }

        pruneRearm(now: timestamp)
        guard isRearmSatisfied(note: note, at: timestamp) else {
            return .insufficientEvidence
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
            return .wrongNote
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
            return .matched
        }

        return .insufficientEvidence
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
