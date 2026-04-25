import SwiftUI

struct CalibrationStepView: View {
    @Bindable var viewModel: ARGuideViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace

    @State private var hasRequestedImmersiveOpen = false
    @State private var isStepVisible = false

    var body: some View {
        ZStack {
            CalibrationCardContainer(
                stage: CalibrationCardStage(phase: viewModel.calibrationPhase),
                storedCalibration: viewModel.storedCalibration,
                isReticleReadyToConfirm: viewModel.calibrationCaptureService.isReticleReadyToConfirm,
                errorMessage: {
                    if case let .error(message) = viewModel.calibrationPhase {
                        return message
                    }
                    return nil
                }(),
                onReturnHome: { dismiss() }
            )

            CalibrationTransitionOverlay(
                isVisible: viewModel.calibrationPhase == .transitionA0 ||
                    viewModel.calibrationPhase == .transitionC8
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            isStepVisible = true
            viewModel.beginCalibrationGuidedFlow()
            guard hasRequestedImmersiveOpen == false else { return }
            hasRequestedImmersiveOpen = true

            Task { @MainActor in
                let openError = await viewModel.openImmersiveForStep(
                    mode: .calibration,
                    using: openImmersiveSpace
                )
                if let openError {
                    viewModel.presentCalibrationError(message: openError)
                }

                if isStepVisible == false {
                    await viewModel.closeImmersiveForStep(using: dismissImmersiveSpace)
                    await viewModel.recoverImmersiveStateIfStuck()
                }
            }
        }
        .onDisappear {
            isStepVisible = false
            hasRequestedImmersiveOpen = false
            viewModel.endCalibrationGuidedFlow()
            Task { @MainActor in
                await viewModel.closeImmersiveForStep(using: dismissImmersiveSpace)
                await viewModel.recoverImmersiveStateIfStuck()
            }
        }
    }
}

private enum CalibrationCardStage: Hashable {
    case capturingA0
    case capturingC8
    case completed
    case error

    init(phase: ARGuideViewModel.CalibrationPhase) {
        switch phase {
            case .capturingA0, .transitionA0:
                self = .capturingA0
            case .capturingC8, .transitionC8:
                self = .capturingC8
            case .completed:
                self = .completed
            case .error:
                self = .error
        }
    }
}

private struct CalibrationCardContainer: View {
    let stage: CalibrationCardStage
    let storedCalibration: StoredWorldAnchorCalibration?
    let isReticleReadyToConfirm: Bool
    let errorMessage: String?
    let onReturnHome: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 12)

            switch stage {
                case .capturingA0:
                    CalibrationCaptureCard(
                        step: .a0,
                        isA0Locked: false,
                        isReticleReadyToConfirm: isReticleReadyToConfirm
                    )
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        )
                    )

                case .capturingC8:
                    CalibrationCaptureCard(
                        step: .c8,
                        isA0Locked: true,
                        isReticleReadyToConfirm: isReticleReadyToConfirm
                    )
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        )
                    )

                case .completed:
                    CalibrationCompletionCard(
                        estimatedKeyboardWidthText: CalibrationCompletionCard.estimatedKeyboardWidthText(
                            storedCalibration: storedCalibration
                        ),
                        onReturnHome: onReturnHome
                    )
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        )
                    )

                case .error:
                    CalibrationErrorCard(
                        message: errorMessage ?? "手部追踪不可用，无法进入校准流程。",
                        onReturnHome: onReturnHome
                    )
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        )
                    )
            }

            Spacer(minLength: 12)
        }
        .animation(.easeInOut(duration: 0.5), value: stage)
    }
}

private struct CalibrationCaptureCard: View {
    let step: CalibrationAnchorPoint
    let isA0Locked: Bool
    let isReticleReadyToConfirm: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                CalibrationProgressIndicator(
                    isA0Complete: isA0Locked,
                    isC8Current: step == .c8,
                    isC8Complete: false
                )

                Spacer()

                KeyboardEdgeLabels(
                    isA0Locked: isA0Locked,
                    currentStep: step
                )
            }

            KeyboardGuideStrip(
                highlight: step,
                isA0Locked: isA0Locked
            )

            Text(step == .a0 ? "左手食指放在 A0 键，准星变绿后捏合确认。" : "左手食指移到 C8 键，准星变绿后捏合确认。")
                .font(.callout)

            Text(isReticleReadyToConfirm ? "已就绪：现在可捏合确认" : "等待稳定：准星变绿后再捏合确认")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: 560)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.primary.opacity(0.12))
        }
    }
}

private struct CalibrationCompletionCard: View {
    let estimatedKeyboardWidthText: String?
    let onReturnHome: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            CalibrationProgressIndicator(isA0Complete: true, isC8Current: false, isC8Complete: true)

            Image(systemName: "checkmark.circle")
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(.green)

