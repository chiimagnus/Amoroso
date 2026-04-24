@testable import LonelyPianistAVP
import Foundation
import simd
import Testing

@Test
func pressDetectionTriggersWhenFingerCrossesKeyPlaneInKeyboardLocalSpace() throws {
    let service = PressDetectionService(cooldownSeconds: 0.0)

    let frame = try #require(KeyboardFrame(
        a0World: SIMD3<Float>(0.0, 0.5, 0.0),
        c8World: SIMD3<Float>(1.0, 0.5, 1.0),
        planeHeight: 0.5
    ))

    let region = PianoKeyRegion(
        midiNote: 60,
        center: frame.originWorld,
        size: SIMD3<Float>(0.02, 0.03, 0.14)
    )

    let prevLocal = SIMD3<Float>(0.0, 0.05, 0.00)
    let currLocal = SIMD3<Float>(0.0, -0.01, 0.00)

    let prevWorld = PressDetectionService.transformPoint(frame.worldFromKeyboard, prevLocal)
    let currWorld = PressDetectionService.transformPoint(frame.worldFromKeyboard, currLocal)

    _ = service.detectPressedNotes(
        fingerTips: ["index": prevWorld],
        keyRegions: [region],
        keyboardFrame: frame,
        at: Date(timeIntervalSince1970: 0)
    )

    let pressed = service.detectPressedNotes(
        fingerTips: ["index": currWorld],
        keyRegions: [region],
        keyboardFrame: frame,
        at: Date(timeIntervalSince1970: 1)
    )

    #expect(pressed == [60])
}

@Test
func pressDetectionLocalSpaceCanSucceedWhereWorldAABBWouldFailUnderYaw() throws {
    let localService = PressDetectionService(cooldownSeconds: 0.0)
    let worldService = PressDetectionService(cooldownSeconds: 0.0)

    // xAxis points along world +Z, so zAxis becomes world +X.
    let frame = try #require(KeyboardFrame(
        a0World: SIMD3<Float>(0.0, 0.5, 0.0),
        c8World: SIMD3<Float>(0.0, 0.5, 1.0),
        planeHeight: 0.5
    ))

    let region = PianoKeyRegion(
        midiNote: 61,
        center: frame.originWorld,
        size: SIMD3<Float>(0.02, 0.03, 0.14)
    )

    // Inside the key in keyboard-local space (z within depth/2), but maps to world +X,
    // which is outside the world AABB width/2.
    let prevLocal = SIMD3<Float>(0.0, 0.05, 0.06)
    let currLocal = SIMD3<Float>(0.0, -0.01, 0.06)
    let prevWorld = PressDetectionService.transformPoint(frame.worldFromKeyboard, prevLocal)
    let currWorld = PressDetectionService.transformPoint(frame.worldFromKeyboard, currLocal)

    _ = worldService.detectPressedNotes(
        fingerTips: ["index": prevWorld],
        keyRegions: [region],
        keyboardFrame: nil,
        at: Date(timeIntervalSince1970: 0)
    )
    let worldPressed = worldService.detectPressedNotes(
        fingerTips: ["index": currWorld],
        keyRegions: [region],
        keyboardFrame: nil,
        at: Date(timeIntervalSince1970: 1)
    )

    _ = localService.detectPressedNotes(
        fingerTips: ["index": prevWorld],
        keyRegions: [region],
        keyboardFrame: frame,
        at: Date(timeIntervalSince1970: 0)
    )
    let localPressed = localService.detectPressedNotes(
        fingerTips: ["index": currWorld],
        keyRegions: [region],
        keyboardFrame: frame,
        at: Date(timeIntervalSince1970: 1)
    )

    #expect(worldPressed.isEmpty)
    #expect(localPressed == [61])
}
