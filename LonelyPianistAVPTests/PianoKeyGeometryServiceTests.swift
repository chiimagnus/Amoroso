@testable import LonelyPianistAVP
import simd
import Testing

@Test
func keyGeometryIgnoresYNoiseInCalibrationAnchors() {
    let calibration = PianoCalibration(
        a0: SIMD3<Float>(0.0, 0.50, 0.0),
        c8: SIMD3<Float>(1.0, 1.10, 0.0),
        planeHeight: 0.50
    )

    let regions = PianoKeyGeometryService().generateKeyRegions(from: calibration)
    #expect(regions.count == 88)
    #expect(abs(regions.first?.center.x ?? -1) < 1e-6)
    #expect(abs((regions.first?.center.y ?? -1) - 0.50) < 1e-6)
    #expect(abs(regions.first?.center.z ?? -1) < 1e-6)

    let last = regions[87].center
    #expect(abs(last.x - 1.0) < 1e-4)
    #expect(abs(last.y - 0.50) < 1e-6)
    #expect(abs(last.z - 0.0) < 1e-4)
}

