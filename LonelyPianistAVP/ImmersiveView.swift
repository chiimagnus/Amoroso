//
//  ImmersiveView.swift
//  LonelyPianistAVP
//
//  Created by chii_magnus on 2026/4/6.
//

import SwiftUI
import RealityKit

struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    @State private var overlayController = PianoGuideOverlayController()

    var body: some View {
        ZStack {
            RealityView { content in
                appModel.practiceSessionViewModel.startGuidingIfReady()
                overlayController.updateHighlights(
                    currentStep: appModel.practiceSessionViewModel.currentStep,
                    keyRegions: appModel.practiceSessionViewModel.keyRegions,
                    feedbackState: appModel.practiceSessionViewModel.feedbackState,
                    content: content
                )
            } update: { content in
                _ = appModel.practiceSessionViewModel.handleFingerTipPositions(
                    appModel.handTrackingService.fingerTipPositions
                )
                overlayController.updateHighlights(
                    currentStep: appModel.practiceSessionViewModel.currentStep,
                    keyRegions: appModel.practiceSessionViewModel.keyRegions,
                    feedbackState: appModel.practiceSessionViewModel.feedbackState,
                    content: content
                )
            }
            .gesture(SpatialTapGesture(coordinateSpace3D: .worldReference).onEnded { value in
                let point3D = value.location3D
                let point = SIMD3<Float>(Float(point3D.x), Float(point3D.y), Float(point3D.z))
                appModel.calibrationCaptureService.updateReticleEstimate(point)
                if let pendingAnchor = appModel.pendingCalibrationCaptureAnchor {
                    appModel.calibrationCaptureService.capture(pendingAnchor)
                    appModel.calibrationStatusMessage = "Captured \(pendingAnchor == .a0 ? "A0" : "C8")"
                    appModel.pendingCalibrationCaptureAnchor = nil
                }
            })

            if appModel.calibration == nil {
                calibrationPanel
            } else {
                practicePanel
            }
        }
        .onAppear {
            appModel.handTrackingService.start()
        }
        .onDisappear {
            appModel.handTrackingService.stop()
        }
    }

    private var calibrationPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Calibration")
                .font(.headline)

            Text(appModel.pendingCalibrationCaptureAnchor == nil ? "Tap in space to preview." : "Tap in space to set.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Set A0") { appModel.pendingCalibrationCaptureAnchor = .a0 }
                Button("Set C8") { appModel.pendingCalibrationCaptureAnchor = .c8 }
                Button("Save") { appModel.saveCalibrationIfPossible() }
            }

            Button("Manual Fallback") {
                appModel.calibrationCaptureService.updateReticleEstimate(nil)
            }

            if appModel.calibrationCaptureService.mode == .manualFallback {
                HStack(spacing: 8) {
                    Button("A0 ◀︎") {
                        appModel.calibrationCaptureService.adjust(anchor: .a0, delta: SIMD3<Float>(-0.01, 0, 0))
                    }
                    Button("A0 ▶︎") {
                        appModel.calibrationCaptureService.adjust(anchor: .a0, delta: SIMD3<Float>(0.01, 0, 0))
                    }
                    Button("C8 ◀︎") {
                        appModel.calibrationCaptureService.adjust(anchor: .c8, delta: SIMD3<Float>(-0.01, 0, 0))
                    }
                    Button("C8 ▶︎") {
                        appModel.calibrationCaptureService.adjust(anchor: .c8, delta: SIMD3<Float>(0.01, 0, 0))
                    }
                }
            }

            if let message = appModel.calibrationStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .glassBackgroundEffect()
    }

    private var practicePanel: some View {
        HStack(spacing: 12) {
            Button("Skip") { appModel.practiceSessionViewModel.skip() }
        }
        .padding()
        .glassBackgroundEffect()
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}
