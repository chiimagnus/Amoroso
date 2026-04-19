import SwiftUI
import UniformTypeIdentifiers
import simd

struct ContentView: View {
    @Bindable var homeViewModel: HomeViewModel
    @Bindable var arGuideViewModel: ARGuideViewModel

    @State private var navigationPath: [MainFlowRoute] = []

    private enum MainFlowRoute: Hashable {
        case calibration
        case practice
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GroupBox("流程入口") {
                        VStack(alignment: .leading, spacing: 8) {
                            NavigationLink(value: MainFlowRoute.calibration) {
                                stepEntry(
                                    title: "Step 1 · 校准",
                                    subtitle: "捕获 A0 / C8 并保存钢琴几何。"
                                )
                            }

                            NavigationLink(value: MainFlowRoute.practice) {
                                stepEntry(
                                    title: "Step 2 · 开始练习",
                                    subtitle: "按高亮键位弹奏并推进练习步骤。"
                                )
                            }
                            .disabled(homeViewModel.canEnterPractice == false)
                            .opacity(homeViewModel.canEnterPractice ? 1.0 : 0.45)

                            Text("导入 MusicXML 后会生成可练习步骤。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                    }

                    GroupBox("状态") {
                        VStack(alignment: .leading, spacing: 10) {
                            LabeledContent("校准") {
                                Text(homeViewModel.calibrationStatusText)
                                    .foregroundStyle(.secondary)
                            }

                            LabeledContent("谱子") {
                                Text(homeViewModel.scoreStatusText)
                                    .foregroundStyle(.secondary)
                            }

                            if let stepCountText = homeViewModel.stepCountText {
                                LabeledContent("步骤") {
                                    Text(stepCountText)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text(homeViewModel.nextActionHint)
                                if let message = homeViewModel.calibrationStatusMessage {
                                    Text(message)
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }

                    if let importErrorMessage = homeViewModel.importErrorMessage {
                        GroupBox("导入错误") {
                            Text(importErrorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("孤独钢琴家")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: MainFlowRoute.self) { route in
                switch route {
                case .calibration:
                    CalibrationStepView(viewModel: arGuideViewModel)
                        .navigationTitle("Step 1 · 校准")
                case .practice:
                    PracticeStepView(viewModel: arGuideViewModel)
                        .navigationTitle("Step 2 · 开始练习")
                }
            }
            .toolbar {
                if navigationPath.isEmpty, homeViewModel.canImportScore {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("导入 MusicXML…") {
                            homeViewModel.isImporterPresented = true
                        }
                        .hoverEffect()
                    }
                }
            }
        }
        .buttonBorderShape(.roundedRectangle)
        .fileImporter(
            isPresented: $homeViewModel.isImporterPresented,
            allowedContentTypes: [.xml, .musicXML],
            allowsMultipleSelection: false
        ) { result in
            homeViewModel.handleImportResult(result)
        }
    }

    private func stepEntry(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview("主页 - 初始") {
    let appModel = AppModel()
    appModel.calibrationStatusMessage = "请重新校准"
    return ContentView(
        homeViewModel: HomeViewModel(appModel: appModel),
        arGuideViewModel: ARGuideViewModel(appModel: appModel)
    )
}

#Preview("主页 - 默认") {
    let appModel = AppModel()
    return ContentView(
        homeViewModel: HomeViewModel(appModel: appModel),
        arGuideViewModel: ARGuideViewModel(appModel: appModel)
    )
}

#Preview("主页 - 已校准") {
    let appModel = AppModel()
    appModel.calibration = PianoCalibration(
        a0: SIMD3<Float>(-0.7, 0.8, -1.0),
        c8: SIMD3<Float>(0.7, 0.8, -1.0),
        planeHeight: 0.8
    )
    appModel.calibrationStatusMessage = "已加载校准"
    return ContentView(
        homeViewModel: HomeViewModel(appModel: appModel),
        arGuideViewModel: ARGuideViewModel(appModel: appModel)
    )
}

#Preview("主页 - 已导入谱子") {
    let appModel = AppModel()
    appModel.calibration = PianoCalibration(
        a0: SIMD3<Float>(-0.7, 0.8, -1.0),
        c8: SIMD3<Float>(0.7, 0.8, -1.0),
        planeHeight: 0.8
    )
    appModel.setImportedSteps(
        [
            PracticeStep(tick: 0, notes: [PracticeStepNote(midiNote: 60, staff: nil)]),
            PracticeStep(tick: 480, notes: [PracticeStepNote(midiNote: 64, staff: nil)])
        ],
        file: nil
    )
    return ContentView(
        homeViewModel: HomeViewModel(appModel: appModel),
        arGuideViewModel: ARGuideViewModel(appModel: appModel)
    )
}
