import RealityKit
import simd
import SwiftUI

@MainActor
final class VirtualPerformerOverlayController {
    private var rootEntity = Entity()
    private var hasAttachedRoot = false
    private var performerRootEntity: Entity?

    func update(
        isEnabled: Bool,
        isPerforming _: Bool,
        keyboardGeometry: PianoKeyboardGeometry?,
        cameraWorldPosition: SIMD3<Float>? = nil,
        content: RealityViewContent?
    ) {
        if hasAttachedRoot == false, let content {
            content.add(rootEntity)
            hasAttachedRoot = true
        }

        guard isEnabled, let keyboardGeometry else {
            clearPerformer()
            return
        }

        showPerformer(geometry: keyboardGeometry, cameraWorldPosition: cameraWorldPosition)
    }

    private func showPerformer(geometry: PianoKeyboardGeometry, cameraWorldPosition: SIMD3<Float>?) {
        if performerRootEntity == nil {
            let performerRoot = makePerformerRootEntity()
            rootEntity.addChild(performerRoot)
            performerRootEntity = performerRoot
        }

        guard let performerRootEntity else { return }

        let totalLength = VirtualPianoKeyGeometryService.totalKeyboardLengthMeters
        let keyDepth = VirtualPianoKeyGeometryService.whiteKeyDepthMeters
        let keyboardCenterLocal = SIMD3<Float>(totalLength / 2, 0, -keyDepth / 2)

        let worldFromKeyboard = geometry.frame.worldFromKeyboard
        let xAxisWorld = SIMD3<Float>(
            worldFromKeyboard.columns.0.x,
            worldFromKeyboard.columns.0.y,
            worldFromKeyboard.columns.0.z
        )
        let yAxisWorld = SIMD3<Float>(
            worldFromKeyboard.columns.1.x,
            worldFromKeyboard.columns.1.y,
            worldFromKeyboard.columns.1.z
        )
        let zAxisWorld = SIMD3<Float>(
            worldFromKeyboard.columns.2.x,
            worldFromKeyboard.columns.2.y,
            worldFromKeyboard.columns.2.z
        )
        let originWorld = SIMD3<Float>(
            worldFromKeyboard.columns.3.x,
            worldFromKeyboard.columns.3.y,
            worldFromKeyboard.columns.3.z
        )
        let keyboardCenterWorld = originWorld
            + xAxisWorld * keyboardCenterLocal.x
            + yAxisWorld * keyboardCenterLocal.y
            + zAxisWorld * keyboardCenterLocal.z

        let forwardOnPlaneWorld: SIMD3<Float> = {
            guard let cameraWorldPosition else { return simd_normalize(zAxisWorld) }
            let toCameraWorld = cameraWorldPosition - keyboardCenterWorld
            let toCameraOnPlane = toCameraWorld - yAxisWorld * simd_dot(toCameraWorld, yAxisWorld)
            guard simd_length(toCameraOnPlane) > 0.0001 else { return simd_normalize(zAxisWorld) }
            return simd_normalize(-toCameraOnPlane)
        }()

        let rightOnPlaneWorld = simd_normalize(simd_cross(yAxisWorld, forwardOnPlaneWorld))

        let offsetRightMeters: Float = totalLength * 0.6
        let offsetForwardMeters: Float = keyDepth * 0.8
        let offsetUpMeters: Float = 0.0

        let performerPositionWorld = keyboardCenterWorld
            + rightOnPlaneWorld * offsetRightMeters
            + forwardOnPlaneWorld * offsetForwardMeters
            + yAxisWorld * offsetUpMeters

        let performerWorldFromRoot = simd_float4x4(columns: (
            SIMD4<Float>(rightOnPlaneWorld, 0),
            SIMD4<Float>(yAxisWorld, 0),
            SIMD4<Float>(simd_normalize(simd_cross(rightOnPlaneWorld, yAxisWorld)), 0),
            SIMD4<Float>(performerPositionWorld, 1)
        ))

        performerRootEntity.transform = Transform(matrix: performerWorldFromRoot)
    }

