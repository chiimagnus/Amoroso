import SwiftUI

struct PreparationWindowRootView: View {
    @Bindable var arGuideViewModel: ARGuideViewModel
    @Environment(PianoSetupCoordinator.self) private var pianoSetupCoordinator
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @State private var isFinishingSetup = false

    init(
        arGuideViewModel: ARGuideViewModel
    ) {
        _arGuideViewModel = Bindable(wrappedValue: arGuideViewModel)
    }

    var body: some View {
        let actions = PreparationNavigationActions(
            backToTypePicker: {
                pianoSetupCoordinator.reset()
            },
            finishSetup: finishSetup
        )

        Group {
            if let selectedMode = pianoSetupCoordinator.selectedMode {
                PianoModePreparationRouterView(
                    route: selectedMode.preparationRoute,
                    arGuideViewModel: arGuideViewModel
                )
            } else {
                PianoTypePickerView()
            }
        }
        .environment(\.preparationNavigationActions, actions)
        .disabled(isFinishingSetup)
    }

    private func finishSetup() {
        guard isFinishingSetup == false else { return }
        isFinishingSetup = true

        Task { @MainActor in
            let dismissHandler = makePracticeImmersiveDismissHandler(dismissImmersiveSpace)
            await arGuideViewModel.closeImmersiveForStep(
                dismissImmersiveSpace: dismissHandler
            )
            await arGuideViewModel.recoverImmersiveStateIfStuck()
            dismissWindow(id: WindowID.preparation)
        }
    }
}
