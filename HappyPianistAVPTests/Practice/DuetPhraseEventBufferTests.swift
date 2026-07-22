import Foundation
@testable import HappyPianistAVP
import Testing

private let phraseEventTestSource = PerformanceObservation.Source(
    kind: .midi1,
    id: "duet-phrase-event-buffer-test",
    generation: 1
)

private func controlChange(
    _ controller: Int,
    _ value: Int,
    at timestampSeconds: TimeInterval
) -> PerformanceObservationPhraseAdapter.PhraseEvent {
    .init(
        observationID: UUID(),
        source: phraseEventTestSource,
        timestamp: .init(seconds: timestampSeconds),
        timingProvenance: .hostOnly,
        kind: .controlChange(controller: controller, value: value)
    )
}

@Test
func duetPhraseEventBufferSnapshotFiltersWhitelistAndRebasesWindow() {
    var buffer = DuetPhraseEventBuffer()
    buffer.record(controlChange(64, 127, at: 1.0))
    buffer.record(controlChange(7, 90, at: 1.2))
    buffer.record(controlChange(1, 80, at: 1.3)) // ignored

    let snapshot = buffer.snapshot(nowTimestampSeconds: 1.5, lookbackSeconds: 4.0, maxPromptSeconds: 3.0)
    let controllers = snapshot.promptEvents.compactMap(\.controller)
    #expect(controllers == [64, 7])
    #expect(snapshot.latestValues[64] == 127)
    #expect(snapshot.latestValues[1] == nil)
    #expect(snapshot.sustainValue == 127)
}

@Test
func duetPhraseEventBufferInjectsInitialCCStateAtWindowStart() {
    var buffer = DuetPhraseEventBuffer()
    buffer.record(controlChange(64, 127, at: 0.5))
    buffer.record(controlChange(11, 70, at: 0.7))
    buffer.record(controlChange(64, 0, at: 2.6))

    let snapshot = buffer.snapshot(nowTimestampSeconds: 3.0, lookbackSeconds: 10.0, maxPromptSeconds: 1.0)
    let zeroTime = snapshot.promptEvents.filter { abs($0.time - 0.0) < 1e-9 }
    let zeroSummary = zeroTime.compactMap { event -> String? in
        guard let controller = event.controller, let value = event.value else { return nil }
        return "\(controller):\(value)"
    }.sorted()

    #expect(zeroSummary == ["11:70", "64:127"])
    #expect(snapshot.promptEvents.contains { $0.controller == 64 && $0.value == 0 && abs($0.time - 1.0) < 1e-9 })
}

@Test
func duetPhraseEventBufferPrunesOldHistory() {
    var buffer = DuetPhraseEventBuffer()
    buffer.record(controlChange(64, 127, at: 1.0))
    buffer.record(controlChange(7, 100, at: 15.0))

    let snapshot = buffer.snapshot(nowTimestampSeconds: 15.5, lookbackSeconds: 12.0, maxPromptSeconds: 3.0)
    #expect(snapshot.promptEvents.contains { $0.controller == 7 })
    #expect(snapshot.promptEvents.contains { $0.controller == 64 && $0.value == 127 && $0.time == 0 })
}

@Test
func duetPhraseEventBufferDoesNotDuplicateControlChangeAtWindowStart() {
    var buffer = DuetPhraseEventBuffer()
    buffer.record(controlChange(64, 127, at: 1))
    buffer.record(controlChange(7, 90, at: 3))

    let snapshot = buffer.snapshot(nowTimestampSeconds: 3, lookbackSeconds: 4, maxPromptSeconds: 2)
    let sustainEvents = snapshot.promptEvents.filter { $0.controller == 64 }
    #expect(sustainEvents.count == 1)
    #expect(sustainEvents.first?.time == 0)
}

@Test
func performanceObservationPhraseAdapterUnifiesMIDIRecordingAndHandEvidence() {
    let adapter = PerformanceObservationPhraseAdapter()
    let midiID = UUID()
    let midiSource = PerformanceObservation.Source(kind: .midi1, id: "midi-source", generation: 4)
    let midiObservation = PerformanceObservation(
        id: midiID,
        source: midiSource,
        timing: .init(
            host: .init(seconds: 10.1),
            source: nil,
            correctedHost: .init(seconds: 10),
            mapping: nil,
            provenance: .latencyEstimate
        ),
        event: .noteOn(note: 60, velocity: .init(midi1: 78))
    )
    let midiPhraseEvent = adapter.phraseEvent(from: midiObservation)
    #expect(midiPhraseEvent != nil)
    guard let midiPhraseEvent else { return }

    let recordingSource = PerformanceObservation.Source(kind: .midi2, id: "recording-source", generation: 2)
    let recordingPhraseEvent = adapter.phraseEvent(
        from: RecordingTakeEvent(time: 0.4, kind: .noteOff(midi: 60)),
        source: recordingSource,
        startTime: .init(seconds: 10)
    )
    #expect(recordingPhraseEvent != nil)
    guard let recordingPhraseEvent else { return }

    let handID = UUID()
    let handSource = PerformanceObservation.Source(kind: .virtualPianoContact, id: "hand-source", generation: 4)
    let handObservation = PerformanceObservation(
        id: handID,
        source: handSource,
        timing: .init(
            host: .init(seconds: 10.5),
            source: nil,
            correctedHost: .init(seconds: 10.5),
            mapping: nil,
            provenance: .hostOnly
        ),
        event: .contact(id: "right-index-1", keyCandidate: 64, phase: .started),
        onsetVelocity: .init(midi1: 66)
    )
    let handPhraseEvent = adapter.phraseEvent(from: handObservation)
    #expect(handPhraseEvent != nil)
    guard let handPhraseEvent else { return }

    var notes = DuetPhraseBuffer()
    notes.record(midiPhraseEvent, sustainIsDown: false)
    notes.record(recordingPhraseEvent, sustainIsDown: false)
    notes.record(handPhraseEvent, sustainIsDown: false)
    let snapshot = notes.snapshot(nowTimestampSeconds: 10.7, lookbackSeconds: 4, maxPromptSeconds: 3)

    #expect(snapshot.promptNotes.contains {
        $0.note == 60 && $0.velocity == 78 && abs($0.duration - 0.4) < 0.000_001
    })
    #expect(snapshot.promptNotes.contains { $0.note == 64 && $0.velocity == 66 })
    #expect(snapshot.phraseProvenance.observations.contains {
        $0.id == midiID && $0.capabilities == .midi && $0.timingProvenance == .latencyEstimate
    })
    #expect(snapshot.phraseProvenance.observations.contains {
        $0.id == handID && $0.capabilities == .handContact
    })
    #expect(recordingPhraseEvent.timestamp == .init(seconds: 10.4))
}
