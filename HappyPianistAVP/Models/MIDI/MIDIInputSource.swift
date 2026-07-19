struct MIDIInputSource: Equatable, Hashable, Sendable {
    enum Identifier: Equatable, Hashable, Sendable {
        case endpointUniqueID(Int32)
        case sourceIndex(Int)
    }

    let identifier: Identifier
    let endpointName: String?
}
