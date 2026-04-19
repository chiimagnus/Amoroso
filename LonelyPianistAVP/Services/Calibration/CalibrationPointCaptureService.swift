import Foundation
import Observation
import simd

enum CalibrationAnchorPoint {
    case a0
    case c8
}

@MainActor
@Observable
final class CalibrationPointCaptureService {
    var reticlePoint: SIMD3<Float> = SIMD3<Float>(0, 0.8, -1.0)
    var a0Point: SIMD3<Float>?
    var c8Point: SIMD3<Float>?

    var isReticleReadyToConfirm: Bool = false

    private var stableStartUptime: TimeInterval?
    private var lastReticlePointForStability: SIMD3<Float>?

    func reset() {
        reticlePoint = SIMD3<Float>(0, 0.8, -1.0)
        a0Point = nil
        c8Point = nil
        isReticleReadyToConfirm = false
        stableStartUptime = nil
        lastReticlePointForStability = nil
    }

    func updateReticleFromHandTracking(_ point: SIMD3<Float>?, nowUptime: TimeInterval) {
        guard let point else {
            isReticleReadyToConfirm = false
            stableStartUptime = nil
            lastReticlePointForStability = nil
            return
        }

        reticlePoint = point

        let deltaThresholdMeters: Float = 0.002
        let stableDurationSeconds: TimeInterval = 0.5

        if let last = lastReticlePointForStability {
            let delta = simd_length(point - last)
            if delta < deltaThresholdMeters {
                if stableStartUptime == nil {
                    stableStartUptime = nowUptime
                }
            } else {
                stableStartUptime = nil
            }
        } else {
            stableStartUptime = nil
        }

        lastReticlePointForStability = point

        if let stableStartUptime {
            let stableFor = max(0, nowUptime - stableStartUptime)
            let progress = min(1.0, stableFor / stableDurationSeconds)
            isReticleReadyToConfirm = progress >= 1.0
        } else {
            isReticleReadyToConfirm = false
        }
    }

    func capture(_ anchor: CalibrationAnchorPoint) {
        switch anchor {
        case .a0:
            a0Point = reticlePoint
        case .c8:
            c8Point = reticlePoint
        }
    }

    func buildCalibration() -> PianoCalibration? {
        guard let a0Point, let c8Point else {
            return nil
        }
        guard simd_length(c8Point - a0Point) > 0.05 else {
            return nil
        }
        return PianoCalibration(a0: a0Point, c8: c8Point, planeHeight: (a0Point.y + c8Point.y) / 2)
    }
}