    private func clearPerformer() {
        performerRootEntity?.removeFromParent()
        performerRootEntity = nil
    }

    private func makePerformerRootEntity() -> Entity {
        let root = Entity()
        root.addChild(makeTinyPianoEntity())
        root.addChild(makePerformerEntity())
        return root
    }

    private func makePerformerEntity() -> Entity {
        let performer = Entity()

        let bodyColor = SimpleMaterial(color: UIColor.orange, isMetallic: false)
        let accentColor = SimpleMaterial(color: UIColor.white, isMetallic: false)

        let head = makeHeadEntity(bodyColor: bodyColor)
        head.position = [0, 0.52, 0]
        performer.addChild(head)

        let torso = ModelEntity(mesh: .generateCylinder(height: 0.32, radius: 0.07), materials: [bodyColor])
        torso.position = [0, 0.32, 0]
        performer.addChild(torso)

        let leftArm = ModelEntity(mesh: .generateCylinder(height: 0.24, radius: 0.03), materials: [bodyColor])
        leftArm.position = [-0.14, 0.34, 0]
        leftArm.transform.rotation = simd_quatf(angle: .pi / 2.6, axis: [0, 0, 1])
        performer.addChild(leftArm)

        let rightArm = ModelEntity(mesh: .generateCylinder(height: 0.24, radius: 0.03), materials: [bodyColor])
        rightArm.position = [0.14, 0.34, 0]
        rightArm.transform.rotation = simd_quatf(angle: -.pi / 2.6, axis: [0, 0, 1])
        performer.addChild(rightArm)

        let leftHand = ModelEntity(mesh: .generateSphere(radius: 0.035), materials: [accentColor])
        leftHand.position = [-0.24, 0.26, 0.03]
        performer.addChild(leftHand)

        let rightHand = ModelEntity(mesh: .generateSphere(radius: 0.035), materials: [accentColor])
        rightHand.position = [0.24, 0.26, 0.03]
        performer.addChild(rightHand)

        let leftLeg = ModelEntity(mesh: .generateCylinder(height: 0.28, radius: 0.035), materials: [bodyColor])
        leftLeg.position = [-0.06, 0.12, 0]
        performer.addChild(leftLeg)

        let rightLeg = ModelEntity(mesh: .generateCylinder(height: 0.28, radius: 0.035), materials: [bodyColor])
        rightLeg.position = [0.06, 0.12, 0]
        performer.addChild(rightLeg)

        return performer
    }

    private func makeHeadEntity(bodyColor: SimpleMaterial) -> Entity {
        let root = Entity()

        let segmentCount = 16
        let ringRadius: Float = 0.095
        let segmentHeight: Float = 0.015
        let segmentRadius: Float = 0.01

        for index in 0 ..< segmentCount {
            let angle = (Float(index) / Float(segmentCount)) * (2 * .pi)
            let x = cos(angle) * ringRadius
            let z = sin(angle) * ringRadius

            let segment = ModelEntity(
                mesh: .generateCylinder(height: segmentHeight, radius: segmentRadius),
                materials: [bodyColor]
            )
            segment.position = [x, 0, z]
            segment.transform.rotation = simd_quatf(angle: angle, axis: [0, 1, 0])
            root.addChild(segment)
        }

        return root
    }

    private func makeTinyPianoEntity() -> Entity {
        let piano = Entity()

        let caseMaterial = SimpleMaterial(color: UIColor.darkGray, isMetallic: false)
        let keyMaterial = SimpleMaterial(color: UIColor.lightGray, isMetallic: false)

        let body = ModelEntity(mesh: .generateBox(size: [0.55, 0.08, 0.26]), materials: [caseMaterial])
        body.position = [0, 0.40, 0.12]
        piano.addChild(body)

        let keys = ModelEntity(mesh: .generateBox(size: [0.52, 0.02, 0.18]), materials: [keyMaterial])
        keys.position = [0, 0.45, 0.05]
        piano.addChild(keys)

        return piano
    }
}
