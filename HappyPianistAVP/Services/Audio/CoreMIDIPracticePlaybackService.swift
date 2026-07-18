import CoreMIDI
import Foundation

@MainActor
final class CoreMIDIPracticePlaybackService: PracticeSequencerPlaybackServiceProtocol {
    private let outputService: any MIDIOutputSendingProtocol
    private let destinationUniqueID: Int32
    private let outputCapabilities: PerformanceOutputCapabilities
    private let diagnosticsReporter: (any DiagnosticsReporting)?
    private let hostTimeConverter: MIDIHostTimeConverter
    private let generationGuard = MIDIPlaybackGenerationGuard()

    private let velocity: UInt8
    private let channel: UInt8

    private var loadedDurationSeconds: TimeInterval?
    private var loadedEvents: [PracticeSequencerMIDIEvent]?
    private var scheduler: MIDILookAheadScheduler?
    private var schedulerTask: Task<Void, Never>?

    private var playingOneShotNotes: Set<UInt8> = []
    private var oneShotStopTask: Task<Void, Never>?
    private var liveNotes: Set<UInt8> = []

    private var lastKnownSeconds: TimeInterval = 0
    private var playbackStartedAtUptimeSeconds: TimeInterval?
    private var playbackStartSeconds: TimeInterval = 0

