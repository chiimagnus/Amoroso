import Foundation

struct RecordedNote: Identifiable, Hashable {
    var id: UUID
    var note: Int
    var velocity: Int
    var channel: Int
    var startOffsetSec: TimeInterval
    var durationSec: TimeInterval
}
