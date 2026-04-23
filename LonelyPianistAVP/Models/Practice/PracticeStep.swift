import Foundation

struct PracticeStepNote: Equatable, Hashable, Identifiable {
    var id: Int {
        midiNote
    }

    let midiNote: Int
    let staff: Int?
    let velocity: UInt8
    let onTickOffset: Int
    let fingeringText: String?

    init(
        midiNote: Int,
        staff: Int?,
        velocity: UInt8 = 96,
        onTickOffset: Int = 0,
        fingeringText: String? = nil
    ) {
        self.midiNote = midiNote
        self.staff = staff
        self.velocity = velocity
        self.onTickOffset = onTickOffset
        self.fingeringText = fingeringText
    }
}

struct PracticeStep: Equatable, Identifiable {
    var id: Int {
        tick
    }

    let tick: Int
    let notes: [PracticeStepNote]
}

struct PracticeStepBuildResult: Equatable {
    let steps: [PracticeStep]
    let unsupportedNoteCount: Int
}