    init(
        destinationUniqueID: Int32,
        outputService: (any MIDIOutputSendingProtocol)? = nil,
        diagnosticsReporter: (any DiagnosticsReporting)? = nil,
        outputCapabilities: PerformanceOutputCapabilities = .externalMIDI,
        hostTimeConverter: MIDIHostTimeConverter = MIDIHostTimeConverter(),
        velocity: UInt8 = 96,
        channel: UInt8 = 0
    ) {
        self.destinationUniqueID = destinationUniqueID
        self.outputService = outputService ?? CoreMIDIOutputService(diagnosticsReporter: diagnosticsReporter)
        self.outputCapabilities = outputCapabilities
        self.diagnosticsReporter = diagnosticsReporter
        self.hostTimeConverter = hostTimeConverter
        self.velocity = velocity
        self.channel = channel

        let generationGuard = self.generationGuard
        self.outputService.onDestinationRouteWillChange = {
            generationGuard.invalidate()
        }
        self.outputService.onDestinationRouteChange = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleDestinationRouteChange()
            }
        }
    }

    deinit {
        let hadScheduledPlayback = schedulerTask != nil
        generationGuard.invalidate()
        schedulerTask?.cancel()
        guard hadScheduledPlayback else { return }

        do {
            try outputService.flushScheduledMessages(destinationUniqueID: destinationUniqueID)
        } catch {
            diagnosticsReporter?.recordSystem(
                severity: .error,
                category: .midi,
                stage: "coreMIDI.teardownFlush",
                summary: "释放外部 MIDI 播放服务时取消未来事件失败",
                reason: String(describing: type(of: error))
            )
        }
        do {
            let hostTime = hostTimeConverter.origin(atTransportSeconds: 0).hostTime
            try outputService.sendMIDI1Messages(
                Self.fullResetMessages(channel: channel, hostTime: hostTime),
                destinationUniqueID: destinationUniqueID
            )
        } catch {
            diagnosticsReporter?.recordSystem(
                severity: .error,
                category: .midi,
                stage: "coreMIDI.teardownReset",
                summary: "释放外部 MIDI 播放服务时复位失败",
                reason: String(describing: type(of: error))
            )
        }
    }

    func warmUp() throws {
        try ensureReady()
    }

    func stop(resetCommands: [PerformanceTransportCommand]) {
        haltPlayback()
        execute(resetCommands)
    }

    func load(sequence: PracticeSequencerSequence) throws {
        try ensureReady()
        haltPlayback()
        loadedDurationSeconds = sequence.durationSeconds
        loadedEvents = sequence.events
        lastKnownSeconds = 0
        recordControllerApproximations(in: sequence.events)
    }

    func play(fromSeconds start: TimeInterval) throws {
        try ensureReady()
        guard let events = loadedEvents else { return }

        haltPlayback()

        let startSeconds = max(0, start)
        lastKnownSeconds = startSeconds
        playbackStartSeconds = startSeconds
        playbackStartedAtUptimeSeconds = ProcessInfo.processInfo.systemUptime
        let generation = generationGuard.beginGeneration()

        let scheduler = MIDILookAheadScheduler(
            outputService: outputService,
            destinationUniqueID: destinationUniqueID,
            channel: channel,
            outputCapabilities: outputCapabilities,
            hostTimeConverter: hostTimeConverter,
            diagnosticsReporter: diagnosticsReporter,
            generationGuard: generationGuard,
            generation: generation
        )
        self.scheduler = scheduler
        schedulerTask = scheduler.start(events: events, fromSeconds: startSeconds)
    }

    private func haltPlayback() {
        generationGuard.invalidate()
        oneShotStopTask?.cancel()
        oneShotStopTask = nil

        if let playbackStartedAtUptimeSeconds {
            lastKnownSeconds = playbackStartSeconds + max(0, ProcessInfo.processInfo.systemUptime - playbackStartedAtUptimeSeconds)
        }
        playbackStartedAtUptimeSeconds = nil

        let hadScheduledPlayback = schedulerTask != nil
        schedulerTask?.cancel()
        schedulerTask = nil
        scheduler = nil

        if hadScheduledPlayback {
            do {
                try outputService.flushScheduledMessages(destinationUniqueID: destinationUniqueID)
            } catch {
                diagnosticsReporter?.recordSystem(
                    severity: .error,
                    category: .midi,
                    stage: "coreMIDI.playbackFlush",
                    summary: "停止外部 MIDI 播放时取消未来事件失败",
                    reason: String(describing: type(of: error))
                )
            }
        }

        liveNotes.removeAll()
        playingOneShotNotes.removeAll()
    }

    private func handleDestinationRouteChange() {
        guard schedulerTask != nil else { return }
        haltPlayback()
        execute(PerformanceTransportReducer.fullResetCommands)
    }

    nonisolated private static func fullResetMessages(
        channel: UInt8,
        hostTime: MIDITimeStamp
    ) -> [TimestampedMIDI1Message] {
        let status = 0xB0 | (channel & 0x0F)
        return [64, 66, 67, 123, 120].map { controller in
            TimestampedMIDI1Message(
                hostTime: hostTime,
                bytes: [status, UInt8(controller), 0]
            )
        }
    }

    func currentSeconds() -> TimeInterval {
        guard let playbackStartedAtUptimeSeconds else { return lastKnownSeconds }
        let now = ProcessInfo.processInfo.systemUptime
        let seconds = playbackStartSeconds + max(0, now - playbackStartedAtUptimeSeconds)
        if let loadedDurationSeconds {
            return min(seconds, loadedDurationSeconds)
        }
        return seconds
    }

    func playOneShot(noteOns: [PracticeOneShotNoteOn], durationSeconds: TimeInterval) throws {
        let notes = noteOns.compactMap { noteOn -> (note: UInt8, velocity: UInt8)? in
            guard let note = UInt8(exactly: noteOn.midiNote) else { return nil }
            return (note, noteOn.velocity)
        }
        guard notes.isEmpty == false else { return }

        try ensureReady()

        oneShotStopTask?.cancel()
        oneShotStopTask = nil

        stopOneShotNotes()

        for (note, velocity) in notes {
            try? outputService.sendNoteOn(
                note: note,
                velocity: velocity,
                channel: channel,
                destinationUniqueID: destinationUniqueID
            )
            playingOneShotNotes.insert(note)
        }

        oneShotStopTask = Task.detached(priority: .userInitiated) { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, durationSeconds)))
            guard Task.isCancelled == false else { return }
            await MainActor.run { [weak self] in
                self?.stopOneShotNotes()
            }
        }
    }

    func startLiveNotes(midiNotes: Set<Int>) throws {
        try ensureReady()
        for midiNote in midiNotes {
            guard let note = UInt8(exactly: midiNote), liveNotes.contains(note) == false else { continue }
            try? outputService.sendNoteOn(
                note: note,
                velocity: velocity,
                channel: channel,
                destinationUniqueID: destinationUniqueID
            )
            liveNotes.insert(note)
        }
    }

    func stopLiveNotes(midiNotes: Set<Int>) {
        for midiNote in midiNotes {
            guard let note = UInt8(exactly: midiNote), liveNotes.contains(note) else { continue }
            try? outputService.sendNoteOff(note: note, channel: channel, destinationUniqueID: destinationUniqueID)
            liveNotes.remove(note)
        }
    }

    func stopAllLiveNotes() {
        for note in liveNotes {
            try? outputService.sendNoteOff(note: note, channel: channel, destinationUniqueID: destinationUniqueID)
        }
        liveNotes.removeAll()
    }

    private func stopOneShotNotes() {
        for note in playingOneShotNotes {
            try? outputService.sendNoteOff(note: note, channel: channel, destinationUniqueID: destinationUniqueID)
        }
        playingOneShotNotes.removeAll()
    }

    private func execute(_ commands: [PerformanceTransportCommand]) {
        for command in commands {
            switch command {
            case let .noteOff(eventID):
                guard let note = loadedEvents?.lazy.compactMap({ event -> UInt8? in
                    guard event.sourceEventID == eventID.description,
                          case let .noteOn(midi, _) = event.kind
                    else { return nil }
                    return UInt8(exactly: midi)
                }).first else { continue }
                try? outputService.sendNoteOff(
                    note: note,
                    channel: channel,
                    destinationUniqueID: destinationUniqueID
                )
            case let .controlChange(controller, value):
                let resolution = outputCapabilities.resolve(controllerNumber: controller, value: value)
                try? outputService.sendControlChange(
                    controller: controller,
                    value: resolution.value,
                    channel: channel,
                    destinationUniqueID: destinationUniqueID
                )
            case .allNotesOff:
                try? outputService.sendAllNotesOff(channel: channel, destinationUniqueID: destinationUniqueID)
            case .allSoundOff:
                try? outputService.sendAllSoundOff(channel: channel, destinationUniqueID: destinationUniqueID)
            }
        }
    }

    private func ensureReady() throws {
        try outputService.start()
    }

    private func recordControllerApproximations(in events: [PracticeSequencerMIDIEvent]) {
        let count = events.reduce(into: 0) { count, event in
            guard case let .controlChange(controller, value) = event.kind,
                  outputCapabilities.resolve(controllerNumber: controller, value: value).approximation != nil
            else { return }
            count += 1
        }
        guard count > 0 else { return }
        diagnosticsReporter?.recordSystem(
            severity: .info,
            category: .midi,
            stage: "coreMIDI.controllerCapability",
            summary: "外部 MIDI 控制器值已按输出能力量化",
            reason: "approximationCount=\(count)"
        )
    }
}
