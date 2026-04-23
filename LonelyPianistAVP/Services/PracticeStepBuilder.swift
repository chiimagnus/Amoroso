import Foundation

protocol PracticeStepBuilderProtocol {
    func buildSteps(from score: MusicXMLScore) -> PracticeStepBuildResult
}

struct PracticeStepBuilder: PracticeStepBuilderProtocol {
    private let playableRange = 21 ... 108

    func buildSteps(from score: MusicXMLScore) -> PracticeStepBuildResult {
        var grouped: [Int: [Int: (staff: Int?, velocity: UInt8)]] = [:] // tick -> midi -> (staff, velocity)
        var unsupportedNoteCount = 0
        let velocityResolver = MusicXMLVelocityResolver(dynamicEvents: score.dynamicEvents)

        for noteEvent in score.notes {
            if noteEvent.isRest {
                continue
            }

            if noteEvent.isGrace {
                continue
            }

            if noteEvent.tieStop {
                continue
            }

            guard let midiNote = noteEvent.midiNote else {
                continue
            }

            guard playableRange.contains(midiNote) else {
                unsupportedNoteCount += 1
                continue
            }

            let velocity = velocityResolver.velocity(for: noteEvent)
            var map = grouped[noteEvent.tick] ?? [:]
            if map[midiNote] == nil {
                map[midiNote] = (staff: noteEvent.staff, velocity: velocity)
            }
            grouped[noteEvent.tick] = map
        }

        let steps = grouped.keys.sorted().map { tick in
            let notesMap = grouped[tick] ?? [:]
            let notes = notesMap.keys.sorted().map { midiNote in
                let entry = notesMap[midiNote]
                return PracticeStepNote(midiNote: midiNote, staff: entry?.staff, velocity: entry?.velocity ?? 96)
            }
            return PracticeStep(tick: tick, notes: notes)
        }

        return PracticeStepBuildResult(steps: steps, unsupportedNoteCount: unsupportedNoteCount)
    }
}
