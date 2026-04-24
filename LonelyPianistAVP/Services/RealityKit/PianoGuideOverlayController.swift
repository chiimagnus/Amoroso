import Foundation
import RealityKit
import SwiftUI

@MainActor
final class PianoGuideOverlayController {
    private var rootEntity = Entity()
    private var keyboardRootEntity = Entity()
    private var hasAttachedRoot = false
    private var activeMarkersByMIDINote: [Int: ModelEntity] = [:]
    private var lastTintColor: UIColor?

    private let lightBeamHeight: Float = 0.22
    private let lightBeamBaseYOffset: Float = 0.006
    private let lightBeamRadiusScale: Float = 0.32
    private let lightBeamMinimumRadius: Float = 0.006
    private let lightBeamAlpha: CGFloat = 0.42

    func updateHighlights(
        currentStep: PracticeStep?,
        keyboardFrame: KeyboardFrame?,
        keyRegions: [PianoKeyRegion],
        feedbackState: PracticeSessionViewModel.VisualFeedbackState,
        content: RealityViewContent
    ) {
        if hasAttachedRoot == false {
            content.add(rootEntity)
            rootEntity.addChild(keyboardRootEntity)
            hasAttachedRoot = true
        }

        guard let currentStep, let keyboardFrame else {
            clearMarkers()
            return
        }

        keyboardRootEntity.transform = Transform(matrix: keyboardFrame.worldFromKeyboard)

        let tintColor: UIColor = switch feedbackState {
            case .none:
                AVPOverlayPalette.feedbackNoneColor
            case .correct:
                AVPOverlayPalette.feedbackCorrectColor
            case .wrong:
                AVPOverlayPalette.feedbackWrongColor
        }

        if lastTintColor != tintColor {
            let material = lightBeamMaterial(for: tintColor)
            for marker in activeMarkersByMIDINote.values {
                marker.model?.materials = [material]
            }
            lastTintColor = tintColor
        }

        let regionByNote = Dictionary(uniqueKeysWithValues: keyRegions.map { ($0.midiNote, $0) })
        let desiredNotes: Set<Int> = Set(currentStep.notes.map(\.midiNote))

        // Remove markers that are no longer needed.
        for (midiNote, marker) in activeMarkersByMIDINote {
            if desiredNotes.contains(midiNote) == false {
                marker.removeFromParent()
                activeMarkersByMIDINote[midiNote] = nil
            }
        }

        // Add/update light beams for desired notes.
        for midiNote in desiredNotes {
            guard let region = regionByNote[midiNote] else { continue }

            // Convert world-space key region center to keyboard-local coordinates so markers inherit the
            // keyboard yaw from `keyboardRootEntity`.
            let centerWorld = SIMD4<Float>(region.center, 1)
            let centerLocal4 = simd_mul(keyboardFrame.keyboardFromWorld, centerWorld)
            let centerLocal = SIMD3<Float>(centerLocal4.x, centerLocal4.y, centerLocal4.z)

            let marker: ModelEntity
            if let existing = activeMarkersByMIDINote[midiNote] {
                marker = existing
            } else {
                marker = ModelEntity(
                    mesh: .generateCylinder(height: 1, radius: 1),
                    materials: [lightBeamMaterial(for: tintColor)]
                )
                activeMarkersByMIDINote[midiNote] = marker
                keyboardRootEntity.addChild(marker)
            }

            let keyFootprint = min(region.size.x, region.size.z)
            let beamRadius = max(keyFootprint * lightBeamRadiusScale, lightBeamMinimumRadius)
            marker.scale = SIMD3<Float>(beamRadius, lightBeamHeight, beamRadius)
            marker.position = SIMD3<Float>(
                centerLocal.x,
                centerLocal.y + lightBeamBaseYOffset + lightBeamHeight * 0.5,
                centerLocal.z
            )
        }
    }

    private func lightBeamMaterial(for tintColor: UIColor) -> SimpleMaterial {
        SimpleMaterial(color: tintColor.withAlphaComponent(lightBeamAlpha), isMetallic: false)
    }

    private func clearMarkers() {
        for marker in activeMarkersByMIDINote.values {
            marker.removeFromParent()
        }
        activeMarkersByMIDINote.removeAll()
        lastTintColor = nil
    }
}
