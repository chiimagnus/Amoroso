import Foundation

struct MIDIEvent: Equatable {
    enum EventType: Equatable {
        case noteOn(note: Int, velocity: Int)
        case noteOff(note: Int, velocity: Int)
        case controlChange(controller: Int, value: Int)
    }

    let type: EventType
    let channel: Int
    let timestamp: Date
}
