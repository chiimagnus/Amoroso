import AudioToolbox
import AVFAudio
import Foundation

struct PracticeSequencerSequence: Sendable {
    let midiData: Data
    let durationSeconds: TimeInterval
    let events: [PracticeSequencerMIDIEvent]
    let outputApproximations: [PerformanceOutputApproximation]

    init(
        midiData: Data,
        durationSeconds: TimeInterval,
        events: [PracticeSequencerMIDIEvent],
        outputApproximations: [PerformanceOutputApproximation] = []
    ) {
        self.midiData = midiData
        self.durationSeconds = durationSeconds
        self.events = events
        self.outputApproximations = outputApproximations
    }
}

struct PracticePlaybackCommand: Equatable, Sendable {
    let sourceEventID: String
    let kind: PracticeSequencerMIDIEvent.Kind
}

protocol PracticeSequencerPlaybackServiceProtocol: AnyObject {
    func warmUp() async throws
    func stop(resetCommands: [PerformanceTransportCommand]) async
    func load(sequence: PracticeSequencerSequence) async throws
    func play(fromSeconds start: TimeInterval) async throws
    func currentSeconds() async -> TimeInterval
    func playOneShot(commands: [PracticePlaybackCommand], durationSeconds: TimeInterval) async throws
    func execute(commands: [PracticePlaybackCommand]) async throws
    func stopAllLiveNotes() async
}

