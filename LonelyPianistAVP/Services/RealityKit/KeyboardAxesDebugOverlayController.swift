import RealityKit
import SwiftUI

@MainActor
final class KeyboardAxesDebugOverlayController {
    private var rootEntity = Entity()
    private var axesRootEntity = Entity()
    private var hasAttachedRoot = false
    private var hasBuiltAxes = false

    func update(isEnabled: Bool, keyboardFrame: KeyboardFrame?, content: RealityViewContent) {
        guard isEnabled else {
            if hasAttachedRoot {
                rootEntity.isEnabled = false
            }
            return
        }

        guard let keyboardFrame else {
            if hasAttachedRoot {
                rootEntity.isEnabled = false
            }
            return
        }

        if hasAttachedRoot == false {
            content.add(rootEntity)
            rootEntity.addChild(axesRootEntity)
            hasAttachedRoot = true
        }

        if hasBuiltAxes == false {
            buildAxes()
            hasBuiltAxes = true
        }

        rootEntity.isEnabled = true
        axesRootEntity.transform = Transform(matrix: keyboardFrame.worldFromKeyboard)
    }

    private func buildAxes() {
        let thickness: Float = 0.004
        let xLen: Float = 0.30
        let yLen: Float = 0.18
        let zLen: Float = 0.20

        let xAxis = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(xLen, thickness, thickness)),
            materials: [SimpleMaterial(color: .systemRed, isMetallic: false)]
        )
        xAxis.position = SIMD3<Float>(xLen / 2, 0, 0)

        let yAxis = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(thickness, yLen, thickness)),
            materials: [SimpleMaterial(color: .systemGreen, isMetallic: false)]
        )
        yAxis.position = SIMD3<Float>(0, yLen / 2, 0)

        let zAxis = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(thickness, thickness, zLen)),
            materials: [SimpleMaterial(color: .systemBlue, isMetallic: false)]
        )
        zAxis.position = SIMD3<Float>(0, 0, zLen / 2)

        axesRootEntity.addChild(xAxis)
        axesRootEntity.addChild(yAxis)
        axesRootEntity.addChild(zAxis)
    }
}
