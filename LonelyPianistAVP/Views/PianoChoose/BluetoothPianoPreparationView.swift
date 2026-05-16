import SwiftUI

struct BluetoothMIDIPreparationView: View {
    @Environment(AppRouter.self) private var router
    @Bindable var viewModel: ARGuideViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("真实钢琴（蓝牙 MIDI）")
                .font(.largeTitle.weight(.bold))

            BluetoothMIDIConnectionSection { sourceCount in
                router.flowState.bluetoothMIDISourceCount = sourceCount
            }

            CalibrationStepView(
                viewModel: viewModel,
                onExit: { router.exitToTypePicker(reason: "user exited from bluetooth midi preparation") }
            )

            HStack {
                Button("返回钢琴类型选择") {
                    router.exitToTypePicker(reason: "user tapped back from bluetooth midi preparation")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("下一步：去选曲") {
                    router.goToLibrary()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!router.canProceedToLibrary)
            }
        }
        .padding(24)
        .frame(minWidth: 560, idealWidth: 700)
        .onChange(of: viewModel.calibrationPhase) {
            router.flowState.isCalibrationCompleted = (viewModel.calibrationPhase == .completed)
        }
    }
}