actor AVAudioSequencerPracticePlaybackService: PracticeSequencerPlaybackServiceProtocol {
    private let engine: AVAudioEngine
    private let sampler: AVAudioUnitSampler
    private let sequencer: AVAudioSequencer
    private let userDefaults: UserDefaults

    private let soundFontResourceName: String
    private let program: UInt8
    private let channel: UInt8

    private var isReady = false
    private var currentAudioOutputVolume: Float?
    private var volumeObservationTask: Task<Void, Never>?
    private var oneShotNoteBySourceEventID: [String: UInt8] = [:]
    private var oneShotStopTask: Task<Void, Never>?
    private var liveNoteBySourceEventID: [String: UInt8] = [:]
    private var noteBySourceEventID: [String: UInt8] = [:]
    private var audioSessionEventTasks: [Task<Void, Never>] = []

    init(
        soundFontResourceName: String,
        userDefaults: UserDefaults = .standard,
        program: UInt8 = 0,
        channel: UInt8 = 0
    ) {
        engine = AVAudioEngine()
        sampler = AVAudioUnitSampler()
        sequencer = AVAudioSequencer(audioEngine: engine)
        self.userDefaults = userDefaults

        self.soundFontResourceName = soundFontResourceName
        self.program = program
        self.channel = channel

        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)

        let initialVolume = AudioOutputVolumeSettings.readAudioOutputVolume(from: userDefaults)
        currentAudioOutputVolume = initialVolume
        engine.mainMixerNode.outputVolume = initialVolume
    }

    deinit {
        volumeObservationTask?.cancel()
        oneShotStopTask?.cancel()
        for task in audioSessionEventTasks { task.cancel() }
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
        applyAudioOutputVolumeIfNeeded()

        haltPlayback()

        try sequencer.load(from: sequence.midiData, options: [])
        noteBySourceEventID = Dictionary(
            sequence.events.compactMap { event -> (String, UInt8)? in
                guard let sourceEventID = event.sourceEventID,
                      case let .noteOn(midi, _) = event.kind,
                      let note = UInt8(exactly: midi)
                else { return nil }
                return (sourceEventID, note)
            },
            uniquingKeysWith: { first, _ in first }
        )
        sequencer.currentPositionInSeconds = 0

        for track in sequencer.tracks {
            track.destinationAudioUnit = sampler
        }

        sequencer.tempoTrack.destinationAudioUnit = sampler
        sequencer.prepareToPlay()
    }

    func play(fromSeconds start: TimeInterval) throws {
        try ensureReady()
        applyAudioOutputVolumeIfNeeded()

        sequencer.currentPositionInSeconds = max(0, start)
        try sequencer.start()
    }

    func currentSeconds() -> TimeInterval {
        sequencer.currentPositionInSeconds
    }

    func playOneShot(commands: [PracticePlaybackCommand], durationSeconds: TimeInterval) throws {
        guard commands.isEmpty == false else { return }

        try ensureReady()
        applyAudioOutputVolumeIfNeeded()

        oneShotStopTask?.cancel()
        oneShotStopTask = nil

        stopOneShotNotes()

        try execute(commands: commands, tracking: .oneShot)

        oneShotStopTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: .seconds(max(0, durationSeconds)))
            } catch {
                return
            }
            await self.stopOneShotNotes()
        }
    }

    func execute(commands: [PracticePlaybackCommand]) throws {
        try ensureReady()
        applyAudioOutputVolumeIfNeeded()
        try execute(commands: commands, tracking: .live)
    }

    func stopAllLiveNotes() {
        guard isReady else { return }
        for note in Set(liveNoteBySourceEventID.values) {
            sampler.stopNote(note, onChannel: channel)
        }
        liveNoteBySourceEventID.removeAll()
    }

    private func stopOneShotNotes() {
        guard isReady else { return }

        for note in Set(oneShotNoteBySourceEventID.values) {
            sampler.stopNote(note, onChannel: channel)
        }
        oneShotNoteBySourceEventID.removeAll()
    }

    private func haltPlayback() {
        oneShotStopTask?.cancel()
        oneShotStopTask = nil
        sequencer.stop()
        oneShotNoteBySourceEventID.removeAll()
        liveNoteBySourceEventID.removeAll()
    }

    private enum CommandTracking {
        case live
        case oneShot
    }

    private func execute(
        commands: [PracticePlaybackCommand],
        tracking: CommandTracking
    ) throws {
        for command in commands {
            switch command.kind {
            case let .noteOn(midi, velocity):
                guard let note = UInt8(exactly: midi) else { continue }
                sampler.startNote(note, withVelocity: velocity, onChannel: channel)
                switch tracking {
                case .live:
                    liveNoteBySourceEventID[command.sourceEventID] = note
                case .oneShot:
                    oneShotNoteBySourceEventID[command.sourceEventID] = note
                }

            case let .noteOff(midi):
                let trackedNote: UInt8?
                switch tracking {
                case .live:
                    trackedNote = liveNoteBySourceEventID.removeValue(forKey: command.sourceEventID)
                case .oneShot:
                    trackedNote = oneShotNoteBySourceEventID.removeValue(forKey: command.sourceEventID)
                }
                guard let note = trackedNote ?? UInt8(exactly: midi) else { continue }
                sampler.stopNote(note, onChannel: channel)

            case let .controlChange(controller, value):
                try sendMIDI(status: 0xB0 | channel, data1: controller, data2: value)
            case let .programChange(program):
                try sendMIDI(status: 0xC0 | channel, data1: program, data2: 0)
            case let .pitchBend(value):
                try sendMIDI(
                    status: 0xE0 | channel,
                    data1: UInt8(value & 0x7F),
                    data2: UInt8((value >> 7) & 0x7F)
                )
            case let .channelPressure(value):
                try sendMIDI(status: 0xD0 | channel, data1: value, data2: 0)
            case let .polyPressure(midi, value):
                guard let note = UInt8(exactly: midi) else { continue }
                try sendMIDI(status: 0xA0 | channel, data1: note, data2: value)
            }
        }
    }

    private func sendMIDI(status: UInt8, data1: UInt8, data2: UInt8) throws {
        let result = MusicDeviceMIDIEvent(
            sampler.audioUnit,
            UInt32(status),
            UInt32(data1),
            UInt32(data2),
            0
        )
        guard result == noErr else {
            throw PracticeAudioError.soundFontLoadFailed(
                resourceName: soundFontResourceName,
                detail: "MusicDeviceMIDIEvent failed: \(result)"
            )
        }
    }

    private func execute(_ commands: [PerformanceTransportCommand]) {
        guard isReady else { return }
        for command in commands {
            switch command {
            case let .noteOff(eventID):
                guard let note = noteBySourceEventID[eventID.description] else { continue }
                _ = MusicDeviceMIDIEvent(sampler.audioUnit, UInt32(0x80 | channel), UInt32(note), 0, 0)
            case let .controlChange(controller, value):
                _ = MusicDeviceMIDIEvent(
                    sampler.audioUnit,
                    UInt32(0xB0 | channel),
                    UInt32(controller),
                    UInt32(value),
                    0
                )
            case .allNotesOff:
                _ = MusicDeviceMIDIEvent(sampler.audioUnit, UInt32(0xB0 | channel), 123, 0, 0)
            case .allSoundOff:
                _ = MusicDeviceMIDIEvent(sampler.audioUnit, UInt32(0xB0 | channel), 120, 0, 0)
            }
        }
    }

    private func ensureReady() throws {
        startObservingLifecycleIfNeeded()

        func configureSessionBestEffort() {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers])
            try? session.setActive(true)
        }

        if isReady {
            if engine.isRunning == false {
                configureSessionBestEffort()
                do {
                    applyAudioOutputVolumeIfNeeded()
                    engine.prepare()
                    try engine.start()
                } catch {
                    throw PracticeAudioError.soundFontLoadFailed(
                        resourceName: soundFontResourceName,
                        detail: error.localizedDescription
                    )
                }
            }
            return
        }

        guard let url = Bundle.main.url(forResource: soundFontResourceName, withExtension: "sf2") else {
            throw PracticeAudioError.soundFontMissing(resourceName: soundFontResourceName)
        }

        do {
            configureSessionBestEffort()

            try sampler.loadSoundBankInstrument(
                at: url,
                program: program,
                bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                bankLSB: 0
            )
            applyAudioOutputVolumeIfNeeded()
            engine.prepare()
            try engine.start()
            isReady = true
        } catch {
            throw PracticeAudioError.soundFontLoadFailed(
                resourceName: soundFontResourceName,
                detail: error.localizedDescription
            )
        }
    }

    private func startObservingLifecycleIfNeeded() {
        guard volumeObservationTask == nil, audioSessionEventTasks.isEmpty else { return }
        volumeObservationTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: UserDefaults.didChangeNotification) {
                guard let self else { return }
                await self.applyAudioOutputVolumeIfNeeded()
            }
        }
        let notificationCenter = NotificationCenter.default
        audioSessionEventTasks = [
            Task { [weak self] in
                for await notification in notificationCenter.notifications(named: AVAudioSession.interruptionNotification) {
                    guard let self,
                          let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                          rawType == AVAudioSession.InterruptionType.began.rawValue
                    else { continue }
                    await self.stop(resetCommands: PerformanceTransportReducer.fullResetCommands)
                }
            },
            Task { [weak self] in
                for await _ in notificationCenter.notifications(named: AVAudioSession.routeChangeNotification) {
                    guard let self else { return }
                    await self.stop(resetCommands: PerformanceTransportReducer.fullResetCommands)
                }
            },
        ]
    }

    private func applyAudioOutputVolumeIfNeeded() {
        let volume = AudioOutputVolumeSettings.readAudioOutputVolume(from: userDefaults)
        guard currentAudioOutputVolume != volume else { return }
        currentAudioOutputVolume = volume
        engine.mainMixerNode.outputVolume = volume
    }
}
