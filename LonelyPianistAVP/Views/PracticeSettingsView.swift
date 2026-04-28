import SwiftUI

struct PracticeSettingsView: View {
    @AppStorage("practiceAudioRecognitionDebugOverlayEnabled") private var practiceAudioRecognitionDebugOverlayEnabled =
        false
    @AppStorage("debugKeyboardAxesOverlayEnabled") private var debugKeyboardAxesOverlayEnabled = false
    @AppStorage("practiceTimingDebugEnabled") private var practiceTimingDebugEnabled = false
    @AppStorage("practiceManualAdvanceMode") private var manualAdvanceModeRawValue = ManualAdvanceMode.step.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("调试：显示音频识别 overlay", isOn: $practiceAudioRecognitionDebugOverlayEnabled)
            Toggle("调试：显示键盘坐标轴（X/Y/Z）", isOn: $debugKeyboardAxesOverlayEnabled)
            Toggle("调试：输出节奏日志（autoplay / 回放）", isOn: $practiceTimingDebugEnabled)

            Picker("手动前进方式", selection: $manualAdvanceModeRawValue) {
                ForEach(ManualAdvanceMode.allCases) { mode in
                    Text(mode.title).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .frame(minWidth: 320)
    }
}

#Preview("练习设置") {
    PracticeSettingsView()
}
