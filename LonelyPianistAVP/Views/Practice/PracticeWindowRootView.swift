import SwiftUI

struct PracticeWindowRootView: View {
    @Environment(WindowTransitionState.self) private var windowState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.scenePhase) private var scenePhase

    @Bindable var viewModel: ARGuideViewModel

    init(viewModel: ARGuideViewModel) {
        _viewModel = Bindable(wrappedValue: viewModel)
    }

    var body: some View {
        PracticeStepView(
            viewModel: viewModel,
            onBackToLibrary: {
                windowState.beginTransition(from: .practice, to: .library)
                openWindow(id: WindowID.library)
            },
            onRestartFromTypePicker: {
                windowState.resetToPreparation(reason: "user restarted from practice window")
                windowState.beginTransition(from: .practice, to: .preparation)
                openWindow(id: WindowID.preparation)
            }
        )
        // .frame(minWidth: 1200, idealWidth: 1600, minHeight: 520, idealHeight: 620)
        .onChange(of: scenePhase) {
            guard scenePhase == .active else { return }
            dismissPendingSourceIfNeeded()
        }
        .onAppear {
            dismissPendingSourceIfNeeded()
        }
        .onDisappear {
            guard windowState.pendingTransition == nil else { return }
            openWindow(id: WindowID.library)
        }
    }

    private func dismissPendingSourceIfNeeded() {
        guard let transition = windowState.consumePendingTransition(to: .practice) else { return }
        withTransaction(\.dismissBehavior, .destructive) {
            dismissWindow(id: transition.fromWindowID)
        }
    }
}

struct PracticeSettingsWindowRootView: View {
    @Environment(WindowTransitionState.self) private var windowState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    @Bindable var viewModel: ARGuideViewModel
    @State private var isTakeLibraryPresented = false

    init(viewModel: ARGuideViewModel) {
        _viewModel = Bindable(wrappedValue: viewModel)
    }

    var body: some View {
        PracticeSettingsView(
            virtualPerformerEnabled: Binding(
                get: { viewModel.aiPerformanceViewModel.isVirtualPerformerEnabled },
                set: { viewModel.setPracticeVirtualPerformerEnabled($0) }
            ),
            backendStatusText: viewModel.backendStatusText,
            lastImprovStatusText: viewModel.lastImprovStatusText,
            recordingSourceText: viewModel.recordingSourceText,
            isAIPerformanceActive: viewModel.isAIPerformanceActive,
            isVirtualPianoMode: viewModel.isVirtualPianoMode,
            isBluetoothMIDIMode: viewModel.isBluetoothMIDIMode,
            gazePlaneDiskStatusText: viewModel.gazePlaneDiskStatusText,
            isRecording: viewModel.isRecording,
            recordingElapsedText: viewModel.recordingElapsedText,
            canStartRecording: viewModel.canRecord && viewModel.isAIPerformanceActive == false && viewModel.takePlaybackViewModel.isPlaying == false,
            onBackToLibrary: {
                viewModel.practiceSessionViewModel.shutdown()
                windowState.beginTransition(from: .practice, to: .library)
                openWindow(id: WindowID.library)
                dismissWindow(id: WindowID.practiceSettings)
            },
            onStartRecording: {
                viewModel.startRecording()
            },
            onStopRecording: {
                viewModel.stopRecording()
            },
            onOpenTakeLibrary: {
                isTakeLibraryPresented = true
            },
            onRetryVirtualPianoPlacement: {
                viewModel.retryVirtualPianoPlacement()
            },
            onRequestSessionRebuild: {
                viewModel.replacePracticeSessionViewModel()
            },
            onDebugInjectAIImprovPhrase: {
                #if DEBUG
                    viewModel.debugInjectAIImprovPhrase()
                #endif
            }
        )
        .sheet(isPresented: $isTakeLibraryPresented) {
            NavigationStack {
                TakeLibraryView(
                    takes: viewModel.takeLibraryTakes,
                    playbackViewModel: viewModel.takePlaybackViewModel,
                    isRecording: viewModel.isRecording,
                    errorMessage: viewModel.takeLibraryErrorMessage,
                    onErrorDismiss: { viewModel.dismissTakeLibraryError() },
                    onRename: { id, name in viewModel.renameTake(id: id, name: name) },
                    onDelete: { id in viewModel.deleteTake(id: id) },
                    onClearAll: { viewModel.clearAllTakes() },
                    makeMIDIExport: { take in try viewModel.makeMIDIExport(for: take) }
                )
                .navigationTitle("录制库")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("关闭") {
                            isTakeLibraryPresented = false
                        }
                    }
                }
            }
            .frame(minWidth: 400, minHeight: 500)
        }
    }
}
