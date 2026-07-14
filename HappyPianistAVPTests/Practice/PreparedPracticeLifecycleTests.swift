import Foundation
@testable import HappyPianistAVP
import Testing

@Test
@MainActor
func clearingPreparedPracticePreventsSessionReplacementFromResurrectingSong() async {
    let appState = AppState()
    appState.practiceSetupState.selectedPianoModeID = "kept-mode"
    let guide = makeLifecycleGuide(appState: appState)
    let prepared = makeLifecyclePreparedPractice()

    #expect(await guide.applyPreparedPractice(prepared, isCurrent: { true }))
    #expect(guide.practiceSessionViewModel.songIdentity == prepared.identity)
    #expect(guide.latestPreparedPractice?.identity == prepared.identity)

    await guide.clearPreparedPracticeForLaunch()
    await guide.clearPreparedPracticeForLaunch()

    #expect(guide.practiceSessionViewModel.songIdentity == nil)
    #expect(guide.practiceSessionViewModel.steps.isEmpty)
    #expect(guide.latestPreparedPractice == nil)
    #expect(appState.practiceSetupState.preparedPracticeIdentity == nil)
    #expect(appState.practiceSetupState.importedSteps.isEmpty)
    #expect(appState.practiceSetupState.selectedPianoModeID == "kept-mode")

    await guide.replacePracticeSessionViewModel()

    #expect(guide.practiceSessionViewModel.songIdentity == nil)
    #expect(guide.practiceSessionViewModel.steps.isEmpty)
    #expect(guide.latestPreparedPractice == nil)
}

@Test
@MainActor
func clearWinsWhilePreparedPracticeAwaitsProgressRestore() async {
    let repository = SuspendedLifecycleProgressRepository()
    let coordinator = PracticeProgressCoordinator(repository: repository)
    let appState = AppState()
    let guide = makeLifecycleGuide(appState: appState, progressCoordinator: coordinator)
    let prepared = makeLifecyclePreparedPractice()
    let applyTask = Task { @MainActor in
        await guide.applyPreparedPractice(prepared, isCurrent: { true })
    }
    await repository.waitForRequest(identity: prepared.identity)

    await guide.clearPreparedPracticeForLaunch()
    await repository.resume(identity: prepared.identity)
    let applied = await applyTask.value

    #expect(applied == false)
    #expect(guide.latestPreparedPractice == nil)
    #expect(appState.practiceSetupState.preparedPracticeIdentity == nil)
    #expect(appState.practiceSetupState.importedSteps.isEmpty)
    #expect(guide.practiceSessionViewModel.songIdentity == nil)
    #expect(guide.practiceSessionViewModel.steps.isEmpty)
    #expect(guide.practiceSessionViewModel.activeRoundConfiguration == nil)
    #expect(guide.practiceSessionViewModel.progressGeneration == nil)
    #expect(guide.practiceSessionViewModel.sessionProgress == nil)
}

@Test
@MainActor
func clearingShutdownPracticeSessionInstallsFreshEmptyReplacement() async {
    let appState = AppState()
    let guide = makeLifecycleGuide(appState: appState)
    let prepared = makeLifecyclePreparedPractice()
    #expect(await guide.applyPreparedPracticeForLaunch(prepared, isCurrent: { true }) == .applied)
    let shutdownSession = guide.practiceSessionViewModel
    await shutdownSession.flushAndShutdown()
    #expect(shutdownSession.hasShutdown)

    await guide.clearPreparedPracticeForLaunch()

    #expect(guide.practiceSessionViewModel !== shutdownSession)
    #expect(guide.practiceSessionViewModel.hasShutdown == false)
    #expect(guide.practiceSessionViewModel.songIdentity == nil)
    #expect(guide.practiceSessionViewModel.steps.isEmpty)
    #expect(guide.latestPreparedPractice == nil)
    #expect(appState.practiceSetupState.preparedPracticeIdentity == nil)
}

@MainActor
private func makeLifecycleGuide(
    appState: AppState,
    progressCoordinator: PracticeProgressCoordinator? = nil
) -> ARGuideViewModel {
    ARGuideViewModel(
        appState: appState,
        practiceSetupState: appState.practiceSetupState,
        pianoModeRegistry: PianoModeRegistryService(modes: []),
        makePracticeSessionViewModel: { _ in
            PracticeSessionViewModel(
                pressDetectionService: PressDetectionService(),
                chordAttemptAccumulator: ChordAttemptAccumulator(),
                sleeper: TaskSleeper(),
                progressCoordinator: progressCoordinator
            )
        }
    )
}

private func makeLifecyclePreparedPractice() -> PreparedPractice {
    let songID = UUID()
    return PreparedPractice(
        identity: PracticeSongIdentity(songID: songID, scoreRevision: "revision"),
        steps: [
            PracticeStep(tick: 0, notes: [PracticeStepNote(midiNote: 60, staff: 1)]),
        ],
        file: ImportedMusicXMLFile(
            fileName: "Lifecycle",
            storedURL: URL(fileURLWithPath: "/dev/null"),
            importedAt: .now
        ),
        tempoMap: MusicXMLTempoMap(tempoEvents: []),
        pedalTimeline: nil,
        fermataTimeline: nil,
        attributeTimeline: nil,
        highlightGuides: [],
        measureSpans: [
            MusicXMLMeasureSpan(
                partID: "P1",
                measureNumber: 1,
                sourceMeasureIndex: 0,
                sourceMeasureNumberToken: "1",
                occurrenceIndex: 0,
                startTick: 0,
                endTick: 480
            ),
        ],
        unsupportedNoteCount: 0
    )
}

private actor SuspendedLifecycleProgressRepository: PracticeProgressRepositoryProtocol {
    private var continuations: [
        PracticeSongIdentity: CheckedContinuation<SongPracticeProgress?, Never>
    ] = [:]

    func load() -> PracticeProgressLoadResult { .loaded(PracticeProgressDocument()) }

    func progress(for identity: PracticeSongIdentity) async -> SongPracticeProgress? {
        await withCheckedContinuation { continuation in
            continuations[identity] = continuation
        }
    }

    func waitForRequest(identity: PracticeSongIdentity) async {
        while continuations[identity] == nil {
            await Task.yield()
        }
    }

    func resume(identity: PracticeSongIdentity) {
        continuations.removeValue(forKey: identity)?.resume(returning: nil)
    }

    func upsert(_: SongPracticeProgress) {}
    func remove(songID _: UUID) {}
}
