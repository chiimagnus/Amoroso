import RealityKit
import simd
import SwiftUI

@MainActor
final class VirtualPianoOverlayController {
    private var rootEntity = Entity()
    private var hasAttachedRoot = false
    private var keyboardRootEntity: Entity?

    func update(
        isEnabled: Bool,
        keyboardGeometry: PianoKeyboardGeometry?,
        content: RealityViewContent?
    ) {
        if hasAttachedRoot == false, let content {
            content.add(rootEntity)
            hasAttachedRoot = true
        }

        guard isEnabled, let keyboardGeometry else {
            clearKeyboard()
            return
        }

        showKeyboard(geometry: keyboardGeometry)
    }

    private func showKeyboard(geometry: PianoKeyboardGeometry) {
        guard keyboardRootEntity == nil else { return }

        let kbRoot = Entity()
        kbRoot.transform = Transform(matrix: geometry.frame.worldFromKeyboard)

        for key in geometry.keys {
            let keyEntity = makeKeyEntity(for: key)
            kbRoot.addChild(keyEntity)
        }

        rootEntity.addChild(kbRoot)
        keyboardRootEntity = kbRoot
    }

    private func clearKeyboard() {
        keyboardRootEntity?.removeFromParent()
        keyboardRootEntity = nil
    }

    private func makeKeyEntity(for key: PianoKeyGeometry) -> ModelEntity {
        let mesh = MeshResource.generateBox(size: key.localSize)
        let color: UIColor = key.kind == .white ? .white : .black
        var material = SimpleMaterial(color: color, isMetallic: false)
        material.roughness = 0.5

        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = key.localCenter
        return entity
    }
}
