import Foundation
@testable import LonelyPianist

@MainActor
final class BluetoothMIDIConnectionServiceMock: BluetoothMIDIConnectionServiceProtocol {
    var onConnectionStateChange: (@Sendable (BluetoothMIDIConnectionState) -> Void)?
    var onPeripheralsChange: (@Sendable ([BluetoothMIDIPeripheral]) -> Void)?

    private(set) var connectionState: BluetoothMIDIConnectionState = .idle {
        didSet { onConnectionStateChange?(connectionState) }
    }

    private(set) var scanMode: BluetoothMIDIScanMode = .midiServiceFiltered
    private(set) var discoveredPeripherals: [BluetoothMIDIPeripheral] = [] {
        didSet { onPeripheralsChange?(discoveredPeripherals) }
    }

    var mockCentralStateRawValue: Int = 0
    var mockAuthorization: String?
    var mockLastError: String?
    var mockLastActivationStatus: Int32?
    var mockLastDisconnectStatus: Int32?
    var mockTargetPeripheralID: String?

    var debugSnapshot: BluetoothMIDIDebugSnapshot {
        BluetoothMIDIDebugSnapshot(
            centralStateRawValue: mockCentralStateRawValue,
            authorization: mockAuthorization,
            isScanning: connectionState == .scanning(mode: scanMode),
            scanMode: scanMode == .midiServiceFiltered ? "midiServiceFiltered" : "allDevices",
            lastError: mockLastError,
            discoveredPeripherals: discoveredPeripherals,
            targetPeripheralID: mockTargetPeripheralID,
            connectionState: String(describing: connectionState),
            lastActivationStatus: mockLastActivationStatus,
            lastDisconnectStatus: mockLastDisconnectStatus
        )
    }

    private(set) var startScanCalls: [BluetoothMIDIScanMode] = []
    private(set) var stopScanCallCount = 0
    private(set) var connectCalls: [String] = []
    private(set) var disconnectCalls: [String] = []

    func startScan(mode: BluetoothMIDIScanMode) {
        startScanCalls.append(mode)
        scanMode = mode
        connectionState = .scanning(mode: mode)
    }

    func stopScan() {
        stopScanCallCount += 1
        connectionState = .idle
    }

    func connect(id: String) {
        connectCalls.append(id)
        mockTargetPeripheralID = id
        connectionState = .connecting(id: id)
    }

    func disconnect(id: String) {
        disconnectCalls.append(id)
        mockLastDisconnectStatus = 0
        connectionState = .disconnecting(id: id)
    }

    func setState(_ state: BluetoothMIDIConnectionState) {
        connectionState = state
    }

    func setPeripherals(_ peripherals: [BluetoothMIDIPeripheral]) {
        discoveredPeripherals = peripherals
    }
}
