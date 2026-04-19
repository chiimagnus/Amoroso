import SwiftUI

struct PracticeStepView: View {
    @Bindable var viewModel: ARGuideViewModel

    var body: some View {
        Form {
            Section("状态") {
                LabeledContent("练习") {
                    Text(viewModel.practiceStatusText)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("进度") {
                    Text(viewModel.practiceProgressText)
                        .foregroundStyle(.secondary)
                }
            }

            Section("控制") {
                Text("按键位高亮弹奏；也可以使用下方按钮推进步骤。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ViewThatFits {
                    AnyLayout(HStackLayout(spacing: 10)) {
                        practiceButtons
                    }
                    AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) {
                        practiceButtons
                    }
                }
            }
        }
        .buttonBorderShape(.roundedRectangle)
    }

    @ViewBuilder
    private var practiceButtons: some View {
        Button("跳过") { viewModel.skipStep() }
            .buttonStyle(.bordered)
            .hoverEffect()
            .disabled(viewModel.canControlPractice == false)

        Button("标记为正确") { viewModel.markCorrect() }
            .buttonStyle(.borderedProminent)
            .hoverEffect()
            .disabled(viewModel.canControlPractice == false)
    }
}

#Preview("Step 2") {
    PracticeStepView(viewModel: ARGuideViewModel(appModel: AppModel()))
}
