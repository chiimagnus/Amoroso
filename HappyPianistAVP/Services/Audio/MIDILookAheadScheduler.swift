import CoreMIDI
import Foundation

protocol MIDILookAheadClock: Sendable {
    func nowSeconds() -> TimeInterval
    func sleep(for seconds: TimeInterval) async throws
}

struct SystemMIDILookAheadClock: MIDILookAheadClock {
    func nowSeconds() -> TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }

    func sleep(for seconds: TimeInterval) async throws {
        try await Task.sleep(for: .seconds(max(0, seconds)))
    }
}

struct MIDILookAheadConfiguration: Equatable, Sendable {
    let horizonSeconds: TimeInterval
    let refillIntervalSeconds: TimeInterval

    static let standard = MIDILookAheadConfiguration(
        horizonSeconds: 0.1,
        refillIntervalSeconds: 0.025
    )
}

actor MIDILookAheadScheduler {
    private let outputService: any MIDIOutputSendingProtocol
    private let destinationUniqueID: Int32
    private let channel: UInt8
    private let outputCapabilities: PerformanceOutputCapabilities
    private let hostTimeConverter: MIDIHostTimeConverter
    private let clock: any MIDILookAheadClock
    private let configuration: MIDILookAheadConfiguration
    private let diagnosticsReporter: (any DiagnosticsReporting)?

    init(
        outputService: any MIDIOutputSendingProtocol,
        destinationUniqueID: Int32,
        channel: UInt8,
        outputCapabilities: PerformanceOutputCapabilities,
        hostTimeConverter: MIDIHostTimeConverter,
        clock: any MIDILookAheadClock = SystemMIDILookAheadClock(),
        configuration: MIDILookAheadConfiguration = .standard,
        diagnosticsReporter: (any DiagnosticsReporting)? = nil
    ) {
        self.outputService = outputService
        self.destinationUniqueID = destinationUniqueID
        self.channel = channel
        self.outputCapabilities = outputCapabilities
        self.hostTimeConverter = hostTimeConverter
        self.clock = clock
        self.configuration = MIDILookAheadConfiguration(
            horizonSeconds: max(0.001, configuration.horizonSeconds),
            refillIntervalSeconds: max(0.001, configuration.refillIntervalSeconds)
        )
        self.diagnosticsReporter = diagnosticsReporter
    }

    nonisolated func start(
        events: [PracticeSequencerMIDIEvent],
        fromSeconds startSeconds: TimeInterval
    ) -> Task<Void, Never> {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                try await self.run(events: events, fromSeconds: max(0, startSeconds))
            } catch is CancellationError {
                return
            } catch {
                await self.recordSendFailure(error)
            }
        }
    }

    private func run(
        events: [PracticeSequencerMIDIEvent],
        fromSeconds startSeconds: TimeInterval
    ) async throws {
        let pendingEvents = events.enumerated()
            .filter { $0.element.timeSeconds >= startSeconds }
            .sorted { lhs, rhs in
                if lhs.element.timeSeconds != rhs.element.timeSeconds {
                    return lhs.element.timeSeconds < rhs.element.timeSeconds
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
        guard pendingEvents.isEmpty == false else { return }

        let startedAtSeconds = clock.nowSeconds()
        let hostTimeOrigin = hostTimeConverter.origin(atTransportSeconds: startSeconds)
        var nextEventIndex = 0

        while nextEventIndex < pendingEvents.count {
            try Task.checkCancellation()

            let elapsedSeconds = max(0, clock.nowSeconds() - startedAtSeconds)
            let transportNowSeconds = startSeconds + elapsedSeconds
            let horizonEndSeconds = transportNowSeconds + configuration.horizonSeconds
            var messages: [TimestampedMIDI1Message] = []

            while nextEventIndex < pendingEvents.count,
                  pendingEvents[nextEventIndex].timeSeconds <= horizonEndSeconds
            {
                let event = pendingEvents[nextEventIndex]
                if let bytes = Self.messageBytes(
                    for: event,
                    channel: channel,
                    outputCapabilities: outputCapabilities
                ) {
                    let scheduledSeconds = max(event.timeSeconds, transportNowSeconds)
                    messages.append(TimestampedMIDI1Message(
                        hostTime: hostTimeConverter.hostTime(
                            atTransportSeconds: scheduledSeconds,
                            relativeTo: hostTimeOrigin
                        ),
                        bytes: bytes
                    ))
                }
                nextEventIndex += 1
            }

            if messages.isEmpty == false {
                try Task.checkCancellation()
                try outputService.sendMIDI1Messages(
                    messages,
                    destinationUniqueID: destinationUniqueID
                )
            }

            guard nextEventIndex < pendingEvents.count else { return }
            let nextRefillSeconds = min(
                pendingEvents[nextEventIndex].timeSeconds - configuration.horizonSeconds,
                transportNowSeconds + configuration.refillIntervalSeconds
            )
            let sleepSeconds = max(0, nextRefillSeconds - transportNowSeconds)
            if sleepSeconds == 0 {
                await Task.yield()
            } else {
                try await clock.sleep(for: sleepSeconds)
            }
        }
    }

    private func recordSendFailure(_ error: any Error) {
        diagnosticsReporter?.recordSystem(
            severity: .error,
            category: .midi,
            stage: "coreMIDI.lookAheadSend",
            summary: "CoreMIDI look-ahead 批次发送失败",
            reason: String(describing: type(of: error))
        )
    }

    private static func messageBytes(
        for event: PracticeSequencerMIDIEvent,
        channel: UInt8,
        outputCapabilities: PerformanceOutputCapabilities
    ) -> [UInt8]? {
        let statusChannel = channel & 0x0F
        switch event.kind {
        case let .noteOn(midi, velocity):
            guard let note = UInt8(exactly: midi) else { return nil }
            return [0x90 | statusChannel, note, velocity]
        case let .noteOff(midi):
            guard let note = UInt8(exactly: midi) else { return nil }
            return [0x80 | statusChannel, note, 0]
        case let .controlChange(controller, value):
            let resolution = outputCapabilities.resolve(controllerNumber: controller, value: value)
            return [0xB0 | statusChannel, controller, resolution.value]
        case let .programChange(program):
            return [0xC0 | statusChannel, program]
        case let .pitchBend(value):
            return [0xE0 | statusChannel, UInt8(value & 0x7F), UInt8((value >> 7) & 0x7F)]
        case let .channelPressure(value):
            return [0xD0 | statusChannel, value]
        case let .polyPressure(midi, value):
            guard let note = UInt8(exactly: midi) else { return nil }
            return [0xA0 | statusChannel, note, value]
        }
    }
}
