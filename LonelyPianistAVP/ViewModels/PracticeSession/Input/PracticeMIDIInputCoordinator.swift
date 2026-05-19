import Foundation
import Observation
import os

@MainActor
final class PracticeMIDIInputCoordinator: PracticeMIDIInputCoordinating, PracticeSessionLifecycleProtocol {
    struct Snapshot: Equatable {
        var practiceState: PracticeSessionState
        var autoplayState: PracticeSessionAutoplayState
        var isManualReplayPlaying: Bool
        var currentStepIndex: Int
        var expectedNotes: [PracticeStepNote]
    }

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "LonelyPianistAVP",
        category: "PracticeMIDIInputCoordinator"
    )

    private let practiceInputEventSource: PracticeInputEventSourceProtocol?
    private let matcher: MIDIPracticeStepMatcher

    private var midi1EventsTask: Task<Void, Never>?
    private var midi2EventsTask: Task<Void, Never>?
    private var hasShutdown = false

    private var isRunning = false
    private var activeSinceUptimeSeconds: TimeInterval?
    private var lastResetStepIndex: Int?

    init(
        practiceInputEventSource: PracticeInputEventSourceProtocol?,
        matcher: MIDIPracticeStepMatcher,
        consumeEvents: Bool = false
    ) {
        self.practiceInputEventSource = practiceInputEventSource
        self.matcher = matcher
        if consumeEvents {
            bindStreamsIfNeeded()
        }
    }

    func shutdown() {
        guard hasShutdown == false else { return }
        hasShutdown = true
        stop()
        midi1EventsTask?.cancel()
        midi1EventsTask = nil
        midi2EventsTask?.cancel()
        midi2EventsTask = nil
    }

    func refreshForCurrentState() {
        guard let snapshot = latestSnapshot else {
            stop()
            return
        }
        refresh(for: snapshot)
    }

    func stop() {
        guard let practiceInputEventSource else { return }
        stopSourceIfNeeded(practiceInputEventSource)
        resetMatchingState()
    }

    private var latestSnapshot: Snapshot?

    func refresh(for snapshot: Snapshot) {
        latestSnapshot = snapshot
        guard let practiceInputEventSource else { return }

        guard snapshot.autoplayState == .off, snapshot.isManualReplayPlaying == false else {
            stop()
            return
        }

        guard case .guiding = snapshot.practiceState, snapshot.expectedNotes.isEmpty == false else {
            stop()
            return
        }

        if lastResetStepIndex != snapshot.currentStepIndex {
            activeSinceUptimeSeconds = ProcessInfo.processInfo.systemUptime
            matcher.reset(
                stepIndex: snapshot.currentStepIndex,
                expectedNotes: snapshot.expectedNotes,
                configuredAt: .now
            )
            lastResetStepIndex = snapshot.currentStepIndex
        }

        guard isRunning == false else { return }
        do {
            try practiceInputEventSource.start()
            isRunning = true
        } catch {
            isRunning = false
            resetMatchingState()
            logger.error("practice input start failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func bindStreamsIfNeeded() {
        guard let practiceInputEventSource else { return }
        guard midi1EventsTask == nil, midi2EventsTask == nil else { return }

        let midi1Stream = practiceInputEventSource.midi1EventsStream()
        midi1EventsTask = Task { [weak self] in
            for await _ in midi1Stream {
                await MainActor.run {
                    _ = self?.activeSinceUptimeSeconds
                }
            }
        }

        let midi2Stream = practiceInputEventSource.midi2EventsStream()
        midi2EventsTask = Task { [weak self] in
            for await _ in midi2Stream {
                await MainActor.run {
                    _ = self?.activeSinceUptimeSeconds
                }
            }
        }
    }

    private func stopSourceIfNeeded(_ practiceInputEventSource: PracticeInputEventSourceProtocol) {
        guard isRunning else { return }
        practiceInputEventSource.stop()
        isRunning = false
    }

    private func resetMatchingState() {
        activeSinceUptimeSeconds = nil
        lastResetStepIndex = nil
        matcher.reset(stepIndex: -1, expectedNotes: [], configuredAt: .now)
    }
}
