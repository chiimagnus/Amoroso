import Foundation

struct PerformanceTransportReducer {
    struct Note: Equatable, Sendable {
        let eventID: ScorePerformanceNoteEventID
        let midiNote: Int
        let velocity: UInt8
        let onTick: Int
        let offTick: Int
    }

    struct Command: Equatable, Sendable {
        enum Kind: Equatable, Sendable {
            case noteOff
            case noteOn(velocity: UInt8)
        }

        let eventID: ScorePerformanceNoteEventID
        let midiNote: Int
        let tick: Int
        let kind: Kind
    }

    struct Reduction: Equatable, Sendable {
        let commands: [Command]
        let retriggeredEventCount: Int
        let preventedStaleOffCount: Int
        let orphanOffCount: Int
    }

    func reduce(notes: [Note]) -> Reduction {
        let edges = notes.flatMap { note in
            [
                Edge(eventID: note.eventID, midiNote: note.midiNote, tick: note.onTick, kind: .on(note.velocity)),
                Edge(eventID: note.eventID, midiNote: note.midiNote, tick: note.offTick, kind: .off),
            ]
        }.sorted(by: edgeOrder)
        var activeByMIDI: [Int: [ScorePerformanceNoteEventID: Int]] = [:]
        var supersededEventIDs: Set<ScorePerformanceNoteEventID> = []
        var commands: [Command] = []
        var retriggeredEventCount = 0
        var preventedStaleOffCount = 0
        var orphanOffCount = 0

        for edge in edges {
            switch edge.kind {
            case .off:
                if supersededEventIDs.remove(edge.eventID) != nil {
                    preventedStaleOffCount += 1
                } else if activeByMIDI[edge.midiNote]?.removeValue(forKey: edge.eventID) != nil {
                    commands.append(Command(
                        eventID: edge.eventID,
                        midiNote: edge.midiNote,
                        tick: edge.tick,
                        kind: .noteOff
                    ))
                } else {
                    orphanOffCount += 1
                }
                if activeByMIDI[edge.midiNote]?.isEmpty == true {
                    activeByMIDI[edge.midiNote] = nil
                }

            case let .on(velocity):
                let retriggeredEventIDs = (activeByMIDI[edge.midiNote] ?? [:])
                    .filter { $0.value < edge.tick }
                    .map(\.key)
                    .sorted { $0.description < $1.description }
                for eventID in retriggeredEventIDs {
                    activeByMIDI[edge.midiNote]?[eventID] = nil
                    supersededEventIDs.insert(eventID)
                    retriggeredEventCount += 1
                    commands.append(Command(
                        eventID: eventID,
                        midiNote: edge.midiNote,
                        tick: edge.tick,
                        kind: .noteOff
                    ))
                }
                activeByMIDI[edge.midiNote, default: [:]][edge.eventID] = edge.tick
                commands.append(Command(
                    eventID: edge.eventID,
                    midiNote: edge.midiNote,
                    tick: edge.tick,
                    kind: .noteOn(velocity: velocity)
                ))
            }
        }

        return Reduction(
            commands: commands,
            retriggeredEventCount: retriggeredEventCount,
            preventedStaleOffCount: preventedStaleOffCount,
            orphanOffCount: orphanOffCount
        )
    }
}

private extension PerformanceTransportReducer {
    struct Edge {
        enum Kind {
            case off
            case on(UInt8)
        }

        let eventID: ScorePerformanceNoteEventID
        let midiNote: Int
        let tick: Int
        let kind: Kind
    }

    func edgeOrder(_ lhs: Edge, _ rhs: Edge) -> Bool {
        if lhs.tick != rhs.tick { return lhs.tick < rhs.tick }
        let lhsPriority = edgePriority(lhs.kind)
        let rhsPriority = edgePriority(rhs.kind)
        if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
        if lhs.midiNote != rhs.midiNote { return lhs.midiNote < rhs.midiNote }
        return lhs.eventID.description < rhs.eventID.description
    }

    func edgePriority(_ kind: Edge.Kind) -> Int {
        switch kind {
        case .off: 0
        case .on: 1
        }
    }
}
