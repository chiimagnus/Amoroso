import Foundation
@testable import LonelyPianistAVP
import os

final class FakeProtocolSeparatedPracticeInputEventSource: PracticeInputEventSourceProtocol {
    private let midi1Broadcaster = Broadcaster<MIDI1InputEvent>()
    private let midi2Broadcaster = Broadcaster<MIDI2InputEvent>()

    private(set) var midi1StreamCallCount = 0
    private(set) var midi2StreamCallCount = 0

    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    private(set) var isRunning = false

    func midi1EventsStream() -> AsyncStream<MIDI1InputEvent> {
        midi1StreamCallCount += 1
        return midi1Broadcaster.makeStream()
    }

    func midi2EventsStream() -> AsyncStream<MIDI2InputEvent> {
        midi2StreamCallCount += 1
        return midi2Broadcaster.makeStream()
    }

    func start() throws {
        startCallCount += 1
        isRunning = true
    }

    func stop() {
        stopCallCount += 1
        isRunning = false
    }

    func emitMIDI1(_ event: MIDI1InputEvent) {
        midi1Broadcaster.yield(event)
    }

    func emitMIDI2(_ event: MIDI2InputEvent) {
        midi2Broadcaster.yield(event)
    }
}

private final class Broadcaster<Element: Sendable> {
    private let continuations = OSAllocatedUnfairLock(initialState: [UUID: AsyncStream<Element>.Continuation]())

    func makeStream() -> AsyncStream<Element> {
        let id = UUID()
        return AsyncStream { continuation in
            continuations.withLock { state in
                state[id] = continuation
            }
            continuation.onTermination = { @Sendable _ in
                self.continuations.withLock { state in
                    state[id] = nil
                }
            }
        }
    }

    func yield(_ event: Element) {
        let snapshot = continuations.withLock { state in
            Array(state.values)
        }
        for continuation in snapshot {
            continuation.yield(event)
        }
    }
}
