import CoreMIDI

enum MIDICanonicalChannelVoiceType: Sendable {
    case channelVoice1
    case channelVoice2
}

struct MIDICanonicalProtocolSelection: Sendable {
    static func subscribedProtocol(endpointProtocolID: MIDIProtocolID?, midi2PortAvailable: Bool) -> MIDIProtocolID {
        if endpointProtocolID == ._2_0, midi2PortAvailable {
            return ._2_0
        }
        return ._1_0
    }

    static func shouldDeliver(_ voiceType: MIDICanonicalChannelVoiceType, eventListProtocol: MIDIProtocolID) -> Bool {
        switch voiceType {
        case .channelVoice1:
            return eventListProtocol == ._1_0
        case .channelVoice2:
            return eventListProtocol == ._2_0
        }
    }
}

