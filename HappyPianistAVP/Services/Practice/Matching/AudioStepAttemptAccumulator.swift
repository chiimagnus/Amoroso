import Foundation
import os

enum Step3AudioRecognitionMode: String, CaseIterable {
    case lowLatency
    case stricter
}

struct AudioStepAttemptAccumulatorConfiguration: Equatable {
    var singleNoteThreshold: Double = 0.60
    var handBoostedThreshold: Double = 0.50
    var wrongNoteThreshold: Double = 0.72
    var wrongDominanceRatio: Double = 1.25
    var onsetThreshold: Double = 0.35
    var aggregationWindow: TimeInterval = 0.25
    var eventTTL: TimeInterval = 0.35
    var rearmSilenceWindow: TimeInterval = 0.12
    var wrongNoteGraceWindow: TimeInterval = 0.16

    static func configuration(for mode: Step3AudioRecognitionMode) -> AudioStepAttemptAccumulatorConfiguration {
        switch mode {
        case .lowLatency:
            AudioStepAttemptAccumulatorConfiguration(
                singleNoteThreshold: 0.55,
                handBoostedThreshold: 0.46,
                wrongNoteThreshold: 0.70,
                wrongDominanceRatio: 1.20,
                onsetThreshold: 0.32,
                aggregationWindow: 0.20,
                eventTTL: 0.30,
                rearmSilenceWindow: 0.10,
                wrongNoteGraceWindow: 0.18
            )
        case .stricter:
            AudioStepAttemptAccumulatorConfiguration(
                singleNoteThreshold: 0.70,
                handBoostedThreshold: 0.62,
                wrongNoteThreshold: 0.72,
                wrongDominanceRatio: 1.40,
                onsetThreshold: 0.40,
                aggregationWindow: 0.28,
                eventTTL: 0.40,
                rearmSilenceWindow: 0.12,
                wrongNoteGraceWindow: 0.18
            )
        }
    }
}

