import Foundation

struct MusicXMLPracticePartSelector {
    func select(from score: MusicXMLScore) -> MusicXMLPracticePartSelection {
        let playable = score.logicalInstruments.filter { instrument in
            score.notes.contains { note in
                instrument.memberPartIDs.contains(note.partID) && note.isRest == false && note.midiNote != nil
            }
        }
        let explicitPianos = playable.filter { $0.classification == .piano }

        if explicitPianos.count == 1, let piano = explicitPianos.first {
            return .selected(piano)
        }
        if explicitPianos.count > 1 {
            return .ambiguous(MusicXMLPartSelectionAmbiguity(
                candidateInstrumentIDs: explicitPianos.map(\.id).sorted(),
                reason: "multiple-explicit-piano-instruments"
            ))
        }
        if playable.count == 1, let only = playable.first {
            return .selected(only)
        }
        if playable.isEmpty {
            return .unavailable
        }
        return .ambiguous(MusicXMLPartSelectionAmbiguity(
            candidateInstrumentIDs: playable.map(\.id).sorted(),
            reason: "multiple-playable-instruments-without-piano-evidence"
        ))
    }
}
