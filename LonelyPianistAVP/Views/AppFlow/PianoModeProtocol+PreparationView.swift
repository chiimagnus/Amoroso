import SwiftUI

extension PianoModeProtocol {
    @MainActor
    func makePreparationView(arGuideViewModel: ARGuideViewModel) -> AnyView {
        switch preparationRoute {
        case .realPiano:
            AnyView(RealPianoPreparationView(viewModel: arGuideViewModel))
        case .bluetoothMIDI:
            AnyView(BluetoothMIDIPreparationView(viewModel: arGuideViewModel))
        case .virtualPiano:
            AnyView(VirtualPianoPreparationView(viewModel: arGuideViewModel))
        }
    }
}

