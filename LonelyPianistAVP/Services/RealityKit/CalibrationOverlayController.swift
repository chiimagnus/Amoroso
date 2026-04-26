import RealityKit
import SwiftUI

@MainActor
final class CalibrationOverlayController {
    private let rootEntity = Entity()
    private var hasAttachedRoot = false

    private var reticleEntity: ModelEntity?

    func update(
        leftIndexFingerTipPoint: SIMD3<Float>?,
        content: RealityViewContent
    ) {
        if hasAttachedRoot == false {
            content.add(rootEntity)
            hasAttachedRoot = true
        }

        guard let leftIndexFingerTipPoint else {
            reticleEntity?.removeFromParent()
            reticleEntity = nil
            return
        }

        let reticle = ensureSphere(
            &reticleEntity,
            color: AVPOverlayPalette.reticleColor,
            radius: 0.02
        )
        reticle.position = leftIndexFingerTipPoint
    }

    private func ensureSphere(
        _ entity: inout ModelEntity?,
        color: UIColor,
        radius: Float
    ) -> ModelEntity {
        if let entity {
            entity.model?.materials = [UnlitMaterial(color: color)]
            return entity
        }

        let model = ModelEntity(
            mesh: .generateSphere(radius: radius),
            materials: [UnlitMaterial(color: color)]
        )
        rootEntity.addChild(model)
        entity = model
        return model
    }
}
