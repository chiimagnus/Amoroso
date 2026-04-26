import Foundation
@testable import LonelyPianistAVP
import Testing

@Test
func fakeAudioRecognitionServiceEmitsEventToConsumer() async {
    let service = FakePracticeAudioRecognitionService()
    let event = DetectedNoteEvent(
        midiNote: 60,
        confidence: 0.9,
        onsetScore: 0.8,
        isOnset: true,
        timestamp: Date(timeIntervalSince1970: 1_000),
        generation: 1,
        source: .audio
    )

    let consumeTask = Task<DetectedNoteEvent?, Never> {
        for await next in service.events {
            return next
        }
        return nil
    }

    service.emitEvent(event)
    let received = await consumeTask.value

    #expect(received == event)
}

@Test
func fakeAudioRecognitionServiceRecordsLifecycleCalls() async throws {
    let service = FakePracticeAudioRecognitionService()
    let now = Date(timeIntervalSince1970: 2_000)
    try await service.start(expectedMIDINotes: [60], wrongCandidateMIDINotes: [61, 62], generation: 3)
    service.updateExpectedNotes([64], wrongCandidateMIDINotes: [63], generation: 4)
    service.suppressRecognition(until: now, generation: 4)
    service.stop()

    #expect(service.startCalls == [.init(expectedMIDINotes: [60], wrongCandidateMIDINotes: [61, 62], generation: 3)])
    #expect(service.updateCalls == [.init(expectedMIDINotes: [64], wrongCandidateMIDINotes: [63], generation: 4)])
    #expect(service.suppressCalls == [.init(until: now, generation: 4)])
    #expect(service.stopCallCount == 1)
}
