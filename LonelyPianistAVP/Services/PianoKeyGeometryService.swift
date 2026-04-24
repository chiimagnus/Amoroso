import Foundation
import simd

protocol PianoKeyGeometryServiceProtocol {
    func generateKeyRegions(from calibration: PianoCalibration) -> [PianoKeyRegion]
}

struct PianoKeyGeometryService: PianoKeyGeometryServiceProtocol {
    private let keyCount = 88
    private let firstMIDINote = 21 // A0

    // Approximate physical dimensions used for hit regions and AR highlights.
    static let keyDepthMeters: Float = 0.14
    static let keyHeightMeters: Float = 0.03

    func generateKeyRegions(from calibration: PianoCalibration) -> [PianoKeyRegion] {
        let a0World = calibration.a0.simdValue
        let c8World = calibration.c8.simdValue

        // P1 assumes the keyboard is perfectly horizontal. Use the horizontal projection to avoid
        // y-noise in tracked anchors from skewing key spacing.
        let delta = SIMD3<Float>(c8World.x - a0World.x, 0, c8World.z - a0World.z)
        let totalDistance = simd_length(delta)
        guard totalDistance > 0.0001 else {
            return []
        }
        let axis = delta / totalDistance
        let keySpacing = totalDistance / Float(max(1, keyCount - 1))

        let depth: Float = Self.keyDepthMeters
        let height: Float = Self.keyHeightMeters
        let planeY = calibration.planeHeight
        let a0 = SIMD3<Float>(a0World.x, planeY, a0World.z)

        return (0 ..< keyCount).map { index in
            let midi = firstMIDINote + index
            let center = a0 + axis * (Float(index) * keySpacing)
            let width = max(0.01, calibration.whiteKeyWidth)
            return PianoKeyRegion(
                midiNote: midi,
                center: center,
                size: SIMD3<Float>(width, height, depth)
            )
        }
    }
}
