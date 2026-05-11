import Observation
import SwiftUI

struct BluetoothMIDIPanelView: View {
    @Bindable var viewModel: LonelyPianistViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Divider()

            scanControls

            Divider()

            peripheralsList

            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Bluetooth MIDI")
                .font(.title2.weight(.semibold))

            Text("State: \(stateDescription)")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("MIDI sources: \(viewModel.connectedSourceNames.count)")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button("Refresh MIDI Sources") {
                viewModel.refreshMIDISources()
            }
        }
    }

    private var scanControls: some View {
        HStack(spacing: 12) {
            Picker("Scan Mode", selection: $viewModel.bluetoothMIDIScanMode) {
                Text("MIDI Service Filtered").tag(BluetoothMIDIScanMode.midiServiceFiltered)
                Text("All Devices (Verify After Connect)").tag(BluetoothMIDIScanMode.allDevices)
            }
            .pickerStyle(.menu)

            Button(isScanning ? "Stop Scan" : "Start Scan") {
                isScanning ? viewModel.stopBluetoothMIDIScan() : viewModel.startBluetoothMIDIScan()
            }

            Spacer()
        }
        .onChange(of: viewModel.bluetoothMIDIScanMode) {
            guard isScanning else { return }
            viewModel.startBluetoothMIDIScan()
        }
    }

    private var peripheralsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Discovered (\(viewModel.bluetoothMIDIDiscoveredPeripherals.count))")
                .font(.headline)

            List {
                ForEach(viewModel.bluetoothMIDIDiscoveredPeripherals) { peripheral in
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(peripheral.name ?? "Unknown")
                                .font(.body.weight(.medium))
                            Text(peripheral.id)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if let rssi = peripheral.rssi {
                            Text("RSSI \(rssi)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(peripheral.lastSeen, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button("Connect") {
                            viewModel.connectBluetoothMIDI(id: peripheral.id)
                        }
                        .disabled(!canConnect(peripheralID: peripheral.id))

                        Button("Disconnect") {
                            viewModel.disconnectBluetoothMIDI(id: peripheral.id)
                        }
                        .disabled(!canDisconnect(peripheralID: peripheral.id))
                    }
                    .padding(.vertical, 4)
                }
            }
            .frame(minHeight: 240)
        }
    }

    private var isScanning: Bool {
        if case .scanning = viewModel.bluetoothMIDIConnectionState {
            return true
        }
        return false
    }

    private var stateDescription: String {
        switch viewModel.bluetoothMIDIConnectionState {
            case .idle:
                "Idle"
            case let .scanning(mode):
                mode == .midiServiceFiltered ? "Scanning (filtered)" : "Scanning (all devices)"
            case .readyToConnect:
                "Ready to connect"
            case let .connecting(id):
                "Connecting \(id)"
            case let .verifying(id):
                "Verifying \(id)"
            case let .activating(id):
                "Activating \(id)"
            case let .activated(id):
                "Activated \(id)"
            case let .disconnecting(id):
                "Disconnecting \(id)"
            case let .failed(message):
                "Failed: \(message)"
            case .denied:
                "Denied"
            case .poweredOff:
                "Powered off"
            case .unsupported:
                "Unsupported"
        }
    }

    private func canConnect(peripheralID id: String) -> Bool {
        switch viewModel.bluetoothMIDIConnectionState {
            case .connecting, .verifying, .activating, .disconnecting:
                return false
            case .denied, .poweredOff, .unsupported:
                return false
            default:
                return true
        }
    }

    private func canDisconnect(peripheralID id: String) -> Bool {
        switch viewModel.bluetoothMIDIConnectionState {
            case let .activated(activeID),
                 let .connecting(activeID),
                 let .verifying(activeID),
                 let .activating(activeID),
                 let .disconnecting(activeID):
                return activeID == id
            default:
                return false
        }
    }
}

