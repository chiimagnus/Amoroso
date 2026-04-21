import Foundation

struct RecordingTake: Identifiable, Hashable {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var durationSec: TimeInterval
    var notes: [RecordedNote]
}
