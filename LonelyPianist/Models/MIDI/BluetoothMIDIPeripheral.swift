import Foundation

struct BluetoothMIDIPeripheral: Identifiable, Equatable, Codable, Sendable {
    let id: String
    let name: String?
    let rssi: Int?
    let lastSeen: Date

    init(
        id: String,
        name: String?,
        rssi: Int?,
        lastSeen: Date
    ) {
        self.id = id
        self.name = name
        self.rssi = rssi
        self.lastSeen = lastSeen
    }
}

