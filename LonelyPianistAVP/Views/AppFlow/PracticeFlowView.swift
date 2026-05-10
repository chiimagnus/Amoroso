import SwiftUI

struct PracticeFlowView: View {
    @Environment(AppRouter.self) private var router
    @Bindable var viewModel: ARGuideViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("返回钢琴类型选择") {
                    router.exitToTypePicker(reason: "user tapped back from practice")
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            PracticeStepView(viewModel: viewModel)
        }
        .frame(minWidth: 920, idealWidth: 1200, minHeight: 320, idealHeight: 360)
    }
}
