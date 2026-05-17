import SwiftUI

struct PreparationWindowRootView: View {
    @Bindable var arGuideViewModel: ARGuideViewModel
    @Environment(WindowCoordinator.self) private var coordinator
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    init(
        arGuideViewModel: ARGuideViewModel
    ) {
        _arGuideViewModel = Bindable(wrappedValue: arGuideViewModel)
    }

    var body: some View {
        let actions = PreparationNavigationActions(
            backToTypePicker: {
                coordinator.resetToPreparation(reason: "user tapped back from preparation")
            },
            nextToLibrary: {
                coordinator.openLibrary(dismissCurrent: .preparation, openWindow: openWindow, dismissWindow: dismissWindow)
            }
        )

        Group {
            if let selectedMode = coordinator.pianoModeRegistry.mode(for: coordinator.flowState.selectedPianoModeID) {
                selectedMode.makePreparationView(arGuideViewModel: arGuideViewModel)
            } else {
                PianoTypePickerView()
            }
        }
        .environment(\.preparationNavigationActions, actions)
        .frame(minWidth: 860, idealWidth: 900, minHeight: 520, idealHeight: 650)
    }
}
