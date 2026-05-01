import Foundation
import simd

struct GazePlaneHitTestService {
    struct Configuration: Equatable {
        var maxAngleFromUpDegrees: Float = 10
        // Avoid picking a too-near plane which feels "in your face".
        var minDistanceMeters: Float = 0.30
        var maxDistanceMeters: Float = 2.0
        // Prefer a plane hit distance that feels like a reachable tabletop.
        var preferredDistanceMeters: Float = 0.60
    }

    private let configuration: Configuration

    init(configuration: Configuration = .init()) {
        self.configuration = configuration
    }

    func hitTest(ray: GazeRay, planes: [DetectedPlane]) -> PlaneHit? {
        guard let direction = ray.normalizedDirectionWorld else { return nil }

        let up = SIMD3<Float>(0, 1, 0)
        let cosThreshold = cos(configuration.maxAngleFromUpDegrees * .pi / 180)

        var best: PlaneHit?
        var bestDistanceError: Float?

        for plane in planes {
            let planeOrigin = plane.originWorld
            let planeNormal = plane.upwardNormalWorld

            let dotUp = simd_dot(planeNormal, up)
            if dotUp < cosThreshold { continue }

            let denom = simd_dot(direction, planeNormal)
            if abs(denom) < 1e-6 { continue }

            let t = simd_dot(planeOrigin - ray.originWorld, planeNormal) / denom
            if t <= 0 { continue }
            if t < configuration.minDistanceMeters || t > configuration.maxDistanceMeters { continue }

            let hitPoint = ray.originWorld + direction * t
            let hit = PlaneHit(
                id: plane.id,
                hitPointWorld: hitPoint,
                planeNormalWorld: planeNormal,
                distanceMeters: t
            )

            let error = abs(t - configuration.preferredDistanceMeters)
            if let currentBestError = bestDistanceError, let currentBest = best {
                if error < currentBestError || (error == currentBestError && hit.distanceMeters < currentBest.distanceMeters) {
                    best = hit
                    bestDistanceError = error
                }
            } else {
                best = hit
                bestDistanceError = error
            }
        }

        return best
    }
}
