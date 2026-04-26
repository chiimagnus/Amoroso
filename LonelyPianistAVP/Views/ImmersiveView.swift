import RealityKit
import SwiftUI

struct ImmersiveView: View {
    @Bindable var viewModel: ARGuideViewModel
    @State private var overlayController = PianoGuideOverlayController()
    @State private var calibrationOverlayController = CalibrationOverlayController()

    var body: some View {
        RealityView { content in
            calibrationOverlayController.update(
                leftIndexFingerTipPoint: viewModel.arTrackingService.leftIndexFingerTipPosition,
                content: content
            )
            overlayController.updateHighlights(
                currentStep: viewModel.practiceSessionViewModel.currentStep,
                keyboardGeometry: viewModel.practiceSessionViewModel.keyboardGeometry,
                feedbackState: viewModel.practiceSessionViewModel.feedbackState,
                content: content
            )
        } update: { content in
            calibrationOverlayController.update(
                leftIndexFingerTipPoint: viewModel.arTrackingService.leftIndexFingerTipPosition,
                content: content
            )
            overlayController.updateHighlights(
                currentStep: viewModel.practiceSessionViewModel.currentStep,
                keyboardGeometry: viewModel.practiceSessionViewModel.keyboardGeometry,
                feedbackState: viewModel.practiceSessionViewModel.feedbackState,
                content: content
            )
        }
        .onAppear {
            viewModel.onImmersiveAppear()
        }
        .onDisappear {
            viewModel.onImmersiveDisappear()
        }
    }
}

#Preview(immersionStyle: .mixed) {
    let appModel = AppModel()
    ImmersiveView(viewModel: ARGuideViewModel(appModel: appModel))
}
