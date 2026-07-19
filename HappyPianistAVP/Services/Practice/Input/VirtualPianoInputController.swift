import Foundation
import simd

@MainActor
protocol KeyContactDetectingProtocol: AnyObject {
    func reset()
    func detect(
        fingerTips: FingerTipsSnapshot,
        keyboardGeometry: PianoKeyboardGeometry
    ) -> KeyContactResult
}

extension KeyContactDetectionService: KeyContactDetectingProtocol {}
extension RealPianoContactDetectionService: KeyContactDetectingProtocol {}

@MainActor
final class VirtualPianoInputController {
    private let detector: any KeyContactDetectingProtocol
    private let sequencerPlaybackService: PracticeSequencerPlaybackServiceProtocol
    private let stateStore: PracticeSessionStateStore
    private let handGateController: PracticeHandGateController
    private var playbackTask: Task<Void, Never>?
    private var hasShutdown = false

    init(
        detector: any KeyContactDetectingProtocol,
        sequencerPlaybackService: PracticeSequencerPlaybackServiceProtocol,
        stateStore: PracticeSessionStateStore,
        handGateController: PracticeHandGateController
    ) {
        self.detector = detector
        self.sequencerPlaybackService = sequencerPlaybackService
        self.stateStore = stateStore
        self.handGateController = handGateController
    }

    func shutdown() {
        guard hasShutdown == false else { return }
        hasShutdown = true
        stop()
    }

    func stop() {
        let previousPlaybackTask = playbackTask
        let sequencerPlaybackService = sequencerPlaybackService
        playbackTask = Task {
            await previousPlaybackTask?.value
            await sequencerPlaybackService.stopAllLiveNotes()
        }
        detector.reset()
        stateStore.latestKeyContactResult = KeyContactResult(down: [], started: [], ended: [])
        stateStore.pressedNotes.removeAll()
        stateStore.latestNoteOnMIDINotes.removeAll()
    }

    func handleFingerTips(
        _ fingerTips: FingerTipsSnapshot,
        keyboardGeometry: PianoKeyboardGeometry,
        at timestamp: Date,
        practiceHandMode: PracticeHandMode
    ) -> Set<Int> {
        let result = detector.detect(
            fingerTips: fingerTips,
            keyboardGeometry: keyboardGeometry
        )
        stateStore.latestKeyContactResult = result
        stateStore.latestNoteOnMIDINotes = result.started

        let shouldPlayLiveNotes = stateStore.autoplayState == .off && stateStore.isManualReplayPlaying == false
        if shouldPlayLiveNotes {
            enqueuePlayback(
                commands: result.ended.sorted().map {
                    PracticePlaybackCommand(
                        sourceEventID: "virtual-piano-\($0)",
                        kind: .noteOff(midi: $0)
                    )
                } + result.started.sorted().map {
                    PracticePlaybackCommand(
                        sourceEventID: "virtual-piano-\($0)",
                        kind: .noteOn(midi: $0, velocity: 96)
                    )
                }
            )
        }

        stateStore.pressedNotes = result.down
        handGateController.updateHandGateState(
            fingerTips: fingerTips,
            keyboardGeometry: keyboardGeometry,
            exactPressedNotes: result.down
        )

        if result.started.isEmpty == false {
            handGateController.registerChordAttemptIfNeeded(
                pressedNotes: result.started,
                at: timestamp,
                practiceHandMode: practiceHandMode
            )
        }

        return result.down
    }

    func waitForPendingPlayback() async {
        await playbackTask?.value
    }

    private func enqueuePlayback(commands: [PracticePlaybackCommand]) {
        guard commands.isEmpty == false else { return }
        let previousPlaybackTask = playbackTask
        let sequencerPlaybackService = sequencerPlaybackService
        playbackTask = Task {
            await previousPlaybackTask?.value
            do {
                try await sequencerPlaybackService.execute(commands: commands)
            } catch {
                stateStore.recordPlaybackError(error)
            }
        }
    }
}
