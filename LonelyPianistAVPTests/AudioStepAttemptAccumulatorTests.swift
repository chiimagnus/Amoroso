import Foundation
@testable import LonelyPianistAVP
import Testing

@Test
func singleNoteMatchesWhenExactMIDIWithOnset() {
    let accumulator = AudioStepAttemptAccumulator()
    let now = Date(timeIntervalSince1970: 1_000)
    accumulator.resetForNewStep(generation: 7)
    accumulator.register(event: makeEvent(midiNote: 60, confidence: 0.9, isOnset: true, timestamp: now, generation: 7))

    let result = accumulator.evaluate(
        expectedMIDINotes: [60],
        wrongCandidateMIDINotes: [],
        generation: 7,
        at: now
    )

    #expect(result == .matched(reason: "single note matched"))
}

@Test
func singleNoteDoesNotMatchAdjacentSemitone() {
    let accumulator = AudioStepAttemptAccumulator()
    let now = Date(timeIntervalSince1970: 1_000)
    accumulator.resetForNewStep(generation: 1)
    accumulator.register(event: makeEvent(midiNote: 61, confidence: 0.9, isOnset: true, timestamp: now, generation: 1))

    let result = accumulator.evaluate(
        expectedMIDINotes: [60],
        wrongCandidateMIDINotes: [],
        generation: 1,
        at: now
    )

    #expect(result == .insufficient(progress: "single note pending"))
}

@Test
func singleNoteReturnsInsufficientWhenConfidenceBelowThreshold() {
    let accumulator = AudioStepAttemptAccumulator()
    let now = Date(timeIntervalSince1970: 1_000)
    accumulator.resetForNewStep(generation: 9)
    accumulator.register(event: makeEvent(midiNote: 60, confidence: 0.55, isOnset: true, timestamp: now, generation: 9))

    let result = accumulator.evaluate(
        expectedMIDINotes: [60],
        wrongCandidateMIDINotes: [],
        generation: 9,
        at: now
    )

    #expect(result == .insufficient(progress: "single note pending"))
}

@Test
func mismatchedGenerationEventsAreIgnored() {
    let accumulator = AudioStepAttemptAccumulator()
    let now = Date(timeIntervalSince1970: 1_000)
    accumulator.resetForNewStep(generation: 10)
    accumulator.register(event: makeEvent(midiNote: 60, confidence: 0.95, isOnset: true, timestamp: now, generation: 11))

    let result = accumulator.evaluate(
        expectedMIDINotes: [60],
        wrongCandidateMIDINotes: [],
        generation: 10,
        at: now
    )

    #expect(result == .insufficient(progress: "single note pending"))
}

private func makeEvent(
    midiNote: Int,
    confidence: Double,
    isOnset: Bool,
    timestamp: Date,
    generation: Int
) -> DetectedNoteEvent {
    DetectedNoteEvent(
        midiNote: midiNote,
        confidence: confidence,
        onsetScore: isOnset ? 1.0 : 0.0,
        isOnset: isOnset,
        timestamp: timestamp,
        generation: generation,
        source: .audio
    )
}
