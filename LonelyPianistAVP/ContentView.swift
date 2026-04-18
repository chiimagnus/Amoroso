import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    @State private var isImporterPresented = false

    private let importService: MusicXMLImportServiceProtocol = MusicXMLImportService()
    private let parser: MusicXMLParserProtocol = MusicXMLParser()
    private let stepBuilder: PracticeStepBuilderProtocol = PracticeStepBuilder()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HomeHeaderView()
                HomeStatusSectionView()
                HomeScoreSectionView(isImporterPresented: $isImporterPresented)
                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .buttonBorderShape(.roundedRectangle)
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.xml, .musicXML],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .sheet(isPresented: arGuideSheetIsPresented) {
            ARGuideSheetView()
                .environment(appModel)
        }
        .ornament(attachmentAnchor: .scene(.bottom), contentAlignment: .center) {
            HomeOrnamentBar(isImporterPresented: $isImporterPresented)
                .environment(appModel)
        }
    }

    private var arGuideSheetIsPresented: Binding<Bool> {
        Binding(
            get: { appModel.immersiveSpaceState != .closed },
            set: { isPresented in
                guard isPresented == false else { return }
                guard appModel.immersiveSpaceState == .open else { return }
                Task { @MainActor in
                    appModel.immersiveSpaceState = .inTransition
                    await dismissImmersiveSpace()
                }
            }
        )
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        do {
            guard let selectedURL = try result.get().first else {
                return
            }
            let importedFile = try importService.importFile(from: selectedURL)
            let score = try parser.parse(fileURL: importedFile.storedURL)
            let buildResult = stepBuilder.buildSteps(from: score)
            if buildResult.unsupportedNoteCount > 0 {
                appModel.importErrorMessage = "已导入（忽略了 \(buildResult.unsupportedNoteCount) 个不支持的音符）。"
            }
            appModel.setImportedSteps(buildResult.steps, file: importedFile)
        } catch {
            appModel.importErrorMessage = "导入失败：\(error.localizedDescription)"
        }
    }
}

#Preview {
    ContentView()
        .environment(AppModel())
}

private struct HomeHeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("孤独钢琴家")
                .font(.largeTitle)
                .fontWeight(.semibold)
            Text("按步骤完成：校准 → 导入谱子 → AR 引导练习。")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

