import Foundation
@testable import LonelyPianist
import Testing

@MainActor
@Test
func startScanPublishesStateChange() {
    let service = BluetoothMIDIConnectionServiceMock()

    var received: [BluetoothMIDIConnectionState] = []
    service.onConnectionStateChange = { received.append($0) }

    service.startScan(mode: .midiServiceFiltered)

    #expect(service.startScanCalls == [.midiServiceFiltered])
    #expect(service.connectionState == .scanning(mode: .midiServiceFiltered))
    #expect(received.last == .scanning(mode: .midiServiceFiltered))
}

@MainActor
@Test
func setPeripheralsPublishesListChange() {
    let service = BluetoothMIDIConnectionServiceMock()

    var received: [[BluetoothMIDIPeripheral]] = []
    service.onPeripheralsChange = { received.append($0) }

    let peripheral = BluetoothMIDIPeripheral(id: "A", name: "Piano", rssi: -42, lastSeen: Date(timeIntervalSince1970: 1))
    service.setPeripherals([peripheral])

    #expect(service.discoveredPeripherals == [peripheral])
    #expect(received.last == [peripheral])
}