final class AudioStepAttemptAccumulator {
    private static let decisionLogger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "HappyPianistAVP",
        category: "Step3AudioDecision"
    )
    private(set) var configuration: AudioStepAttemptAccumulatorConfiguration

    private var recentEvents: [DetectedNoteEvent] = []
    private var rearmBlockedSince: [Int: Date] = [:]
    private var currentGeneration: Int = 0
    private var recognitionMode: Step3AudioRecognitionMode = .lowLatency
    private var lastMatchedAt: Date?

    init(configuration: AudioStepAttemptAccumulatorConfiguration = .init()) {
        self.configuration = configuration
    }

    func register(event: DetectedNoteEvent) {
        guard event.generation == currentGeneration else { return }
        if event.isOnset {
            rearmBlockedSince[event.midiNote] = nil
        }
        recentEvents.append(event)
    }

    func setMode(_ mode: Step3AudioRecognitionMode) {
        recognitionMode = mode
        configuration = .configuration(for: mode)
        Self.decisionLogger.debug("accumulator mode changed to \(mode.rawValue, privacy: .public)")
    }

    func evaluate(
        expectedMIDINotes: [Int],
        wrongCandidateMIDINotes: Set<Int>,
        generation: Int,
        at timestamp: Date,
        handGateBoost: Bool = false
    ) -> StepAttemptMatchResult {
        if generation != currentGeneration {
            currentGeneration = generation
            resetForNewStep(generation: generation)
        }
        pruneExpiredEvents(now: timestamp)

        let expectedSet = Set(expectedMIDINotes)
        let threshold = threshold(for: handGateBoost)
        let activeEvents = makeActiveEvents(generation: generation, at: timestamp, threshold: threshold)
        let observed = Set(activeEvents.map(\.midiNote))
        let evidence = makeEvidence(
            expected: expectedSet,
            observed: observed,
            handMode: .both,
            message: "audio evaluation"
        )
        guard expectedSet.isEmpty == false else {
            return .insufficientEvidence(evidence: evidence)
        }

        let strongestExpected = activeEvents
            .filter { expectedSet.contains($0.midiNote) }
            .map(\.confidence)
            .max() ?? 0
        let wrongEvents = activeEvents.filter { wrongCandidateMIDINotes.contains($0.midiNote) }
        let strongestWrong = wrongEvents.map(\.confidence).max() ?? 0

        if strongestWrong >= configuration.wrongNoteThreshold,
           strongestWrong >= max(strongestExpected, 0.01) * configuration.wrongDominanceRatio
        {
            if let lastMatchedAt, timestamp.timeIntervalSince(lastMatchedAt) <= configuration.wrongNoteGraceWindow {
                return .insufficientEvidence(evidence: makeEvidence(
                    expected: expectedSet,
                    observed: observed,
                    handMode: .both,
                    message: "wrong note grace"
                ))
            }
            return .wrongNote(
                evidence: makeEvidence(
                    expected: expectedSet,
                    observed: observed,
                    handMode: .both,
                    message: "wrong note dominates window"
                ),
                unexpectedNotes: Set(wrongEvents.map(\.midiNote))
            )
        }

        let matchedNotes = expectedSet.intersection(observed)
        if matchedNotes == expectedSet {
            lastMatchedAt = timestamp
            return .matched(evidence: makeEvidence(
                expected: expectedSet,
                observed: observed,
                handMode: .both,
                message: expectedSet.count == 1 ? "single note matched" : "complete chord matched"
            ))
        }

        let isPartialChordEvidence = expectedSet.count >= 3
            && matchedNotes.count >= requiredMatchCount(expectedCount: expectedSet.count)
        return .insufficientEvidence(evidence: PracticeAttemptEvidence(
            expectedNotes: expectedSet,
            observedNotes: observed,
            handMode: .both,
            source: .audio,
            isPartialEvidence: isPartialChordEvidence,
            debugMessage: isPartialChordEvidence ? "experimental chord majority" : "expected notes pending"
        ))
    }

    func evaluateHandSeparated(
        expectedRightMIDINotes: [Int],
        expectedLeftMIDINotes: [Int],
        wrongCandidateMIDINotes: Set<Int>,
        generation: Int,
        at timestamp: Date,
        handGateBoost: Bool = false
    ) -> StepAttemptMatchResult {
        if generation != currentGeneration {
            currentGeneration = generation
            resetForNewStep(generation: generation)
        }
        pruneExpiredEvents(now: timestamp)

        let expectedRightSet = Set(expectedRightMIDINotes)
        let expectedLeftSet = Set(expectedLeftMIDINotes)
        let expectedUnion = expectedRightSet.union(expectedLeftSet)
        let handMode: PracticeHandMode = if expectedRightSet.isEmpty {
            .left
        } else if expectedLeftSet.isEmpty {
            .right
        } else {
            .both
        }
        let threshold = threshold(for: handGateBoost)
        let activeEvents = makeActiveEvents(generation: generation, at: timestamp, threshold: threshold)
        let observed = Set(activeEvents.map(\.midiNote))
        guard expectedUnion.isEmpty == false else {
            return .insufficientEvidence(evidence: makeEvidence(
                expected: expectedUnion,
                observed: observed,
                handMode: handMode,
                message: "no expected notes"
            ))
        }

        let strongestExpected = activeEvents
            .filter { expectedUnion.contains($0.midiNote) }
            .map(\.confidence)
            .max() ?? 0
        let wrongEvents = activeEvents.filter { wrongCandidateMIDINotes.contains($0.midiNote) }
        let strongestWrong = wrongEvents.map(\.confidence).max() ?? 0

        if strongestWrong >= configuration.wrongNoteThreshold,
           strongestWrong >= max(strongestExpected, 0.01) * configuration.wrongDominanceRatio
        {
            if let lastMatchedAt, timestamp.timeIntervalSince(lastMatchedAt) <= configuration.wrongNoteGraceWindow {
                return .insufficientEvidence(evidence: makeEvidence(
                    expected: expectedUnion,
                    observed: observed,
                    handMode: handMode,
                    message: "wrong note grace"
                ))
            }
            return .wrongNote(
                evidence: makeEvidence(
                    expected: expectedUnion,
                    observed: observed,
                    handMode: handMode,
                    message: "wrong note dominates window"
                ),
                unexpectedNotes: Set(wrongEvents.map(\.midiNote))
            )
        }

        let matched = expectedUnion.intersection(observed)
        if matched == expectedUnion {
            lastMatchedAt = timestamp
            return .matched(evidence: makeEvidence(
                expected: expectedUnion,
                observed: observed,
                handMode: handMode,
                message: "hand-separated complete match"
            ))
        }

        let partialThresholdReached = [expectedRightSet, expectedLeftSet].contains { expected in
            expected.count >= 3
                && expected.intersection(observed).count >= requiredMatchCount(expectedCount: expected.count)
                && expected.isSubset(of: observed) == false
        }
        return .insufficientEvidence(evidence: PracticeAttemptEvidence(
            expectedNotes: expectedUnion,
            observedNotes: observed,
            handMode: handMode,
            source: .audio,
            isPartialEvidence: partialThresholdReached,
            debugMessage: partialThresholdReached ? "experimental hand chord majority" : "hand notes pending"
        ))
    }

    private func makeEvidence(
        expected: Set<Int>,
        observed: Set<Int>,
        handMode: PracticeHandMode,
        message: String
    ) -> PracticeAttemptEvidence {
        PracticeAttemptEvidence(
            expectedNotes: expected,
            observedNotes: observed,
            handMode: handMode,
            source: .audio,
            isPartialEvidence: false,
            debugMessage: message
        )
    }

    func resetForNewStep(generation: Int) {
        currentGeneration = generation
        recentEvents.removeAll()
        lastMatchedAt = nil
    }

    func markMatchedAndRequireRearm(expectedMIDINotes: [Int], at timestamp: Date) {
        for midiNote in Set(expectedMIDINotes) {
            rearmBlockedSince[midiNote] = timestamp
        }
    }

    private func pruneExpiredEvents(now: Date) {
        recentEvents.removeAll { event in
            now.timeIntervalSince(event.timestamp) > configuration.eventTTL
        }
        rearmBlockedSince = rearmBlockedSince.filter { _, blockedAt in
            now.timeIntervalSince(blockedAt) < configuration.rearmSilenceWindow
        }
    }

    private func isEventQualified(_ event: DetectedNoteEvent, threshold: Double) -> Bool {
        event.confidence >= threshold && (event.isOnset || event.onsetScore >= configuration.onsetThreshold)
    }

    private func threshold(for handGateBoost: Bool) -> Double {
        handGateBoost ? configuration.handBoostedThreshold : configuration.singleNoteThreshold
    }

    private func makeActiveEvents(generation: Int, at timestamp: Date, threshold: Double) -> [DetectedNoteEvent] {
        recentEvents.filter { event in
            event.timestamp <= timestamp &&
                timestamp.timeIntervalSince(event.timestamp) <= configuration.aggregationWindow &&
                event.generation == generation &&
                isEventQualified(event, threshold: threshold) &&
                isRearmSatisfied(for: event.midiNote, at: timestamp)
        }
    }

    private func isRearmSatisfied(for midiNote: Int, at timestamp: Date) -> Bool {
        guard let blockedAt = rearmBlockedSince[midiNote] else { return true }
        return timestamp.timeIntervalSince(blockedAt) >= configuration.rearmSilenceWindow
    }

    private func requiredMatchCount(expectedCount: Int) -> Int {
        switch expectedCount {
        case ...0:
            0
        case 1:
            1
        case 2:
            2
        default:
            Int(ceil(Double(expectedCount) * 2.0 / 3.0))
        }
    }
}
