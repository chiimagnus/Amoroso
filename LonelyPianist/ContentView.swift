import Observation
import SwiftUI

struct MainWindowView: View {
    @Bindable var viewModel: LonelyPianistViewModel
    @State private var isShowingBluetoothMIDIPanel = false

    var body: some View {
        NavigationStack {
            RecorderPanelView(viewModel: viewModel)
                .navigationTitle("Recorder")
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Button {
                            isShowingBluetoothMIDIPanel = true
                        } label: {
                            Label("Bluetooth MIDI", systemImage: "dot.radiowaves.left.and.right")
                        }
                    }
                }
                .sheet(isPresented: $isShowingBluetoothMIDIPanel) {
                    BluetoothMIDIPanelView(viewModel: viewModel)
                        .frame(minWidth: 520, minHeight: 520)
                }
        }
    }
}
