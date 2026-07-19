import Foundation
import simd

protocol PressDetectionServiceProtocol {
    func detectPressedNotes(
        fingerTips: FingerTipsSnapshot,
        keyboardGeometry: PianoKeyboardGeometry?,
        at timestamp: PerformanceMonotonicInstant
    ) -> Set<Int>
}

final class PressDetectionService: PressDetectionServiceProtocol {
    private let cooldownSeconds: TimeInterval
    private var motionEstimator = FingerMotionEstimator()
    private var lastTriggerTimeByNote: [Int: PerformanceMonotonicInstant] = [:]
    private var cachedGeometryID: UUID?
    private var hitTestIndex: PianoKeyHitTestIndex?

    init(cooldownSeconds: TimeInterval = 0.15) {
        self.cooldownSeconds = cooldownSeconds
    }

    func detectPressedNotes(
        fingerTips: FingerTipsSnapshot,
        keyboardGeometry: PianoKeyboardGeometry?,
        at timestamp: PerformanceMonotonicInstant
    ) -> Set<Int> {
        guard let keyboardGeometry else {
            motionEstimator.reset()
            lastTriggerTimeByNote.removeAll(keepingCapacity: true)
            return []
        }

        if let cachedGeometryID, cachedGeometryID != keyboardGeometry.cacheID {
            motionEstimator.reset()
            lastTriggerTimeByNote.removeAll(keepingCapacity: true)
        }
        let index = index(for: keyboardGeometry)
        let keyboardFromWorld = keyboardGeometry.frame.keyboardFromWorld
        var pressed: Set<Int> = []
        var observedFingerIDs: Set<TrackedFingerID> = []
        pressed.reserveCapacity(4)

        fingerTips.forEachFinger { fingerID, currentPosition in
            observedFingerIDs.insert(fingerID)
            let currentPoint = Self.transformPoint(keyboardFromWorld, currentPosition)
            let motion = motionEstimator.estimate(
                fingerID: fingerID,
                position: currentPoint,
                at: timestamp
            )
            guard motion.hasValidMotion,
                  let previousPoint = motion.previousPosition,
                  let normalVelocity = motion.normalVelocityMetersPerSecond,
                  normalVelocity < 0 else { return }
            guard let key = index.firstRegion(containingXZ: currentPoint) else { return }

            let crossedPlane = previousPoint.y > key.surfaceLocalY && currentPoint.y <= key.surfaceLocalY
            guard crossedPlane else { return }

            let isCoolingDown = lastTriggerTimeByNote[key.midiNote]
                .map { timestamp.seconds - $0.seconds < cooldownSeconds } ?? false
            guard isCoolingDown == false else { return }

            pressed.insert(key.midiNote)
            lastTriggerTimeByNote[key.midiNote] = timestamp
        }

        motionEstimator.retainOnly(observedFingerIDs)
        return pressed
    }

    private func index(for geometry: PianoKeyboardGeometry) -> PianoKeyHitTestIndex {
        if cachedGeometryID == geometry.cacheID, let hitTestIndex {
            return hitTestIndex
        }
        let next = PianoKeyHitTestIndex(keyboardGeometry: geometry)
        cachedGeometryID = geometry.cacheID
        hitTestIndex = next
        return next
    }
}

extension PressDetectionService {
    @inline(__always)
    static func transformPoint(_ matrix: simd_float4x4, _ point: SIMD3<Float>) -> SIMD3<Float> {
        let value = simd_mul(matrix, SIMD4<Float>(point, 1))
        return SIMD3<Float>(value.x, value.y, value.z)
    }
}
