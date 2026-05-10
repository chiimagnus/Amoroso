import SwiftUI

struct PracticeFlowView: View {
    @Environment(AppRouter.self) private var router
    @Bindable var viewModel: ARGuideViewModel

    var body: some View {
        VStack(spacing: 0) {
            PracticeStepView(
                viewModel: viewModel,
                onExit: { router.exitToTypePicker(reason: "user exited from practice") }
            )
        }
        .frame(minWidth: 920, idealWidth: 1200, minHeight: 320, idealHeight: 360)
    }
}
