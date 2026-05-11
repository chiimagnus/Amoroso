import Foundation

enum BluetoothMIDIScanMode: Equatable, Sendable {
    case midiServiceFiltered
    case allDevices
}

enum BluetoothMIDIConnectionState: Equatable, Sendable {
    case idle
    case scanning(mode: BluetoothMIDIScanMode)
    case readyToConnect
    case connecting(id: String)
    case verifying(id: String)
    case activating(id: String)
    case activated(id: String)
    case disconnecting(id: String)
    case failed(String)
    case denied
    case poweredOff
    case unsupported
}

@MainActor
protocol BluetoothMIDIConnectionServiceProtocol: AnyObject {
    var onConnectionStateChange: (@Sendable (BluetoothMIDIConnectionState) -> Void)? { get set }
    var onPeripheralsChange: (@Sendable ([BluetoothMIDIPeripheral]) -> Void)? { get set }

    var connectionState: BluetoothMIDIConnectionState { get }
    var scanMode: BluetoothMIDIScanMode { get }
    var discoveredPeripherals: [BluetoothMIDIPeripheral] { get }

    func startScan(mode: BluetoothMIDIScanMode)
    func stopScan()

    func connect(id: String)
    func disconnect(id: String)
}

