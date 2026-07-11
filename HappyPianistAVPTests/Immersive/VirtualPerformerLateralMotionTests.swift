import Foundation
@testable import HappyPianistAVP
import simd
import Testing

@MainActor
@Test
func virtualPerformerLateralMotionNilActiveNoteIsCentered() {
    let frame = KeyboardFrame(worldFromKeyboard: matrix_identity_float4x4)
    let geometry = VirtualPianoKeyGeometryService().generateKeyboardGeometry(from: frame)
    #expect(geometry != nil)
    guard let geometry else { return }

    let resolver = VirtualPerformerOverlayController.DefaultVirtualPerformerLateralMotionResolver()
    let offset = resolver.desiredLateralOffsetMeters(keyboardGeometry: geometry, activeMIDINote: nil)
    #expect(abs(offset) < 0.0001)
}

@MainActor
@Test
func virtualPerformerLateralMotionClampsToKeyboardFraction() {
    let frame = KeyboardFrame(worldFromKeyboard: matrix_identity_float4x4)
    let geometry = VirtualPianoKeyGeometryService().generateKeyboardGeometry(from: frame)
    #expect(geometry != nil)
    guard let geometry else { return }

    let resolver = VirtualPerformerOverlayController.DefaultVirtualPerformerLateralMotionResolver()

    let totalLength = VirtualPianoKeyGeometryService.totalKeyboardLengthMeters
    let expectedMaxTravel = totalLength * 0.32

    let left = resolver.desiredLateralOffsetMeters(keyboardGeometry: geometry, activeMIDINote: 21)
    let right = resolver.desiredLateralOffsetMeters(keyboardGeometry: geometry, activeMIDINote: 108)

    #expect(left < 0)
    #expect(right > 0)

    #expect(abs(abs(left) - expectedMaxTravel) < 0.001)
    #expect(abs(abs(right) - expectedMaxTravel) < 0.001)
}
