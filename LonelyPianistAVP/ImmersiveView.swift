//
//  ImmersiveView.swift
//  LonelyPianistAVP
//
//  Created by chii_magnus on 2026/4/6.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    @State private var sessionViewModel = PracticeSessionViewModel()
    @State private var overlayController = PianoGuideOverlayController()

    var body: some View {
        ZStack {
            RealityView { content in
                // Add the initial RealityKit content
                if let immersiveContentEntity = try? await Entity(named: "Immersive", in: realityKitContentBundle) {
                    content.add(immersiveContentEntity)
                }
                bootstrapDemoDataIfNeeded()
                sessionViewModel.startGuidingIfReady()
                overlayController.updateHighlights(
                    currentStep: sessionViewModel.currentStep,
                    keyRegions: sessionViewModel.keyRegions,
                    content: content
                )
            } update: { content in
                overlayController.updateHighlights(
                    currentStep: sessionViewModel.currentStep,
                    keyRegions: sessionViewModel.keyRegions,
                    content: content
                )
            }

            VStack(spacing: 12) {
                Text(currentStepSummary)
                HStack(spacing: 16) {
                    Button("Skip") {
                        sessionViewModel.skip()
                    }
                    Button("Mark Correct") {
                        sessionViewModel.markCorrect()
                    }
                }
            }
            .padding()
            .glassBackgroundEffect()
        }
    }

    private var currentStepSummary: String {
        guard let step = sessionViewModel.currentStep else {
            return "No active step"
        }
        let summary = step.notes.map { midiToName($0.midiNote) }.joined(separator: " + ")
        return "Current Step: \(summary)"
    }

    private func midiToName(_ midi: Int) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = midi / 12 - 1
        let index = max(0, min(11, midi % 12))
        return "\(names[index])\(octave)"
    }

    private func bootstrapDemoDataIfNeeded() {
        guard sessionViewModel.steps.isEmpty else { return }

        let calibration = PianoCalibration(
            a0: SIMD3<Float>(-0.7, 0.8, -1.0),
            c8: SIMD3<Float>(0.7, 0.8, -1.0),
            planeHeight: 0.8
        )
        let keyRegions = PianoKeyGeometryService().generateKeyRegions(from: calibration)
        let steps = [
            PracticeStep(tick: 0, notes: [PracticeStepNote(midiNote: 60, staff: 1)]),
            PracticeStep(tick: 1, notes: [
                PracticeStepNote(midiNote: 60, staff: 1),
                PracticeStepNote(midiNote: 64, staff: 1),
                PracticeStepNote(midiNote: 67, staff: 1)
            ]),
            PracticeStep(tick: 2, notes: [PracticeStepNote(midiNote: 62, staff: 1)])
        ]
        sessionViewModel.configure(steps: steps, calibration: calibration, keyRegions: keyRegions)
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}
