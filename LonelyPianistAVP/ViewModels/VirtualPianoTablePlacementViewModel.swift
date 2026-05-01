import Foundation
import Observation
import simd

@MainActor
@Observable
final class VirtualPianoTablePlacementViewModel {
    enum State: Equatable {
        case disabled
        case waitingForTableAnchor
        case waitingForHandsStable(progress: Double)
        case ready(worldFromKeyboard: simd_float4x4)
        case failed(message: String)
    }

    private static let stableDurationSeconds: TimeInterval = 3.0
    private static let stableThresholdMeters: Float = 0.005
    private static let missingHandsGraceSeconds: TimeInterval = 0.25

    private(set) var state: State = .disabled

    private var stableStartUptime: TimeInterval?
    private var stableReferenceHandPointOnPlaneWorld: SIMD3<Float>?
    private var lastBothHandsSeenUptime: TimeInterval?

    func reset() {
        state = .disabled
        stableStartUptime = nil
        stableReferenceHandPointOnPlaneWorld = nil
        lastBothHandsSeenUptime = nil
    }

    func start() {
        state = .waitingForTableAnchor
        stableStartUptime = nil
        stableReferenceHandPointOnPlaneWorld = nil
        lastBothHandsSeenUptime = nil
    }

    #if DEBUG && targetEnvironment(simulator)
    func placeAtDefaultPosition() {
        let xAxisWorld = SIMD3<Float>(1, 0, 0)
        let yAxisWorld = SIMD3<Float>(0, 1, 0)
        let zAxis = simd_normalize(simd_cross(xAxisWorld, yAxisWorld))
        let xAxis = simd_normalize(simd_cross(yAxisWorld, zAxis))

        // 默认位置：在用户面前约 1m 处，键盘水平放置
        let centerPoint = SIMD3<Float>(0, 1.0, -1.0)
        let originWorld = centerPoint - xAxis * (VirtualPianoKeyGeometryService.totalKeyboardLengthMeters / 2)

        let transform = simd_float4x4(columns: (
            SIMD4<Float>(xAxis, 0),
            SIMD4<Float>(yAxisWorld, 0),
            SIMD4<Float>(zAxis, 0),
            SIMD4<Float>(originWorld, 1)
        ))

        stableStartUptime = nil
        stableReferenceHandPointOnPlaneWorld = nil
        state = .ready(worldFromKeyboard: transform)
    }
    #endif

    func update(
        tableWorldFromAnchor: simd_float4x4?,
        fingerTips: [String: SIMD3<Float>],
        deviceWorldTransform: simd_float4x4?,
        nowUptime: TimeInterval
    ) {
        guard state != .disabled else { return }
        if case .ready = state { return }
        if case .failed = state { return }

        guard let tableWorldFromAnchor else {
            state = .waitingForTableAnchor
            stableStartUptime = nil
            stableReferenceHandPointOnPlaneWorld = nil
            lastBothHandsSeenUptime = nil
            return
        }

        // 放置确认不再使用 fingertip 平均值（抖动大、且容易因 tip 丢失造成闪烁）；
        // 改为使用每只手的 palmCenter（在 ARTrackingService 中由 wrist + metacarpal/knuckle 近似得到）。
        let leftPalm = fingerTips["left-palmCenter"]
        let rightPalm = fingerTips["right-palmCenter"]

        guard let leftPalm, let rightPalm else {
            if let lastBothHandsSeenUptime, nowUptime - lastBothHandsSeenUptime <= Self.missingHandsGraceSeconds {
                // Hand tracking 偶发丢一帧时不立刻清零，避免 UI 进度闪烁。
                return
            }
            state = .waitingForHandsStable(progress: 0)
            stableStartUptime = nil
            stableReferenceHandPointOnPlaneWorld = nil
            lastBothHandsSeenUptime = nil
            return
        }
        lastBothHandsSeenUptime = nowUptime

        let handCenterWorld = (leftPalm + rightPalm) / 2

        let tableOriginWorld = SIMD3<Float>(tableWorldFromAnchor.columns.3.x, tableWorldFromAnchor.columns.3.y, tableWorldFromAnchor.columns.3.z)
        let yAxisWorld = simd_normalize(SIMD3<Float>(tableWorldFromAnchor.columns.1.x, tableWorldFromAnchor.columns.1.y, tableWorldFromAnchor.columns.1.z))

        let handPointOnPlaneWorld = projectPointOntoPlane(
            handCenterWorld,
            planeOriginWorld: tableOriginWorld,
            planeNormalWorld: yAxisWorld
        )

        if stableStartUptime == nil {
            stableStartUptime = nowUptime
            stableReferenceHandPointOnPlaneWorld = handPointOnPlaneWorld
        } else if let stableReferenceHandPointOnPlaneWorld {
            let delta = handPointOnPlaneWorld - stableReferenceHandPointOnPlaneWorld
            let deltaOnPlane = delta - yAxisWorld * simd_dot(delta, yAxisWorld)
            if simd_length(deltaOnPlane) >= Self.stableThresholdMeters {
                stableStartUptime = nowUptime
                self.stableReferenceHandPointOnPlaneWorld = handPointOnPlaneWorld
            }
        }

        let stableFor = nowUptime - (stableStartUptime ?? nowUptime)
        let progress = min(1.0, max(0.0, stableFor / Self.stableDurationSeconds))
        state = .waitingForHandsStable(progress: progress)

        guard progress >= 1.0 else { return }

        guard let worldFromKeyboard = computeWorldFromKeyboard(
            tableWorldFromAnchor: tableWorldFromAnchor,
            handPointOnPlaneWorld: handPointOnPlaneWorld,
            deviceWorldTransform: deviceWorldTransform
        ) else {
            state = .failed(message: "无法生成虚拟键盘姿态（桌面/设备姿态异常）")
            return
        }

        state = .ready(worldFromKeyboard: worldFromKeyboard)
    }