            VStack(spacing: 6) {
                Text("校准完成")
                    .font(.title2.weight(.semibold))

                if let estimatedKeyboardWidthText {
                    Text(estimatedKeyboardWidthText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Button("返回首页") {
                onReturnHome()
            }
            .buttonStyle(.borderedProminent)
            .hoverEffect()
        }
        .padding(18)
        .frame(maxWidth: 560)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.primary.opacity(0.12))
        }
    }

    static func estimatedKeyboardWidthText(storedCalibration: StoredWorldAnchorCalibration?) -> String? {
        guard let storedCalibration else { return nil }
        let estimatedMeters = storedCalibration.whiteKeyWidth * 52
        let estimatedCentimeters = Int((estimatedMeters * 100).rounded())
        return "键盘宽度 · ~\(estimatedCentimeters) cm"
    }
}

private struct CalibrationErrorCard: View {
    let message: String
    let onReturnHome: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(.red)

            VStack(spacing: 6) {
                Text("无法校准")
                    .font(.title2.weight(.semibold))
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("返回首页") {
                onReturnHome()
            }
            .buttonStyle(.borderedProminent)
            .hoverEffect()
        }
        .padding(18)
        .frame(maxWidth: 560)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.primary.opacity(0.12))
        }
    }
}

private struct CalibrationTransitionOverlay: View {
    let isVisible: Bool

    var body: some View {
        if isVisible {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 80, weight: .semibold))
                .foregroundStyle(.green)
                .padding(28)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.45, dampingFraction: 0.72), value: isVisible)
        }
    }
}

private struct CalibrationProgressIndicator: View {
    let isA0Complete: Bool
    let isC8Current: Bool
    let isC8Complete: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isA0Complete ? "checkmark.circle" : "circle.inset.filled")
                .foregroundStyle(isA0Complete ? .green : .primary)
            Image(systemName: c8SymbolName)
                .foregroundStyle(c8ForegroundStyle)
        }
        .font(.title3.weight(.semibold))
        .symbolRenderingMode(.hierarchical)
    }

    private var c8SymbolName: String {
        if isC8Complete {
            return "checkmark.circle"
        }
        return isC8Current ? "circle.inset.filled" : "circle"
    }

    private var c8ForegroundStyle: Color {
        if isC8Complete {
            return .green
        }
        return isC8Current ? .primary : .secondary
    }
}

private struct KeyboardEdgeLabels: View {
    let isA0Locked: Bool
    let currentStep: CalibrationAnchorPoint

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                Text("A0")
                if isA0Locked {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                } else if currentStep == .a0 {
                    Image(systemName: "arrow.up")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .font(.callout.weight(.semibold))

            HStack(spacing: 4) {
                Text("C8")
                if currentStep == .c8 {
                    Image(systemName: "arrow.up")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .font(.callout.weight(.semibold))
        }
        .foregroundStyle(.secondary)
    }
}

private struct KeyboardGuideStrip: View {
    let highlight: CalibrationAnchorPoint
    let isA0Locked: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.secondary.opacity(0.12))

            HStack(spacing: 0) {
                KeyboardSegment(
                    color: isA0Locked ? .green : (highlight == .a0 ? .blue : .secondary.opacity(0.2)),
                    isHighlighted: highlight == .a0 || isA0Locked
                )
                KeyboardSegment(
                    color: highlight == .c8 ? .blue : .secondary.opacity(0.2),
                    isHighlighted: highlight == .c8
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(4)
        }
        .frame(height: 44)
    }
}

private struct KeyboardSegment: View {
    let color: Color
    let isHighlighted: Bool

    var body: some View {
        Rectangle()
            .fill(isHighlighted ? color.opacity(0.75) : color.opacity(0.45))
            .frame(maxWidth: .infinity)
    }
}

#Preview("Step 1 - A0") {
    let appModel = AppModel()
    let viewModel = ARGuideViewModel(appModel: appModel)
    viewModel.setCalibrationPhaseForPreview(.capturingA0)
    return CalibrationStepView(viewModel: viewModel)
}

#Preview("Step 1 - C8") {
    let appModel = AppModel()
    let viewModel = ARGuideViewModel(appModel: appModel)
    viewModel.setCalibrationPhaseForPreview(.capturingC8)
    return CalibrationStepView(viewModel: viewModel)
}

#Preview("Step 1 - 完成") {
    let appModel = AppModel()
    appModel.storedCalibration = StoredWorldAnchorCalibration(
        a0AnchorID: UUID(),
        c8AnchorID: UUID(),
        whiteKeyWidth: 0.0235
    )
    let viewModel = ARGuideViewModel(appModel: appModel)
    viewModel.setCalibrationPhaseForPreview(.completed)
    return CalibrationStepView(viewModel: viewModel)
}

#Preview("Step 1 - 错误") {
    let appModel = AppModel()
    let viewModel = ARGuideViewModel(appModel: appModel)
    viewModel.setCalibrationPhaseForPreview(.error(message: "手部追踪不可用：此设备不支持手部追踪。"))
    return CalibrationStepView(viewModel: viewModel)
}
