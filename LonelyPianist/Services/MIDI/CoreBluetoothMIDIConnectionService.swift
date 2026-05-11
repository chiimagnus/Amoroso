import CoreBluetooth
import CoreMIDI
import Foundation
import OSLog

@MainActor
final class CoreBluetoothMIDIConnectionService: NSObject, BluetoothMIDIConnectionServiceProtocol {
    private enum Constants {
        static let bleMIDIServiceUUID = "03B80E5A-EDE8-4B33-A751-6CE34EC4C700"
        static let bleMIDICharacteristicUUID = "7772E5DB-3868-4112-A1A9-F2669D106BF3"
    }

    var onConnectionStateChange: (@Sendable (BluetoothMIDIConnectionState) -> Void)?
    var onPeripheralsChange: (@Sendable ([BluetoothMIDIPeripheral]) -> Void)?

    private(set) var connectionState: BluetoothMIDIConnectionState = .idle {
        didSet {
            onConnectionStateChange?(connectionState)
        }
    }

    private(set) var scanMode: BluetoothMIDIScanMode = .midiServiceFiltered

    private(set) var discoveredPeripherals: [BluetoothMIDIPeripheral] = [] {
        didSet {
            onPeripheralsChange?(discoveredPeripherals)
        }
    }

    private let logger = Logger(subsystem: "com.chiimagnus.LonelyPianist", category: "BluetoothMIDI")

    private let settings: AppSettingsProtocol

    private lazy var central: CBCentralManager = {
        CBCentralManager(delegate: self, queue: .main)
    }()

    private let bleMIDIService = CBUUID(string: Constants.bleMIDIServiceUUID)
    private let bleMIDICharacteristic = CBUUID(string: Constants.bleMIDICharacteristicUUID)

    private var peripheralsByID: [String: CBPeripheral] = [:]
    private var activePeripheral: CBPeripheral?
    private var targetPeripheralID: String?
    private var lastError: String?
    private var lastActivationStatus: OSStatus?
    private var lastDisconnectStatus: OSStatus?
    private var pendingAutoConnect = false
    private var scanTimeoutTask: Task<Void, Never>?

    init(settings: AppSettingsProtocol) {
        self.settings = settings
        super.init()
        _ = central
    }

    var debugSnapshot: BluetoothMIDIDebugSnapshot {
        BluetoothMIDIDebugSnapshot(
            centralStateRawValue: central.state.rawValue,
            authorization: String(describing: CBManager.authorization),
            isScanning: central.isScanning,
            scanMode: scanMode == .midiServiceFiltered ? "midiServiceFiltered" : "allDevices",
            lastError: lastError,
            discoveredPeripherals: discoveredPeripherals,
            targetPeripheralID: targetPeripheralID,
            connectionState: String(describing: connectionState),
            lastActivationStatus: lastActivationStatus,
            lastDisconnectStatus: lastDisconnectStatus
        )
    }

    func startScan(mode: BluetoothMIDIScanMode) {
        scanMode = mode

        switch central.state {
            case .poweredOn:
                break
            case .poweredOff:
                lastError = "Bluetooth powered off"
                connectionState = .poweredOff
                logger.warning("Bluetooth powered off")
                return
            case .unauthorized:
                lastError = "Bluetooth unauthorized"
                connectionState = .denied
                logger.warning("Bluetooth unauthorized")
                return
            case .unsupported:
                lastError = "Bluetooth unsupported"
                connectionState = .unsupported
                logger.error("Bluetooth unsupported")
                return
            case .resetting, .unknown:
                let state = central.state
                lastError = "Bluetooth not ready (\(state.rawValue))"
                connectionState = .failed("Bluetooth not ready (\(state.rawValue))")
                logger.warning("Bluetooth not ready: \(state.rawValue, privacy: .public)")
                return
            @unknown default:
                lastError = "Bluetooth state unknown"
                connectionState = .failed("Bluetooth state unknown")
                logger.warning("Bluetooth state unknown")
                return
        }

        stopScan()
        clearDiscoveredPeripherals()
        lastError = nil
        scanTimeoutTask?.cancel()
        scanTimeoutTask = nil

        let services = (mode == .midiServiceFiltered) ? [bleMIDIService] : nil
        logger.info("Start scan (mode: \(String(describing: mode), privacy: .public))")
        central.scanForPeripherals(withServices: services, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: true,
        ])
        connectionState = .scanning(mode: mode)

        scanTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            await MainActor.run { [weak self] in
                guard let self else { return }
                guard case .scanning = connectionState else { return }
                logger.info("Scan timeout reached, stopping scan")
                stopScan()
            }
        }
    }

    func stopScan() {
        guard central.isScanning else { return }
        central.stopScan()
        scanTimeoutTask?.cancel()
        scanTimeoutTask = nil
        logger.info("Stop scan")
        if case .scanning = connectionState {
            connectionState = discoveredPeripherals.isEmpty ? .idle : .readyToConnect
        }
    }

    func connect(id: String) {
        switch central.state {
            case .poweredOn:
                break
            case .poweredOff:
                lastError = "Bluetooth powered off"
                connectionState = .poweredOff
                logger.warning("Bluetooth powered off")
                return
            case .unauthorized:
                lastError = "Bluetooth unauthorized"
                connectionState = .denied
                logger.warning("Bluetooth unauthorized")
                return
            case .unsupported:
                lastError = "Bluetooth unsupported"
                connectionState = .unsupported
                logger.error("Bluetooth unsupported")
                return
            case .resetting, .unknown:
                let state = central.state
                lastError = "Bluetooth not ready (\(state.rawValue))"
                connectionState = .failed("Bluetooth not ready (\(state.rawValue))")
                logger.warning("Bluetooth not ready: \(state.rawValue, privacy: .public)")
                return
            @unknown default:
                lastError = "Bluetooth state unknown"
                connectionState = .failed("Bluetooth state unknown")
                logger.warning("Bluetooth state unknown")
                return
        }

        if let targetPeripheralID, targetPeripheralID != id {
            disconnect(id: targetPeripheralID)
        }

        if let activePeripheral, activePeripheral.identifier.uuidString != id {
            logger.info("Disconnect active peripheral before connecting new target")
            disconnect(id: activePeripheral.identifier.uuidString)
        }

        guard let peripheral = peripheralsByID[id] else {
            lastError = "Peripheral not found: \(id)"
            connectionState = .failed("Peripheral not found: \(id)")
            logger.error("Peripheral not found: \(id, privacy: .public)")
            return
        }

        stopScan()

        targetPeripheralID = id
        lastError = nil
        activePeripheral = peripheral
        peripheral.delegate = self
        connectionState = .connecting(id: id)
        logger.info("Connect: \(id, privacy: .public) name=\(peripheral.name ?? "(nil)", privacy: .public)")
        central.connect(peripheral, options: nil)
    }

    func disconnect(id: String) {
        disconnect(id: id, setIdleWhenDone: true)
    }

    func attemptAutoConnect() {
        guard settings.rememberLastBluetoothMIDIDevice else { return }
        guard let id = settings.lastBluetoothMIDIPeripheralID else { return }

        guard CBManager.authorization == .allowedAlways else { return }
        guard central.state == .poweredOn else {
            pendingAutoConnect = true
            return
        }

        guard let uuid = UUID(uuidString: id) else {
            logger.warning("Invalid saved peripheral UUID: \(id, privacy: .public)")
            return
        }

        guard connectionState == .idle || connectionState == .readyToConnect else { return }

        attemptAutoConnectNow(id: id, uuid: uuid)
    }

    private func attemptAutoConnectNow(id: String, uuid: UUID) {
        pendingAutoConnect = false
        targetPeripheralID = id
        connectionState = .connecting(id: id)
        logger.info("Auto connect attempt: \(id, privacy: .public)")

        let peripherals = central.retrievePeripherals(withIdentifiers: [uuid])
        guard let peripheral = peripherals.first else {
            lastError = "Auto connect failed: peripheral not found"
            connectionState = .idle
            return
        }

        peripheralsByID[id] = peripheral
        activePeripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
    }

    private func clearDiscoveredPeripherals() {
        peripheralsByID.removeAll(keepingCapacity: false)
        discoveredPeripherals.removeAll(keepingCapacity: false)
    }

    private func updateDiscovered(peripheral: CBPeripheral, rssi: NSNumber) {
        let id = peripheral.identifier.uuidString
        peripheralsByID[id] = peripheral

        let item = BluetoothMIDIPeripheral(
            id: id,
            name: peripheral.name,
            rssi: rssi.intValue,
            lastSeen: .now
        )

        if let index = discoveredPeripherals.firstIndex(where: { $0.id == id }) {
            discoveredPeripherals[index] = item
        } else {
            discoveredPeripherals.append(item)
        }

        discoveredPeripherals = Self.sortedPeripherals(discoveredPeripherals)
    }

    static func sortedPeripherals(_ peripherals: [BluetoothMIDIPeripheral]) -> [BluetoothMIDIPeripheral] {
        peripherals.sorted { lhs, rhs in
            let leftName = lhs.name ?? ""
            let rightName = rhs.name ?? ""

            let nameCompare = leftName.localizedCaseInsensitiveCompare(rightName)
            if nameCompare != .orderedSame {
                return nameCompare == .orderedAscending
            }

            if lhs.lastSeen != rhs.lastSeen {
                return lhs.lastSeen > rhs.lastSeen
            }

            return lhs.id < rhs.id
        }
    }

    private func verifyAndActivate(peripheral: CBPeripheral) {
        let id = peripheral.identifier.uuidString
        connectionState = .verifying(id: id)
        logger.info("Discover services for \(id, privacy: .public)")
        peripheral.discoverServices([bleMIDIService])
    }

    private func failActivePeripheral(_ message: String) {
        let id = activePeripheral?.identifier.uuidString
        lastError = message
        connectionState = .failed(message)
        logger.error("\(message, privacy: .public)")
        if let id {
            disconnect(id: id, setIdleWhenDone: false)
        }
    }

    private func activateCoreMIDIIfPossible(for peripheral: CBPeripheral) {
        let id = peripheral.identifier.uuidString
        connectionState = .activating(id: id)

        let sourcesBefore = MIDIGetNumberOfSources()
        let status = MIDIBluetoothDriverActivateAllConnections()
        lastActivationStatus = status

        if status != noErr {
            failActivePeripheral("Activate CoreMIDI Bluetooth driver failed: \(status)")
            return
        }

        let sourcesAfter = MIDIGetNumberOfSources()
        logger.info("Activate ok. sources before=\(sourcesBefore, privacy: .public) after=\(sourcesAfter, privacy: .public)")
        connectionState = .activated(id: id)

        if settings.rememberLastBluetoothMIDIDevice {
            settings.lastBluetoothMIDIPeripheralID = id
        }

        logger.info("Disconnect CoreBluetooth connection for \(id, privacy: .public) (CoreMIDI takes over)")
        central.cancelPeripheralConnection(peripheral)
        activePeripheral = nil
    }

    private func disconnect(id: String, setIdleWhenDone: Bool) {
        if setIdleWhenDone {
            let shouldShowDisconnecting: Bool = {
                if let activePeripheral, activePeripheral.identifier.uuidString == id { return true }
                if targetPeripheralID == id { return true }
                switch connectionState {
                    case let .activated(activeID),
                         let .connecting(activeID),
                         let .verifying(activeID),
                         let .activating(activeID),
                         let .disconnecting(activeID):
                        return activeID == id
                    default:
                        return false
                }
            }()

            if shouldShowDisconnecting {
                connectionState = .disconnecting(id: id)
            }
        }

        let status = MIDIBluetoothDriverDisconnect(id as CFString)
        lastDisconnectStatus = status
        if status != noErr {
            logger.error("MIDIBluetoothDriverDisconnect failed: \(status, privacy: .public) id=\(id, privacy: .public)")
        } else {
            logger.info("MIDIBluetoothDriverDisconnect ok id=\(id, privacy: .public)")
        }

        if let peripheral = peripheralsByID[id] {
            central.cancelPeripheralConnection(peripheral)
        }

        if let activePeripheral = self.activePeripheral, activePeripheral.identifier.uuidString == id {
            self.activePeripheral = nil
        }

        if targetPeripheralID == id {
            targetPeripheralID = nil
        }

        if setIdleWhenDone {
            switch connectionState {
                case let .disconnecting(activeID) where activeID == id:
                    connectionState = .idle
                default:
                    break
            }
        }
    }
}

