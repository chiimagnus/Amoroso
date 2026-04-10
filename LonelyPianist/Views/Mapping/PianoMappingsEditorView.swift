import Observation
import SwiftUI

struct PianoMappingsEditorView: View {
    @Bindable var viewModel: LonelyPianistViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            pianoArea
                .frame(maxWidth: .infinity, minHeight: 320, alignment: .top)

            sidebar
                .frame(width: 320)
        }
        .padding(16)
    }

    private var pianoArea: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                PianoKeyboardView(
                    noteRange: 48...83,
                    highlightedNotes: Set(viewModel.pressedNotes),
                    labelsForNote: labelsForNote
                )
                    .frame(height: 220)

                Text("已显示音名与单键映射；键盘高亮实时跟随 MIDI pressed notes。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } label: {
            Text("Piano")
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProfileSectionView(viewModel: viewModel)
            modeAndInspectorPanel
            velocityPanel
        }
    }

    private var modeAndInspectorPanel: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Mode", selection: $viewModel.selectedTab) {
                    ForEach(LonelyPianistViewModel.EditorTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                Text("选中规则属性面板将在 P2 完整接入。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } label: {
            Text("Rule Inspector")
        }
    }

    private var velocityPanel: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Toggle(
                    "Enable Velocity",
                    isOn: Binding(
                        get: { viewModel.activeProfile?.payload.velocityEnabled ?? false },
                        set: { viewModel.setVelocityEnabled($0) }
                    )
                )

                HStack {
                    Text("Default Threshold")

                    Slider(
                        value: Binding(
                            get: { Double(viewModel.activeProfile?.payload.defaultVelocityThreshold ?? 100) },
                            set: { viewModel.setVelocityThreshold(Int($0.rounded())) }
                        ),
                        in: 1...127,
                        step: 1
                    )

                    Text("\(viewModel.activeProfile?.payload.defaultVelocityThreshold ?? 100)")
                        .frame(width: 30)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } label: {
            Text("Velocity")
        }
    }

    private var singleRuleOutputByNote: [Int: String] {
        guard let profile = viewModel.activeProfile else { return [:] }
        return profile.payload.singleKeyRules.reduce(into: [:]) { partialResult, rule in
            partialResult[rule.note] = rule.normalOutput
        }
    }

    private func labelsForNote(_ note: Int) -> PianoKeyLabels {
        PianoKeyLabels(
            noteName: MIDINote(note).name,
            mappingLabel: singleRuleOutputByNote[note]
        )
    }
}
