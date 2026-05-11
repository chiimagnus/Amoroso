import Foundation
@testable import LonelyPianist
import Testing

@MainActor
@Test
func sortedPeripheralsSortsByNameThenLastSeenThenID() {
    let now = Date(timeIntervalSince1970: 10)

    let a1 = BluetoothMIDIPeripheral(id: "A1", name: "Alpha", rssi: -1, lastSeen: now.addingTimeInterval(-5))
    let a2 = BluetoothMIDIPeripheral(id: "A2", name: "alpha", rssi: -1, lastSeen: now.addingTimeInterval(-1))
    let b1 = BluetoothMIDIPeripheral(id: "B1", name: "Beta", rssi: -1, lastSeen: now.addingTimeInterval(-1))
    let z1 = BluetoothMIDIPeripheral(id: "Z1", name: nil, rssi: -1, lastSeen: now.addingTimeInterval(-1))

    let sorted = CoreBluetoothMIDIConnectionService.sortedPeripherals([b1, a1, z1, a2])

    #expect(sorted == [z1, a2, a1, b1])
}

