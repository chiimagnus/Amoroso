import ARKit
import Foundation
import Observation
import simd

@MainActor
@Observable
final class HandTrackingService {
    enum TrackingState: Equatable {
        case idle
        case running
        case unavailable(reason: String)
    }

    private(set) var state: TrackingState = .idle
    private(set) var fingerTipPositions: [String: SIMD3<Float>] = [:]
    private(set) var leftIndexFingerTipPosition: SIMD3<Float>?
    private(set) var rightIndexFingerTipPosition: SIMD3<Float>?
    private(set) var rightThumbTipPosition: SIMD3<Float>?

    private let session = ARKitSession()
    private let provider = HandTrackingProvider()
    private var updateTask: Task<Void, Never>?
    private var fingerTipUpdatesContinuation: AsyncStream<[String: SIMD3<Float>]>.Continuation?

    func fingerTipUpdatesStream() -> AsyncStream<[String: SIMD3<Float>]> {
        AsyncStream { continuation in
            fingerTipUpdatesContinuation?.finish()
            fingerTipUpdatesContinuation = continuation
            continuation.yield(fingerTipPositions)
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.fingerTipUpdatesContinuation = nil
                }
            }
        }
    }

    func start() {
        guard updateTask == nil else { return }
        guard HandTrackingProvider.isSupported else {
            state = .unavailable(reason: "此设备不支持手部追踪。")
            return
        }

        updateTask = Task {
            do {
                try await session.run([provider])
                await MainActor.run {
                    self.state = .running
                }
                for await update in provider.anchorUpdates {
                    let chiralityPrefix = "\(update.anchor.chirality)-"
                    guard update.anchor.isTracked else {
                        await MainActor.run {
                            self.fingerTipPositions = self.fingerTipPositions.filter { key, _ in
                                key.hasPrefix(chiralityPrefix) == false
                            }
                            switch update.anchor.chirality {
                            case .left:
                                self.leftIndexFingerTipPosition = nil
                            case .right:
                                self.rightIndexFingerTipPosition = nil
                                self.rightThumbTipPosition = nil
                            @unknown default:
                                break
                            }
                            self.fingerTipUpdatesContinuation?.yield(self.fingerTipPositions)
                        }
                        continue
                    }
                    let extracted = extractFingerTips(from: update.anchor)
                    await MainActor.run {
                        self.fingerTipPositions = self.fingerTipPositions.filter { key, _ in
                            key.hasPrefix(chiralityPrefix) == false
                        }
                        self.fingerTipPositions.merge(extracted.tips, uniquingKeysWith: { _, new in new })
                        switch update.anchor.chirality {
                        case .left:
                            self.leftIndexFingerTipPosition = extracted.indexFingerTip
                        case .right:
                            self.rightIndexFingerTipPosition = extracted.indexFingerTip
                            self.rightThumbTipPosition = extracted.thumbTip
                        @unknown default:
                            break
                        }
                        self.fingerTipUpdatesContinuation?.yield(self.fingerTipPositions)
                    }
                }
            } catch {
                if error is CancellationError {
                    await MainActor.run {
                        if case .running = self.state {
                            self.state = .idle
                        }
                    }
                } else {
                    await MainActor.run {
                        self.state = .unavailable(reason: error.localizedDescription)
                    }
                }
            }
            await MainActor.run {
                self.updateTask = nil
            }
        }
    }

    func stop() {
        updateTask?.cancel()
        updateTask = nil
        fingerTipUpdatesContinuation?.finish()
        fingerTipUpdatesContinuation = nil
        fingerTipPositions.removeAll()
        leftIndexFingerTipPosition = nil
        rightIndexFingerTipPosition = nil
        rightThumbTipPosition = nil
        if case .running = state {
            state = .idle
        }
    }

    private func extractFingerTips(
        from anchor: HandAnchor
    ) -> (tips: [String: SIMD3<Float>], indexFingerTip: SIMD3<Float>?, thumbTip: SIMD3<Float>?) {
        guard let handSkeleton = anchor.handSkeleton else { return ([:], nil, nil) }
        let jointNames: [HandSkeleton.JointName] = [
            .thumbTip,
            .indexFingerTip,
            .middleFingerTip,
            .ringFingerTip,
            .littleFingerTip
        ]

        var tips: [String: SIMD3<Float>] = [:]
        var indexFingerTip: SIMD3<Float>?
        var thumbTip: SIMD3<Float>?
        for jointName in jointNames {
            let joint = handSkeleton.joint(jointName)
            guard joint.isTracked else { continue }
            let worldTransform = anchor.originFromAnchorTransform * joint.anchorFromJointTransform
            let point = SIMD3<Float>(
                worldTransform.columns.3.x,
                worldTransform.columns.3.y,
                worldTransform.columns.3.z
            )
            tips["\(anchor.chirality)-\(jointName)"] = point
            switch jointName {
            case .indexFingerTip:
                indexFingerTip = point
            case .thumbTip:
                thumbTip = point
            default:
                break
            }
        }
        return (tips, indexFingerTip, thumbTip)
    }
}
