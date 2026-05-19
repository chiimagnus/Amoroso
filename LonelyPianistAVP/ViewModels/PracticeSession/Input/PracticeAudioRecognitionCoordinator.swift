import Foundation
import os

@MainActor
final class PracticeAudioRecognitionCoordinator: PracticeAudioRecognitionCoordinating, PracticeSessionLifecycleProtocol {
    struct Snapshot: Equatable {
        var practiceState: PracticeSessionState
        var autoplayState: PracticeSessionAutoplayState
        var isManualReplayPlaying: Bool
        var isAudioRecognitionEnabled: Bool
        var expectedMIDINotes: [Int]
        var wrongCandidateMIDINotes: [Int]
        var suppressUntil: Date?
    }

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "LonelyPianistAVP",
        category: "PracticeAudioRecognitionCoordinator"
    )

    private let service: PracticeAudioRecognitionServiceProtocol?
    private let accumulator: AudioStepAttemptAccumulator
    private let stateStore: PracticeSessionStateStore

    private var hasShutdown = false

    init(
        service: PracticeAudioRecognitionServiceProtocol?,
        accumulator: AudioStepAttemptAccumulator,
        stateStore: PracticeSessionStateStore
    ) {
        self.service = service
        self.accumulator = accumulator
        self.stateStore = stateStore
    }

    func shutdown() {
        guard hasShutdown == false else { return }
        hasShutdown = true
        stop()
    }

    func refreshForCurrentState() {
        guard let snapshot = latestSnapshot else {
            stop()
            return
        }
        refresh(for: snapshot)
    }

    func stop() {
        guard let service else { return }
        service.stop()
        stateStore.isAudioRecognitionRunning = false
    }

    private var latestSnapshot: Snapshot?

    func refresh(for snapshot: Snapshot) {
        latestSnapshot = snapshot
        guard let service else { return }

        guard snapshot.isAudioRecognitionEnabled else {
            stop()
            return
        }
        guard snapshot.autoplayState == .off else {
            stop()
            return
        }
        guard snapshot.isManualReplayPlaying == false else {
            stop()
            return
        }
        guard case .guiding = snapshot.practiceState, snapshot.expectedMIDINotes.isEmpty == false else {
            stop()
            return
        }

        service.configureDetectorMode(
            stateStore.practiceAudioRecognitionDetectorModeSnapshot,
            profile: stateStore.harmonicTemplateTuningProfileSnapshot
        )

        accumulator.setMode(.lowLatency)
        stateStore.audioRecognitionGeneration += 1
        accumulator.resetForNewStep(generation: stateStore.audioRecognitionGeneration)

        if stateStore.isAudioRecognitionRunning {
            service.updateExpectedNotes(
                snapshot.expectedMIDINotes,
                wrongCandidateMIDINotes: snapshot.wrongCandidateMIDINotes,
                generation: stateStore.audioRecognitionGeneration
            )
            return
        }

        stateStore.isAudioRecognitionRunning = true
        let startGeneration = stateStore.audioRecognitionGeneration
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await service.start(
                    expectedMIDINotes: snapshot.expectedMIDINotes,
                    wrongCandidateMIDINotes: snapshot.wrongCandidateMIDINotes,
                    generation: startGeneration,
                    suppressUntil: snapshot.suppressUntil
                )
            } catch {
                stateStore.isAudioRecognitionRunning = false
                logger.error("audio recognition start failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

