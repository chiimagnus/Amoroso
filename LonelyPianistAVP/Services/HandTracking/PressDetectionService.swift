import Foundation
import simd

protocol PressDetectionServiceProtocol {
    func detectPressedNotes(
        fingerTips: [String: SIMD3<Float>],
        keyRegions: [PianoKeyRegion],
        at timestamp: Date
    ) -> Set<Int>
}

final class PressDetectionService: PressDetectionServiceProtocol {
    private let cooldownSeconds: TimeInterval
    private var lastFingerTipPositions: [String: SIMD3<Float>] = [:]
    private var lastTriggerTimeByNote: [Int: Date] = [:]

    init(cooldownSeconds: TimeInterval = 0.15) {
        self.cooldownSeconds = cooldownSeconds
    }

    func detectPressedNotes(
        fingerTips: [String : SIMD3<Float>],
        keyRegions: [PianoKeyRegion],
        at timestamp: Date
    ) -> Set<Int> {
        var pressed: Set<Int> = []

        for (fingerID, currentPosition) in fingerTips {
            defer { lastFingerTipPositions[fingerID] = currentPosition }
            guard let previousPosition = lastFingerTipPositions[fingerID] else { continue }

            for region in keyRegions {
                let keyPlaneY = region.center.y + region.size.y * 0.5
                let crossedPlane = previousPosition.y > keyPlaneY && currentPosition.y <= keyPlaneY
                guard crossedPlane else { continue }

                let minPoint = region.min
                let maxPoint = region.max
                let insideKeyBounds = currentPosition.x >= minPoint.x && currentPosition.x <= maxPoint.x
                    && currentPosition.z >= minPoint.z && currentPosition.z <= maxPoint.z
                guard insideKeyBounds else { continue }

                let lastTriggerTime = lastTriggerTimeByNote[region.midiNote]
                let isCoolingDown = lastTriggerTime.map { timestamp.timeIntervalSince($0) < cooldownSeconds } ?? false
                guard isCoolingDown == false else { continue }

                pressed.insert(region.midiNote)
                lastTriggerTimeByNote[region.midiNote] = timestamp
            }
        }

        return pressed
    }
}
