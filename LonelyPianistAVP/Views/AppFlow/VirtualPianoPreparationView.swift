import SwiftUI

struct VirtualPianoPreparationView: View {
    @Environment(AppRouter.self) private var router
    @Bindable var viewModel: ARGuideViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("虚拟钢琴准备")
                .font(.largeTitle.weight(.bold))

            Text("放置虚拟钢琴到空间中")
                .font(.title3)
                .foregroundStyle(.secondary)

            Spacer()

            HStack {
                Button("返回钢琴类型选择") {
                    router.exitToTypePicker(reason: "user tapped back from virtual preparation")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("下一步：去选曲") {
                    router.goToLibrary()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.practiceLocalizationState != .ready)
            }
        }
        .padding(24)
        .frame(minWidth: 560, idealWidth: 700)
    }
}
