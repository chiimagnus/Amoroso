import CoreMIDI

nonisolated struct MIDICanonicalProtocolSelection: Sendable {
    static func subscribedProtocol(endpointProtocolID: MIDIProtocolID?, midi2PortAvailable: Bool) -> MIDIProtocolID {
        if endpointProtocolID == ._2_0, midi2PortAvailable {
            return ._2_0
        }
        return ._1_0
    }
}
