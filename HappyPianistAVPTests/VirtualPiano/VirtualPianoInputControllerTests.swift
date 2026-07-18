import Foundation
@testable import HappyPianistAVP
import simd
import Testing

@MainActor
private final class CapturingEffectHandler: PracticeSessionEffectHandlerProtocol {
    private(set) var effects: [PracticeSessionEffect] = []

    func handle(effect: PracticeSessionEffect) {
        effects.append(effect)
    }
}

private final class AlwaysMatchChordAttemptAccumulator: ChordAttemptAccumulatorProtocol {
    func register(
        pressedNotes _: Set<Int>,
        expectedNotes _: [Int],
        tolerance _: Int,
        at _: Date
    ) -> StepAttemptMatchResult {
        testAttemptOutcome(matched: true)
    }

    func reset() {}
}

@MainActor
private final class FakeKeyContactDetector: KeyContactDetectingProtocol {
    var resultToReturn: KeyContactResult

    init(resultToReturn: KeyContactResult) {
        self.resultToReturn = resultToReturn
    }

    func reset() {}

    func detect(
        fingerTips _: FingerTipsSnapshot,
        keyboardGeometry _: PianoKeyboardGeometry
    ) -> KeyContactResult {
        resultToReturn
    }
}

@MainActor
private final class FakeSequencerPlaybackService: PracticeSequencerPlaybackServiceProtocol {
    private(set) var commands: [[PracticePlaybackCommand]] = []

    func warmUp() throws {}
    func stop(resetCommands _: [PerformanceTransportCommand]) {}
    func load(sequence _: PracticeSequencerSequence) throws {}
    func play(fromSeconds _: TimeInterval) throws {}
    func currentSeconds() -> TimeInterval {
        0
    }

    func playOneShot(commands _: [PracticePlaybackCommand], durationSeconds _: TimeInterval) throws {}
    func execute(commands: [PracticePlaybackCommand]) throws {
        self.commands.append(commands)
    }

    func stopAllLiveNotes() {}
}

private func makeMinimalKeyboardGeometry() -> PianoKeyboardGeometry {
    let frame = KeyboardFrame(worldFromKeyboard: matrix_identity_float4x4)
    let key = PianoKeyGeometry(
        midiNote: 60,
        kind: .white,
        localCenter: .zero,
        localSize: SIMD3<Float>(1, 0.02, 0.2),
        surfaceLocalY: 0,
        hitCenterLocal: .zero,
        hitSizeLocal: SIMD3<Float>(1, 0.02, 0.2),
        beamFootprintCenterLocal: .zero,
        beamFootprintSizeLocal: SIMD2<Float>(1, 0.2)
    )
    return PianoKeyboardGeometry(frame: frame, keys: [key])
}

@Test
@MainActor
func virtualPianoPlaysLiveNotesWhenNotSuppressed() async {
    let store = PracticeSessionStateStore()
    store.autoplayState = .off
    store.isManualReplayPlaying = false
    store.steps = [PracticeStep(tick: 0, notes: [PracticeStepNote(midiNote: 60, staff: 1, handAssignment: .unknown)])]
    store.currentStepIndex = 0

    let effectHandler = CapturingEffectHandler()
    let handGateController = PracticeHandGateController(
        activityGate: HandPianoActivityGate(),
        chordAttemptAccumulator: AlwaysMatchChordAttemptAccumulator(),
        stateStore: store,
        effectHandler: effectHandler
    )

    let detector = FakeKeyContactDetector(
        resultToReturn: KeyContactResult(down: [60], started: [60], ended: [61])
    )
    let sequencer = FakeSequencerPlaybackService()
    let controller = VirtualPianoInputController(
        detector: detector,
        sequencerPlaybackService: sequencer,
        stateStore: store,
        handGateController: handGateController
    )

    _ = controller.handleFingerTips(
        FingerTipsSnapshot.empty,
        keyboardGeometry: makeMinimalKeyboardGeometry(),
        at: .now,
        practiceHandMode: .both
    )
    await controller.waitForPendingPlayback()

    #expect(sequencer.commands == [[
        PracticePlaybackCommand(sourceEventID: "virtual-piano-61", kind: .noteOff(midi: 61)),
        PracticePlaybackCommand(sourceEventID: "virtual-piano-60", kind: .noteOn(midi: 60, velocity: 96)),
    ]])
    #expect(effectHandler.effects.contains(.advanceToNextStep))
}

@Test
@MainActor
func virtualPianoDoesNotPlayLiveNotesDuringAutoplay() async {
    let store = PracticeSessionStateStore()
    store.autoplayState = .playing
    store.isManualReplayPlaying = false

    let effectHandler = CapturingEffectHandler()
    let handGateController = PracticeHandGateController(
        activityGate: HandPianoActivityGate(),
        chordAttemptAccumulator: AlwaysMatchChordAttemptAccumulator(),
        stateStore: store,
        effectHandler: effectHandler
    )

    let detector = FakeKeyContactDetector(
        resultToReturn: KeyContactResult(down: [60], started: [60], ended: [61])
    )
    let sequencer = FakeSequencerPlaybackService()
    let controller = VirtualPianoInputController(
        detector: detector,
        sequencerPlaybackService: sequencer,
        stateStore: store,
        handGateController: handGateController
    )

    _ = controller.handleFingerTips(
        FingerTipsSnapshot.empty,
        keyboardGeometry: makeMinimalKeyboardGeometry(),
        at: .now,
        practiceHandMode: .both
    )
    await controller.waitForPendingPlayback()

    #expect(sequencer.commands.isEmpty)
}
