import Foundation

struct MappingConfigPayload: Codable, Hashable {
    var velocityEnabled: Bool
    var defaultVelocityThreshold: Int
    var singleKeyRules: [SingleKeyMappingRule]
    var chordRules: [ChordMappingRule]

    static let empty = MappingConfigPayload(
        velocityEnabled: false,
        defaultVelocityThreshold: 90,
        singleKeyRules: [],
        chordRules: []
    )
}

struct MappingConfig: Identifiable, Hashable {
    var id: UUID
    var updatedAt: Date
    var payload: MappingConfigPayload
}