extension CoreBluetoothMIDIConnectionService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = central.state
        logger.info("Central state updated: \(state.rawValue, privacy: .public)")
        switch state {
            case .poweredOn:
                if connectionState == .poweredOff {
                    connectionState = .idle
                }
                if pendingAutoConnect {
                    attemptAutoConnect()
                }
            case .poweredOff:
                connectionState = .poweredOff
            case .unauthorized:
                connectionState = .denied
            case .unsupported:
                connectionState = .unsupported
            case .resetting, .unknown:
                break
            @unknown default:
                break
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData _: [String: Any],
        rssi RSSI: NSNumber
    ) {
        updateDiscovered(peripheral: peripheral, rssi: RSSI)
        if case .scanning = connectionState {
            connectionState = .scanning(mode: scanMode)
        }

        logger.debug("Discovered: \(peripheral.identifier.uuidString, privacy: .public) name=\(peripheral.name ?? "(nil)", privacy: .public) rssi=\(RSSI, privacy: .public)")
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let id = peripheral.identifier.uuidString
        logger.info("Connected: \(id, privacy: .public)")
        verifyAndActivate(peripheral: peripheral)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let id = peripheral.identifier.uuidString
        let message = error?.localizedDescription ?? "Unknown"
        logger.error("Connect failed: \(id, privacy: .public) error=\(message, privacy: .public)")
        failActivePeripheral("Connect failed: \(message)")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let id = peripheral.identifier.uuidString
        if let error {
            logger.error("Disconnected: \(id, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
        } else {
            logger.info("Disconnected: \(id, privacy: .public)")
        }
    }
}

