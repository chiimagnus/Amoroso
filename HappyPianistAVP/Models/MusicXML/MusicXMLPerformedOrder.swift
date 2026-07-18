import Foundation

enum MusicXMLScoreOrder: String, Codable, Equatable, Sendable {
    case written
    case performed
}

struct MusicXMLOrderSelection: Codable, Equatable, Sendable {
    let requested: MusicXMLScoreOrder
    let applied: MusicXMLScoreOrder
    let approximationReason: String?

    init(
        requested: MusicXMLScoreOrder,
        applied: MusicXMLScoreOrder,
        approximationReason: String? = nil
    ) {
        self.requested = requested
        self.applied = applied
        self.approximationReason = approximationReason
    }

    var diagnosticValue: String {
        if let approximationReason {
            return "requested=\(requested.rawValue),applied=\(applied.rawValue),approximation=\(approximationReason)"
        }
        return "requested=\(requested.rawValue),applied=\(applied.rawValue)"
    }
}
