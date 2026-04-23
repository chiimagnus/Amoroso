import SwiftUI

struct PracticeSettingsView: View {
    @AppStorage("practiceMusicXMLStructureEnabled") private var isMusicXMLStructureEnabled = false
    @AppStorage("practiceMusicXMLPerformanceTimingEnabled") private var isMusicXMLPerformanceTimingEnabled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("启用结构跳转/反复", isOn: $isMusicXMLStructureEnabled)

            Text("默认关闭。开启后会在后续版本支持 repeat/ending、D.S./D.C./coda/segno 等曲式跳转。")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Toggle("启用 performance timing（attack/release）", isOn: $isMusicXMLPerformanceTimingEnabled)

            Text("默认关闭。仅影响自动播放的起音/释音时序，不影响 tick→秒 的 tempo 主链路。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(minWidth: 320)
    }
}

#Preview("练习设置") {
    PracticeSettingsView()
}
