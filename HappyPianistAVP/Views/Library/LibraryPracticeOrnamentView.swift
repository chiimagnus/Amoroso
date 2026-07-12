import SwiftUI

struct LibraryPracticeOrnamentView: View {
    @Bindable var viewModel: SongLibraryViewModel
    let isStartEnabled: Bool
    let onStartPractice: () -> Void
    let onImportMusicXML: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch viewModel.practicePreparationState {
                case .idle:
                    ContentUnavailableView(
                        "选择一首曲目",
                        systemImage: "music.note.list",
                        description: Text("练习信息和设置会显示在这里。")
                    )
                case .loading:
                    ScrollView {
                        LibraryPracticeSkeletonView()
                            .padding(20)
                    }
                    .scrollIndicators(.hidden)
                case let .failure(failure):
                    LibraryPracticeFailureView(
                        failure: failure,
                        wasRecordedInDiagnostics: viewModel.wasSelectedPreparationFailureRecorded,
                        onRetry: viewModel.retrySelectedPracticePreparation,
                        onImportMusicXML: onImportMusicXML
                    )
                    .padding(20)
                case let .ready(_, identity):
                    if let controller = viewModel.preparedRoundConfigurationController,
                       let presentation = viewModel.selectedPracticePresentation
                    {
                        LibraryPracticeReadyView(
                            roundConfigurationController: controller,
                            measureSpans: viewModel.preparedMeasureSpans,
                            presentation: presentation
                        )
                        .id(identity)
                    } else {
                        ScrollView {
                            LibraryPracticeSkeletonView()
                                .padding(20)
                        }
                        .scrollIndicators(.hidden)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                if let summary = viewModel.selectedPracticePresentation?.launchSummary {
                    Text(summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Button("去练习！", systemImage: "music.note", action: onStartPractice)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .frame(maxWidth: .infinity)
                    .disabled(isStartEnabled == false)
            }
            .padding(20)
        }
        .frame(width: 400)
    }
}

private struct LibraryPracticeReadyView: View {
    @Bindable var roundConfigurationController: PracticeRoundConfigurationController
    let measureOptions: [LibraryPracticeMeasureOption]
    let presentation: LibraryPracticePanelPresentation

    init(
        roundConfigurationController: PracticeRoundConfigurationController,
        measureSpans: [MusicXMLMeasureSpan],
        presentation: LibraryPracticePanelPresentation
    ) {
        self.roundConfigurationController = roundConfigurationController
        measureOptions = LibraryPracticeMeasureOption.make(from: measureSpans)
        self.presentation = presentation
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LibraryPracticeOverviewView(presentation: presentation)
                Divider()
                LibraryPracticePassageSettingsView(
                    roundConfigurationController: roundConfigurationController,
                    measureOptions: measureOptions
                )
                Divider()
                LibraryPracticeRoundSettingsView(
                    roundConfigurationController: roundConfigurationController
                )
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
    }
}

private struct LibraryPracticeOverviewView: View {
    let presentation: LibraryPracticePanelPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("练习概览")
                .font(.headline)

            LabeledContent("稳定小节") {
                Text("\(presentation.stableMeasureCount) / \(presentation.totalMeasureCount)")
                    .monospacedDigit()
            }

            Text(presentation.resumeText)
                .foregroundStyle(.secondary)

            if let hotspotTitle = presentation.hotspotTitle {
                Label("最近卡点：\(hotspotTitle)", systemImage: "scope")
                    .foregroundStyle(.secondary)
            }

            PracticeMeasureMapView(viewModel: presentation.measureMap)
        }
    }
}

private struct LibraryPracticePassageSettingsView: View {
    @Bindable var roundConfigurationController: PracticeRoundConfigurationController
    let measureOptions: [LibraryPracticeMeasureOption]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("练习片段")
                .font(.headline)

            Picker("开始小节", selection: startSelection) {
                ForEach(measureOptions) { option in
                    Text(option.title)
                        .tag(Optional(option.id))
                }
            }

            Picker("结束小节", selection: endSelection) {
                ForEach(availableEndOptions) { option in
                    Text(option.title)
                        .tag(Optional(option.id))
                }
            }
        }
    }

    private var startSelection: Binding<PracticeMeasureOccurrenceID?> {
        Binding(
            get: { roundConfigurationController.pendingPassage?.start },
            set: updateStart
        )
    }

    private var endSelection: Binding<PracticeMeasureOccurrenceID?> {
        Binding(
            get: { roundConfigurationController.pendingPassage?.end },
            set: updateEnd
        )
    }

    private var availableEndOptions: [LibraryPracticeMeasureOption] {
        guard let start = roundConfigurationController.pendingPassage?.start else {
            return measureOptions
        }
        return measureOptions.filter { $0.occurrenceIndex >= start.occurrenceIndex }
    }

    private func updateStart(_ newStart: PracticeMeasureOccurrenceID?) {
        guard let newStart,
              let fallbackEnd = measureOptions.last?.id
        else { return }
        let currentEnd = roundConfigurationController.pendingPassage?.end
        let resolvedEnd = currentEnd.map {
            $0.occurrenceIndex >= newStart.occurrenceIndex ? $0 : newStart
        } ?? fallbackEnd
        guard let passage = PracticePassage(start: newStart, end: resolvedEnd) else { return }
        roundConfigurationController.pendingPassage = passage
    }

    private func updateEnd(_ newEnd: PracticeMeasureOccurrenceID?) {
        guard let newEnd,
              let fallbackStart = measureOptions.first?.id
        else { return }
        let currentStart = roundConfigurationController.pendingPassage?.start
        let resolvedStart = currentStart.map {
            $0.occurrenceIndex <= newEnd.occurrenceIndex ? $0 : newEnd
        } ?? fallbackStart
        guard let passage = PracticePassage(start: resolvedStart, end: newEnd) else { return }
        roundConfigurationController.pendingPassage = passage
    }
}

private struct LibraryPracticeRoundSettingsView: View {
    @Bindable var roundConfigurationController: PracticeRoundConfigurationController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("本轮设置")
                .font(.headline)

            Picker("练习手", selection: $roundConfigurationController.pendingHandMode) {
                ForEach(PracticeHandMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            LabeledContent("速度") {
                Text(
                    roundConfigurationController.pendingTempoScale,
                    format: .percent.precision(.fractionLength(0))
                )
                .monospacedDigit()
            }

            Slider(
                value: $roundConfigurationController.pendingTempoScale,
                in: PracticeRoundConfiguration.supportedTempoRange,
                step: 0.05
            )

            Toggle("循环当前片段", isOn: $roundConfigurationController.pendingLoopEnabled)

            Stepper(
                "连续成功 \(roundConfigurationController.pendingRequiredSuccesses) 次",
                value: $roundConfigurationController.pendingRequiredSuccesses,
                in: PracticeRoundConfiguration.supportedSuccessRange
            )
        }
    }
}