private struct HomeStatusSectionView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        GroupBox("状态") {
            VStack(alignment: .leading, spacing: 10) {
                LabeledContent("AR 引导") {
                    Text(appModel.immersiveSpaceState == .open ? "运行中" : "已停止")
                        .foregroundStyle(.secondary)
                }

                LabeledContent("校准") {
                    Text(appModel.calibration == nil ? "未设置" : "已加载")
                        .foregroundStyle(.secondary)
                }

                LabeledContent("谱子") {
                    Text(appModel.importedFile?.fileName ?? "未导入")
                        .foregroundStyle(.secondary)
                }

                if appModel.importedSteps.isEmpty == false {
                    LabeledContent("步骤") {
                        Text("\(appModel.importedSteps.count)")
                            .foregroundStyle(.secondary)
                    }
                }

                Text(nextActionHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let message = appModel.calibrationStatusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var nextActionHint: String {
        if appModel.calibration == nil {
            return "下一步：开始 AR 引导 → 在弹出的表单里依次点“设置 A0 / 设置 C8”并在空间轻点捕获 → 保存。"
        }
        if appModel.importedSteps.isEmpty {
            return "下一步：导入 MusicXML（.musicxml 或 .xml）。"
        }
        return "下一步：开始 AR 引导，在表单里进入“练习”并按高亮键位弹奏。"
    }
}

private struct HomeScoreSectionView: View {
    @Environment(AppModel.self) private var appModel
    @Binding var isImporterPresented: Bool

    var body: some View {
        GroupBox("谱子") {
            VStack(alignment: .leading, spacing: 10) {
                Text("导入 MusicXML 后会生成练习步骤。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let importErrorMessage = appModel.importErrorMessage {
                    Text(importErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button("导入 MusicXML…") {
                    isImporterPresented = true
                }
                .buttonStyle(.bordered)
                .hoverEffect()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct HomeOrnamentBar: View {
    @Environment(AppModel.self) private var appModel
    @Binding var isImporterPresented: Bool

    var body: some View {
        HStack(spacing: 12) {
            ToggleImmersiveSpaceButton()

            Button("导入 MusicXML…") {
                isImporterPresented = true
            }
            .buttonStyle(.bordered)
            .disabled(appModel.immersiveSpaceState != .closed)
            .hoverEffect()
        }
        .controlSize(.large)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassBackgroundEffect()
    }
}

private struct ARGuideSheetView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ARGuideStatusSectionView()

                    if appModel.calibration == nil {
                        CalibrationSectionView()
                    } else if appModel.importedSteps.isEmpty {
                        GroupBox("练习") {
                            Text("请先在主窗口导入 MusicXML，然后再回来开始练习。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        PracticeSectionView()
                    }

                    if let message = appModel.calibrationStatusMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer(minLength: 0)
                }
                .padding(20)
            }
            .navigationTitle("AR 引导")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("停止") {
                        Task { @MainActor in
                            await dismissImmersiveSpace()
                            dismiss()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .hoverEffect()
                }
            }
        }
        .buttonBorderShape(.roundedRectangle)
        .presentationDetents([.medium, .large])
    }
}

private struct ARGuideStatusSectionView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        GroupBox("状态") {
            VStack(alignment: .leading, spacing: 8) {
                Text(handTrackingStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(practiceStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var handTrackingStatusText: String {
        switch appModel.handTrackingService.state {
        case .idle:
            return "手部：空闲"
        case .running:
            return "手部：运行中（\(appModel.handTrackingService.fingerTipPositions.count) 个点）"
        case .unavailable(let reason):
            return "手部：不可用（\(reason)）"
        }
    }

    private var practiceStatusText: String {
        switch appModel.practiceSessionViewModel.state {
        case .idle:
            return "练习：空闲"
        case .ready:
            return "练习：就绪"
        case .guiding(let index):
            return "练习：引导中（第 \(index + 1) 步）"
        case .completed:
            return "练习：已完成"
        }
    }
}

private struct CalibrationSectionView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        GroupBox("校准") {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("步骤：")
                        .font(.callout)
                        .fontWeight(.semibold)
                    Text("（提示：每次进入 AR 引导都会要求重新校准。）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("1) 点“设置 A0”，然后在空间轻点一次，把点放到 A0 键中心上方。")
                    Text("2) 点“设置 C8”，同样捕获 C8 键中心上方。")
                    Text("3) 点“保存”。重启后仍能加载即为通过。")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(captureHintText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ControlGroup {
                    Button("设置 A0") { appModel.pendingCalibrationCaptureAnchor = .a0 }
                        .hoverEffect()
                    Button("设置 C8") { appModel.pendingCalibrationCaptureAnchor = .c8 }
                        .hoverEffect()
                    Button("保存") { appModel.saveCalibrationIfPossible() }
                        .buttonStyle(.borderedProminent)
                        .disabled(appModel.calibrationCaptureService.buildCalibration() == nil)
                        .hoverEffect()
                }

                Button("手动微调") {
                    appModel.calibrationCaptureService.updateReticleEstimate(nil)
                }
                .buttonStyle(.bordered)
                .hoverEffect()

                if appModel.calibrationCaptureService.mode == .manualFallback {
                    ManualAdjustRowView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var captureHintText: String {
        guard let pending = appModel.pendingCalibrationCaptureAnchor else {
            return "提示：先在空间轻点一次可更新准星位置；选择“设置 A0/C8”后，再轻点一次完成捕获。"
        }
        return "待捕获：\(pending == .a0 ? "A0" : "C8")（现在在空间轻点一次完成捕获）"
    }
}

private struct ManualAdjustRowView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("微调（手动模式）")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Button("A0 左移") { adjust(.a0, x: -0.01) }
                    .buttonStyle(.bordered)
                    .hoverEffect()
                Button("A0 右移") { adjust(.a0, x: 0.01) }
                    .buttonStyle(.bordered)
                    .hoverEffect()
                Button("C8 左移") { adjust(.c8, x: -0.01) }
                    .buttonStyle(.bordered)
                    .hoverEffect()
                Button("C8 右移") { adjust(.c8, x: 0.01) }
                    .buttonStyle(.bordered)
                    .hoverEffect()
            }
        }
    }

    private func adjust(_ anchor: CalibrationAnchorPoint, x: Float) {
        appModel.calibrationCaptureService.adjust(anchor: anchor, delta: SIMD3<Float>(x, 0, 0))
    }
}

private struct PracticeSectionView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        GroupBox("练习") {
            VStack(alignment: .leading, spacing: 12) {
                Text("按键位高亮弹奏；也可以用下方按钮推进步骤。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ControlGroup {
                    Button("跳过") { appModel.practiceSessionViewModel.skip() }
                        .hoverEffect()
                    Button("标记为正确") { appModel.practiceSessionViewModel.markCorrect() }
                        .hoverEffect()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
