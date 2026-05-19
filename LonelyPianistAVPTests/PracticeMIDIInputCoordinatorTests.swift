import Foundation
@testable import LonelyPianistAVP
import Testing

@Test
@MainActor
func refreshInNonGuidingStateStopsInput() {
    let source = FakeProtocolSeparatedPracticeInputEventSource()
    let coordinator = PracticeMIDIInputCoordinator(
        practiceInputEventSource: source,
        matcher: MIDIPracticeStepMatcher(),
        consumeEvents: true
    )

    coordinator.refresh(
        for: .init(
            practiceState: .ready,
            autoplayState: .off,
            isManualReplayPlaying: false,
            currentStepIndex: 0,
            expectedNotes: [PracticeStepNote(midiNote: 60, staff: 1)]
        )
    )

    #expect(source.stopCallCount == 1)
    #expect(source.isRunning == false)
}

@Test
@MainActor
func shutdownIsIdempotent() {
    let source = FakeProtocolSeparatedPracticeInputEventSource()
    let coordinator = PracticeMIDIInputCoordinator(
        practiceInputEventSource: source,
        matcher: MIDIPracticeStepMatcher()
    )

    coordinator.refresh(
        for: .init(
            practiceState: .guiding(stepIndex: 0),
            autoplayState: .off,
            isManualReplayPlaying: false,
            currentStepIndex: 0,
            expectedNotes: [PracticeStepNote(midiNote: 60, staff: 1)]
        )
    )
    #expect(source.startCallCount == 1)
    #expect(source.isRunning == true)

    coordinator.shutdown()
    coordinator.shutdown()

    #expect(source.stopCallCount == 1)
}

@Test
@MainActor
func shutdownDoesNotCancelOtherConsumers() async {
    let source = FakeProtocolSeparatedPracticeInputEventSource()
    let coordinator = PracticeMIDIInputCoordinator(
        practiceInputEventSource: source,
        matcher: MIDIPracticeStepMatcher()
    )

    coordinator.refresh(
        for: .init(
            practiceState: .guiding(stepIndex: 0),
            autoplayState: .off,
            isManualReplayPlaying: false,
            currentStepIndex: 0,
            expectedNotes: [PracticeStepNote(midiNote: 60, staff: 1)]
        )
    )

    let otherStream = source.midi1EventsStream()
    let otherTask = Task {
        for await _ in otherStream {
            return true
        }
        return false
    }

    source.emitMIDI1(
        MIDI1InputEvent(
            kind: .noteOn(note: 60, velocity: 1),
            channel: 1,
            group: 0,
            source: .init(identifier: .sourceIndex(0), endpointName: "test"),
            receivedAt: .now,
            receivedAtUptimeSeconds: ProcessInfo.processInfo.systemUptime,
            debugEventID: 1
        )
    )

    coordinator.shutdown()
    let received = await otherTask.value

    #expect(received == true)
}
