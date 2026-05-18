import CoreMIDI
@testable import LonelyPianistAVP
import Testing

@Test
func canonicalSelectionDefaultsToMIDI1() {
    #expect(MIDICanonicalProtocolSelection.subscribedProtocol(endpointProtocolID: nil, midi2PortAvailable: true) == ._1_0)
    #expect(MIDICanonicalProtocolSelection.subscribedProtocol(endpointProtocolID: nil, midi2PortAvailable: false) == ._1_0)
}

@Test
func canonicalSelectionUsesMIDI2OnlyWhenPortAvailable() {
    #expect(MIDICanonicalProtocolSelection.subscribedProtocol(endpointProtocolID: ._2_0, midi2PortAvailable: true) == ._2_0)
    #expect(MIDICanonicalProtocolSelection.subscribedProtocol(endpointProtocolID: ._2_0, midi2PortAvailable: false) == ._1_0)
    #expect(MIDICanonicalProtocolSelection.subscribedProtocol(endpointProtocolID: ._1_0, midi2PortAvailable: true) == ._1_0)
}

@Test
func canonicalShouldDeliverNeverDoubleDelivers() {
    let protocols: [MIDIProtocolID] = [._1_0, ._2_0]
    for protocolID in protocols {
        let midi1 = MIDICanonicalProtocolSelection.shouldDeliver(.channelVoice1, eventListProtocol: protocolID)
        let midi2 = MIDICanonicalProtocolSelection.shouldDeliver(.channelVoice2, eventListProtocol: protocolID)
        #expect(midi1 != midi2)
    }
}

