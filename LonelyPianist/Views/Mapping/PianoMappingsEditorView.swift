import AppKit
import Observation
import SwiftUI

struct PianoMappingsEditorView: View {
    @Bindable var viewModel: LonelyPianistViewModel
    @State private var bindingTargetNote: Int?
    @State private var bindingMessage = "点击琴键进入绑定态；按 Esc 可取消。"
    @State private var selectedSingleNote: Int?
    @State private var selectedChordRuleID: UUID?
    @State private var chordSelectedNotes: Set<Int> = []
    @State private var chordDraftOutput: KeyStroke = KeyStroke(keyCode: 8, modifiers: [.command])
    @State private var chordMultiSelectEnabled = false
    @State private var isInspectorPresented = false

    var body: some View {
        pianoArea
            .padding(16)
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
                cancelBindingOnFocusLoss()
            }
            .onChange(of: viewModel.activeConfig?.id) { _, _ in
                resetEditorState()
            }
            .onChange(of: chordMultiSelectEnabled) { _, isEnabled in
                bindingTargetNote = nil
                if isEnabled {
                    bindingMessage = "Chord 多选已开启：点击琴键可加入/移除和弦。"
                } else {
                    chordSelectedNotes.removeAll()
                    selectedChordRuleID = nil
                    bindingMessage = "Chord 多选已关闭：点击琴键将进入 Single 绑定态。"
                }
            }
            .toolbar {
                ToolbarItem {
                    Button {
                        isInspectorPresented.toggle()
                    } label: {
                        Label(isInspectorPresented ? "Hide Inspector" : "Show Inspector", systemImage: "sidebar.right")
                    }
                }
            }
            .inspector(isPresented: $isInspectorPresented) {
                inspectorPanel
            }
    }

    private var pianoArea: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                PianoKeyboardView(
                    noteRange: 48...83,
                    highlightedNotes: Set(viewModel.pressedNotes),
                    selectedNotes: selectedNotes,
                    labelsForNote: labelsForNote,
                    onTapNote: handlePianoTap
                )
                .frame(height: 220)

                Text(bindingMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } label: {
            Text("Piano")
        }
        .overlay(alignment: .topLeading) {
            if let bindingTargetNote {
                bindingOverlay(note: bindingTargetNote)
                    .padding(12)
            }
        }
    }

    private var inspectorPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Chord Multi-Select", isOn: $chordMultiSelectEnabled)

                Divider()

                singleInspector

                Divider()

                chordInspector

                Divider()

                velocityPanel
            }
            .padding(14)
        }
        .frame(minWidth: 300)
    }

    private var singleInspector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Single")
                .font(.headline)

            if let note = selectedSingleNote {
                let rule = singleRuleByNote[note]
                Text("Note: \(MIDINote(note).name)")
                    .font(.subheadline)
                Text("Normal: \(rule?.output.displayLabel ?? "-")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("High Velocity: \(highVelocityLabel(for: rule))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Button("Bind") {
                        beginBinding(note: note)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Clear") {
                        clearSingleRule(note: note)
                    }
                    .buttonStyle(.bordered)
                    .disabled(rule == nil)
                }
            } else {
                Text("点击钢琴键后可绑定单键输出。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var chordInspector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Chord")
                .font(.headline)

            if chordRules.isEmpty {
                Text("暂无 Chord 规则")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(chordRules) { rule in
                        Button {
                            selectChordRule(rule)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(MIDINoteParser.stringify(notes: rule.notes, separator: " "))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text("Out: \(rule.output.displayLabel)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(rule.id == selectedChordRuleID ? Color.accentColor.opacity(0.18) : Color(nsColor: .textBackgroundColor))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Text("Selected: \(MIDINoteParser.stringify(notes: chordSelectedNotes.sorted(), separator: " "))")
                .font(.caption)
                .foregroundStyle(.secondary)

            keyStrokeEditor(title: "Output", keyStroke: $chordDraftOutput)

            HStack(spacing: 8) {
                Button("Save") {
                    saveChordRule()
                }
                .buttonStyle(.borderedProminent)
                .disabled(chordSelectedNotes.isEmpty)

                Button("Delete", role: .destructive) {
                    deleteSelectedChordRule()
                }
                .buttonStyle(.bordered)
                .disabled(selectedChordRuleID == nil)
            }

            Text("Trigger: 严格相等（当前按下集合必须与规则集合完全一致）")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var velocityPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Velocity")
                .font(.headline)

            Toggle(
                "Enable Velocity",
                isOn: Binding(
                    get: { viewModel.activeConfig?.payload.velocityEnabled ?? false },
                    set: { viewModel.setVelocityEnabled($0) }
                )
            )

            HStack {
                Text("Threshold")

                Slider(
                    value: Binding(
                        get: { Double(viewModel.activeConfig?.payload.defaultVelocityThreshold ?? 100) },
                        set: { viewModel.setVelocityThreshold(Int($0.rounded())) }
                    ),
                    in: 1...127,
                    step: 1
                )

                Text("\(viewModel.activeConfig?.payload.defaultVelocityThreshold ?? 100)")
                    .frame(width: 30)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var selectedNotes: Set<Int> {
        if chordMultiSelectEnabled {
            return chordSelectedNotes
        }

        guard let selectedSingleNote else { return [] }
        return [selectedSingleNote]
    }

    private var singleRuleByNote: [Int: SingleKeyMappingRule] {
        guard let config = viewModel.activeConfig else { return [:] }
        return config.payload.singleKeyRules.reduce(into: [:]) { partialResult, rule in
            partialResult[rule.note] = rule
        }
    }

    private var singleRuleOutputByNote: [Int: String] {
        singleRuleByNote.reduce(into: [:]) { partialResult, pair in
            partialResult[pair.key] = pair.value.output.displayLabel
        }
    }

    private var chordRules: [ChordMappingRule] {
        guard let rules = viewModel.activeConfig?.payload.chordRules else { return [] }
        return rules.sorted { lhs, rhs in
            let lhsKey = MIDINoteParser.stringify(notes: lhs.notes, separator: " ")
            let rhsKey = MIDINoteParser.stringify(notes: rhs.notes, separator: " ")
            return lhsKey < rhsKey
        }
    }

    private func labelsForNote(_ note: Int) -> PianoKeyLabels {
        PianoKeyLabels(
            noteName: MIDINote(note).name,
            mappingLabel: singleRuleOutputByNote[note]
        )
    }

    private func beginBinding(note: Int) {
        selectedSingleNote = note
        bindingTargetNote = note
        bindingMessage = "正在绑定 \(MIDINote(note).name)：请输入 1 个按键（Esc 取消）。"
    }

    private func clearSingleRule(note: Int) {
        viewModel.clearSingleKeyMapping(note: note)
        bindingMessage = "已清除 \(MIDINote(note).name) 的 Single 绑定。"
    }

    private func handlePianoTap(note: Int) {
        if chordMultiSelectEnabled {
            toggleChordNoteSelection(note: note)
            return
        }

        beginBinding(note: note)
    }

    @ViewBuilder
    private func bindingOverlay(note: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("绑定 \(MIDINote(note).name)")
                .font(.headline)

            Text("等待下一次本地按键输入")
                .font(.caption)
                .foregroundStyle(.secondary)

            OneShotKeyCaptureView { event in
                handleCaptureEvent(event, note: note)
            }
            .frame(width: 1, height: 1)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
        )
    }

    private func handleCaptureEvent(_ event: NSEvent, note: Int) {
        if isEscapeEvent(event) {
            bindingTargetNote = nil
            bindingMessage = "已取消绑定 \(MIDINote(note).name)。"
            return
        }

        if Self.modifierOnlyKeyCodes.contains(event.keyCode) {
            bindingMessage = "已忽略纯修饰键，请输入一个普通按键。"
            return
        }

        let blockedModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
        if !event.modifierFlags.intersection(blockedModifiers).isEmpty {
            bindingMessage = "请勿使用 Command/Control/Option 组合键。"
            return
        }

        viewModel.setSingleKeyMapping(note: note, keyCode: event.keyCode)
        bindingTargetNote = nil
        let normal = KeyStroke(keyCode: event.keyCode)
        let high = normal.adding(.shift)
        bindingMessage = "已绑定 \(MIDINote(note).name)：Out=\(normal.displayLabel) / High=\(high.displayLabel)"
    }

    private func highVelocityLabel(for rule: SingleKeyMappingRule?) -> String {
        guard let rule else { return "-" }
        let high = KeyStroke(keyCode: rule.output.keyCode, modifiers: [.shift])
        return high.displayLabel
    }

    private func isEscapeEvent(_ event: NSEvent) -> Bool {
        event.keyCode == 53 || event.characters == "\u{1B}"
    }

    private func cancelBindingOnFocusLoss() {
        guard let note = bindingTargetNote else { return }
        bindingTargetNote = nil
        bindingMessage = "窗口失焦，已取消绑定 \(MIDINote(note).name)。"
    }

    private func toggleChordNoteSelection(note: Int) {
        bindingTargetNote = nil

        if chordSelectedNotes.contains(note) {
            chordSelectedNotes.remove(note)
        } else {
            chordSelectedNotes.insert(note)
        }

        bindingMessage = "Chord 选中：\(MIDINoteParser.stringify(notes: chordSelectedNotes.sorted(), separator: " "))"
    }

    private func selectChordRule(_ rule: ChordMappingRule) {
        selectedChordRuleID = rule.id
        chordSelectedNotes = Set(rule.notes)
        chordDraftOutput = rule.output
        bindingMessage = "已选中 Chord 规则：\(MIDINoteParser.stringify(notes: rule.notes, separator: " "))"
    }

    private func saveChordRule() {
        let notes = chordSelectedNotes.sorted()
        guard !notes.isEmpty else {
            bindingMessage = "请先在键盘上选择 Chord notes。"
            return
        }

        if let selectedChordRuleID {
            viewModel.updateChordRule(
                ChordMappingRule(id: selectedChordRuleID, notes: notes, output: chordDraftOutput)
            )
            bindingMessage = "Chord 规则已更新。"
        } else {
            viewModel.createChordRule(notes: notes, output: chordDraftOutput)
            selectedChordRuleID = nil
            chordSelectedNotes.removeAll()
            bindingMessage = "Chord 规则已创建，并已清空编辑态。"
        }
    }

    private func deleteSelectedChordRule() {
        guard let selectedChordRuleID else { return }
        viewModel.deleteChordRule(id: selectedChordRuleID)
        self.selectedChordRuleID = nil
        chordSelectedNotes.removeAll()
        bindingMessage = "Chord 规则已删除。"
    }

    private func resetEditorState() {
        bindingTargetNote = nil
        selectedSingleNote = nil
        selectedChordRuleID = nil
        chordSelectedNotes.removeAll()
        chordDraftOutput = KeyStroke(keyCode: 8, modifiers: [.command])
        chordMultiSelectEnabled = false
        bindingMessage = "点击琴键进入绑定态；按 Esc 可取消。"
    }

    @ViewBuilder
    private func keyStrokeEditor(title: String, keyStroke: Binding<KeyStroke>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(title): \(keyStroke.wrappedValue.displayLabel)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text("KeyCode")
                    .font(.caption)
                TextField(
                    "0",
                    value: keyCodeBinding(for: keyStroke),
                    format: .number
                )
                .textFieldStyle(.roundedBorder)
                .frame(width: 90)
            }

            HStack(spacing: 10) {
                Toggle("\u{2318}", isOn: modifierBinding(for: keyStroke, modifier: .command))
                Toggle("\u{2325}", isOn: modifierBinding(for: keyStroke, modifier: .option))
                Toggle("\u{2303}", isOn: modifierBinding(for: keyStroke, modifier: .control))
                Toggle("\u{21E7}", isOn: modifierBinding(for: keyStroke, modifier: .shift))
            }
            .toggleStyle(.checkbox)
            .font(.caption)
        }
    }

    private func keyCodeBinding(for keyStroke: Binding<KeyStroke>) -> Binding<Int> {
        Binding(
            get: { Int(keyStroke.wrappedValue.keyCode) },
            set: { rawValue in
                let clamped = max(0, min(rawValue, Int(UInt16.max)))
                keyStroke.wrappedValue.keyCode = UInt16(clamped)
            }
        )
    }

    private func modifierBinding(for keyStroke: Binding<KeyStroke>, modifier: KeyStrokeModifiers) -> Binding<Bool> {
        Binding(
            get: { keyStroke.wrappedValue.modifiers.contains(modifier) },
            set: { isEnabled in
                if isEnabled {
                    keyStroke.wrappedValue.modifiers.insert(modifier)
                } else {
                    keyStroke.wrappedValue.modifiers.remove(modifier)
                }
            }
        )
    }

    private static let modifierOnlyKeyCodes: Set<UInt16> = [
        54, 55, // command
        56, 60, // shift
        57, // caps lock
        58, 61, // option
        59, 62, // control
        63 // function
    ]
}

private struct OneShotKeyCaptureView: NSViewRepresentable {
    let onKeyDown: (NSEvent) -> Void

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onKeyDown = onKeyDown
        view.promoteToFirstResponder()
        return view
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.onKeyDown = onKeyDown
        nsView.promoteToFirstResponder()
    }

    final class KeyCaptureNSView: NSView {
        var onKeyDown: ((NSEvent) -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            promoteToFirstResponder()
        }

        override func keyDown(with event: NSEvent) {
            onKeyDown?(event)
        }

        fileprivate func promoteToFirstResponder() {
            DispatchQueue.main.async { [weak self] in
                guard let self, let window else { return }
                guard window.isKeyWindow else { return }
                if window.firstResponder !== self {
                    window.makeFirstResponder(self)
                }
            }
        }
    }
}
