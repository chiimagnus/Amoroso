import Foundation

enum MusicXMLHandRoutingStrategy: Equatable {
    case staffBased
    case heuristic
}

enum MusicXMLHandRoutingOverride: Codable, Equatable {
    case disableHeuristic
    case splitThresholdMIDINote(Int)

    private enum CodingKeys: String, CodingKey {
        case kind
        case threshold
    }

    private enum Kind: String, Codable {
        case disableHeuristic
        case splitThresholdMIDINote
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
            case .disableHeuristic:
                self = .disableHeuristic
            case .splitThresholdMIDINote:
                self = .splitThresholdMIDINote(try container.decode(Int.self, forKey: .threshold))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
            case .disableHeuristic:
                try container.encode(Kind.disableHeuristic, forKey: .kind)
            case let .splitThresholdMIDINote(threshold):
                try container.encode(Kind.splitThresholdMIDINote, forKey: .kind)
                try container.encode(threshold, forKey: .threshold)
        }
    }
}

struct MusicXMLHandRoutingOverrideStore {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadOverride(for file: ImportedMusicXMLFile) -> MusicXMLHandRoutingOverride? {
        guard let data = userDefaults.data(forKey: storageKey(for: file)) else { return nil }
        return try? JSONDecoder().decode(MusicXMLHandRoutingOverride.self, from: data)
    }

    func saveOverride(_ override: MusicXMLHandRoutingOverride?, for file: ImportedMusicXMLFile) {
        let key = storageKey(for: file)
        guard let override else {
            userDefaults.removeObject(forKey: key)
            return
        }
        if let data = try? JSONEncoder().encode(override) {
            userDefaults.set(data, forKey: key)
        }
    }

    private func storageKey(for file: ImportedMusicXMLFile) -> String {
        "practiceHeuristicHandRoutingOverride.\(file.storedURL.lastPathComponent)"
    }
}

struct MusicXMLHandRouter {
    nonisolated static let heuristicEnabledKey = "practiceHeuristicHandRoutingEnabled"
    private let overrideStore: MusicXMLHandRoutingOverrideStore

    init(overrideStore: MusicXMLHandRoutingOverrideStore = MusicXMLHandRoutingOverrideStore()) {
        self.overrideStore = overrideStore
    }

    func routeIfNeeded(
        score: MusicXMLScore,
        file: ImportedMusicXMLFile
    ) -> (routedScore: MusicXMLScore, strategy: MusicXMLHandRoutingStrategy) {
        let override = overrideStore.loadOverride(for: file)
        if override == .disableHeuristic {
            return (score, .staffBased)
        }

        guard Self.isHeuristicEnabled else { return (score, .staffBased) }

        let hasAnyStaffTwoOrGreater = score.notes.contains { note in
            guard note.isRest == false else { return false }
            return (note.staff ?? 1) >= 2
        }
        guard hasAnyStaffTwoOrGreater == false else { return (score, .staffBased) }

        let pitchedNotes = score.notes.compactMap { note -> Int? in
            guard note.isRest == false else { return nil }
            return note.midiNote
        }
        guard pitchedNotes.isEmpty == false else { return (score, .staffBased) }

        let minNote = pitchedNotes.min() ?? 0
        let maxNote = pitchedNotes.max() ?? 0
        if maxNote - minNote < 12 {
            return (score, .staffBased)
        }

        let threshold = {
            if case let .splitThresholdMIDINote(value) = override { return value }
            return splitThresholdMIDINote(pitchedNotes: pitchedNotes)
        }()
        let routedNotes = score.notes.map { note in
            routeNote(note, threshold: threshold)
        }

        var copy = score
        copy.notes = routedNotes
        return (copy, .heuristic)
    }

    private static var isHeuristicEnabled: Bool {
        if let stored = UserDefaults.standard.object(forKey: heuristicEnabledKey) as? Bool {
            return stored
        }
        return true
    }

    private func splitThresholdMIDINote(pitchedNotes: [Int]) -> Int {
        let sorted = pitchedNotes.sorted()
        let median = sorted[sorted.count / 2]
        if (50 ... 70).contains(median) {
            return median
        }
        return 60
    }

    private func routeNote(_ note: MusicXMLNoteEvent, threshold: Int) -> MusicXMLNoteEvent {
        guard note.isRest == false else { return note }
        guard let midiNote = note.midiNote else { return note }

        let existingStaff = note.staff ?? 1
        guard existingStaff <= 1 else { return note }

        let routedStaff = (midiNote < threshold) ? 2 : 1
        if note.staff == routedStaff {
            return note
        }

        return MusicXMLNoteEvent(
            partID: note.partID,
            measureNumber: note.measureNumber,
            tick: note.tick,
            durationTicks: note.durationTicks,
            midiNote: note.midiNote,
            isRest: note.isRest,
            isChord: note.isChord,
            isGrace: note.isGrace,
            graceSlash: note.graceSlash,
            graceStealTimePrevious: note.graceStealTimePrevious,
            graceStealTimeFollowing: note.graceStealTimeFollowing,
            tieStart: note.tieStart,
            tieStop: note.tieStop,
            staff: routedStaff,
            voice: note.voice,
            attackTicks: note.attackTicks,
            releaseTicks: note.releaseTicks,
            dynamicsOverrideVelocity: note.dynamicsOverrideVelocity,
            articulations: note.articulations,
            arpeggiate: note.arpeggiate,
            fingeringText: note.fingeringText,
            dotCount: note.dotCount
        )
    }
}
