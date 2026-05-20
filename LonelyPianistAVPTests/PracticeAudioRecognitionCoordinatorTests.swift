import Foundation
@testable import LonelyPianistAVP
import Testing

@MainActor
private final class CapturingPracticeAudioRecognitionEffectHandler: PracticeSessionEffectHandlerProtocol {
    private(set) var effects: [PracticeSessionEffect] = []

    func handle(effect: PracticeSessionEffect) {
        effects.append(effect)
    }
}

@MainActor
private final class FakePracticeAudioRecognitionInputServiceService: PracticeAudioRecognitionServiceProtocol {
    let events: AsyncStream<DetectedNoteEvent> = AsyncStream { _ in }
    let statusUpdates: AsyncStream<PracticeAudioRecognitionStatus> = AsyncStream { _ in }
    let debugSnapshots: AsyncStream<PracticeAudioRecognitionDebugSnapshot> = AsyncStream { _ in }

    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0

    func start(
        expectedMIDINotes _: [Int],
        wrongCandidateMIDINotes _: [Int],
        generation _: Int,
        suppressUntil _: Date?
    ) async throws {
        startCallCount += 1
    }

    func updateExpectedNotes(_: [Int], wrongCandidateMIDINotes _: [Int], generation _: Int) {}
    func configureDetectorMode(_: PracticeAudioRecognitionDetectorMode, profile _: HarmonicTemplateTuningProfile) {}
    func suppressRecognition(until _: Date, generation _: Int) {}

    func stop() {
        stopCallCount += 1
    }
}

@Test
@MainActor
func practiceAudioRecognitionService_serviceNilHasNoSideEffects() async {
    let stateStore = PracticeSessionStateStore()
    let effectHandler = CapturingPracticeAudioRecognitionEffectHandler()
    let service = PracticeAudioRecognitionInputService(
        service: nil,
        accumulator: AudioStepAttemptAccumulator(),
        stateStore: stateStore,
        effectHandler: effectHandler,
        consumeStreams: false
    )

    service.refresh(
        for: .init(
            practiceState: .guiding(stepIndex: 0),
            autoplayState: .off,
            isManualReplayPlaying: false,
            isAudioRecognitionEnabled: true,
            expectedMIDINotes: [60],
            expectedRightMIDINotes: [],
            expectedLeftMIDINotes: [],
            wrongCandidateMIDINotes: [],
            handGateBoost: false,
            isHandSeparatedStepMatchingEnabled: false,
            suppressUntil: nil
        )
    )
    service.stop()
    service.shutdown()
    await Task.yield()

    #expect(stateStore.isAudioRecognitionRunning == false)
}

@Test
@MainActor
func practiceAudioRecognitionService_shutdownIsIdempotent() {
    let service = FakePracticeAudioRecognitionInputServiceService()
    let stateStore = PracticeSessionStateStore()
    let effectHandler = CapturingPracticeAudioRecognitionEffectHandler()
    let service = PracticeAudioRecognitionInputService(
        service: service,
        accumulator: AudioStepAttemptAccumulator(),
        stateStore: stateStore,
        effectHandler: effectHandler,
        consumeStreams: false
    )

    service.shutdown()
    service.shutdown()

    #expect(service.stopCallCount == 1)
}

@Test
@MainActor
func practiceAudioRecognitionService_refreshOutsideGuidingStopsService() {
    let service = FakePracticeAudioRecognitionInputServiceService()
    let stateStore = PracticeSessionStateStore()
    let effectHandler = CapturingPracticeAudioRecognitionEffectHandler()
    stateStore.isAudioRecognitionRunning = true
    let service = PracticeAudioRecognitionInputService(
        service: service,
        accumulator: AudioStepAttemptAccumulator(),
        stateStore: stateStore,
        effectHandler: effectHandler,
        consumeStreams: false
    )

    service.refresh(
        for: .init(
            practiceState: .ready,
            autoplayState: .off,
            isManualReplayPlaying: false,
            isAudioRecognitionEnabled: true,
            expectedMIDINotes: [60],
            expectedRightMIDINotes: [],
            expectedLeftMIDINotes: [],
            wrongCandidateMIDINotes: [],
            handGateBoost: false,
            isHandSeparatedStepMatchingEnabled: false,
            suppressUntil: nil
        )
    )

    #expect(service.stopCallCount == 1)
    #expect(stateStore.isAudioRecognitionRunning == false)
}