extension CoreBluetoothMIDIConnectionService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        let id = peripheral.identifier.uuidString
        if let error {
            logger.error("Discover services failed: \(id, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            failActivePeripheral("Discover services failed: \(error.localizedDescription)")
            return
        }

        guard let services = peripheral.services else {
            failActivePeripheral("No services discovered")
            return
        }

        guard let service = services.first(where: { $0.uuid == bleMIDIService }) else {
            failActivePeripheral("Peripheral is not BLE MIDI (missing MIDI service)")
            return
        }

        connectionState = .verifying(id: id)
        logger.info("Discover characteristics for \(id, privacy: .public)")
        peripheral.discoverCharacteristics([bleMIDICharacteristic], for: service)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        let id = peripheral.identifier.uuidString
        if let error {
            logger.error("Discover characteristics failed: \(id, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            failActivePeripheral("Discover characteristics failed: \(error.localizedDescription)")
            return
        }

        guard let characteristics = service.characteristics else {
            failActivePeripheral("No characteristics discovered")
            return
        }

        guard characteristics.contains(where: { $0.uuid == bleMIDICharacteristic }) else {
            failActivePeripheral("Peripheral is not BLE MIDI (missing MIDI I/O characteristic)")
            return
        }

        logger.info("Verified BLE MIDI service + characteristic for \(id, privacy: .public)")
        activateCoreMIDIIfPossible(for: peripheral)
    }
}
