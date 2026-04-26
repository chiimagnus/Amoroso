import RealityKit
import SwiftUI

struct ImmersiveView: View {
    @Bindable var viewModel: ARGuideViewModel
    @State private var overlayController = PianoGuideOverlayController()
    @State private var calibrationOverlayController = CalibrationOverlayController()

    private var reticlePointForOverlay: SIMD3<Float>? {
        switch viewModel.immersiveMode {
            case .calibration:
                switch viewModel.pendingCalibrationCaptureAnchor {
                    case .a0:
                        viewModel.arTrackingService.leftIndexFingerTipPosition
                    case .c8:
                        viewModel.arTrackingService.rightIndexFingerTipPosition
                    case nil:
                        nil
                }
            case .practice:
                viewModel.arTrackingService.leftIndexFingerTipPosition
        }
    }

    var body: some View {
        RealityView { content in
            calibrationOverlayController.update(
                reticlePoint: reticlePointForOverlay,
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
                reticlePoint: reticlePointForOverlay,
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
