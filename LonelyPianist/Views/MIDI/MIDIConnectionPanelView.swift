import Observation
import SwiftUI

struct MIDIConnectionPanelView: View {
    @Bindable var viewModel: LonelyPianistViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MIDI")
                        .font(.title2.weight(.semibold))
                    Text(viewModel.connectionDescription)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }

            HStack(spacing: 10) {
                Button {
                    viewModel.refreshMIDISources()
                } label: {
                    Label("Refresh MIDI Sources", systemImage: "arrow.clockwise")
                }

                Text(viewModel.statusMessage)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }

            GroupBox("Connected Sources (\(viewModel.connectedSourceNames.count))") {
                if viewModel.connectedSourceNames.isEmpty {
                    ContentUnavailableView {
                        Label("No MIDI Source", systemImage: "questionmark.folder")
                    } description: {
                        Text("Connect your BLE MIDI device in Audio MIDI Setup → Bluetooth, then refresh.")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                } else {
                    List(viewModel.connectedSourceNames, id: \.self) { name in
                        Text(name)
                    }
                    .frame(minHeight: 160)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 360)
    }
}