    private func computeWorldFromKeyboard(
        tableWorldFromAnchor: simd_float4x4,
        handPointOnPlaneWorld: SIMD3<Float>,
        deviceWorldTransform: simd_float4x4?
    ) -> simd_float4x4? {
        let yAxisWorld = simd_normalize(SIMD3<Float>(tableWorldFromAnchor.columns.1.x, tableWorldFromAnchor.columns.1.y, tableWorldFromAnchor.columns.1.z))

        let zAxisWorld: SIMD3<Float> = {
            if let deviceWorldTransform {
                let devicePosWorld = SIMD3<Float>(deviceWorldTransform.columns.3.x, deviceWorldTransform.columns.3.y, deviceWorldTransform.columns.3.z)
                let v = devicePosWorld - handPointOnPlaneWorld
                let vOnPlane = v - yAxisWorld * simd_dot(v, yAxisWorld)
                if simd_length(vOnPlane) > 1e-4 {
                    return simd_normalize(vOnPlane)
                }
            }

            let forward = SIMD3<Float>(tableWorldFromAnchor.columns.2.x, tableWorldFromAnchor.columns.2.y, tableWorldFromAnchor.columns.2.z)
            let forwardOnPlane = forward - yAxisWorld * simd_dot(forward, yAxisWorld)
            if simd_length(forwardOnPlane) > 1e-4 {
                return simd_normalize(forwardOnPlane)
            }

            return SIMD3<Float>(0, 0, 1)
        }()

        let xAxisWorld = simd_normalize(simd_cross(yAxisWorld, zAxisWorld))
        let zAxisOrtho = simd_normalize(simd_cross(xAxisWorld, yAxisWorld))

        if simd_length(xAxisWorld) < 1e-4 || simd_length(zAxisOrtho) < 1e-4 {
            return nil
        }

        let totalLength = VirtualPianoKeyGeometryService.totalKeyboardLengthMeters
        let keyDepth = VirtualPianoKeyGeometryService.whiteKeyDepthMeters
        let keyboardCenterLocal = SIMD3<Float>(totalLength / 2, 0, -keyDepth / 2)
        let originWorld = handPointOnPlaneWorld
            - xAxisWorld * keyboardCenterLocal.x
            - yAxisWorld * keyboardCenterLocal.y
            - zAxisOrtho * keyboardCenterLocal.z

        return simd_float4x4(columns: (
            SIMD4<Float>(xAxisWorld, 0),
            SIMD4<Float>(yAxisWorld, 0),
            SIMD4<Float>(zAxisOrtho, 0),
            SIMD4<Float>(originWorld, 1)
        ))
    }

    private func projectPointOntoPlane(
        _ pointWorld: SIMD3<Float>,
        planeOriginWorld: SIMD3<Float>,
        planeNormalWorld: SIMD3<Float>
    ) -> SIMD3<Float> {
        let v = pointWorld - planeOriginWorld
        let distanceAlongNormal = simd_dot(v, planeNormalWorld)
        return pointWorld - planeNormalWorld * distanceAlongNormal
    }
}
