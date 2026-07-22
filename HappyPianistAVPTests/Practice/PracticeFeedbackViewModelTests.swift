import Foundation
@testable import HappyPianistAVP
import Testing

@Test @MainActor
func feedbackViewModelReplacesAndCancelsCue() {
    let viewModel = PracticeFeedbackViewModel(sleeper: NeverFeedbackSleeper())
    let event = PracticeFeedbackEvent(
        sequence: 1,
        sourceMeasureID: nil,
        kind: .roundSummaryReady
    )
    viewModel.present(event)
    #expect(viewModel.cue == event)
    viewModel.cancel()
    #expect(viewModel.cue == nil)
}

@Test @MainActor
func feedbackViewModelPresentsNeutralHandAndFingeringSources() throws {
    let viewModel = PracticeFeedbackViewModel(sleeper: NeverFeedbackSleeper())
    let event = PracticeFeedbackEvent(
        sequence: 1,
        sourceMeasureID: nil,
        kind: .roundSummaryReady
    )
    let issue = MusicalIssue(
        kind: .pitch,
        scoreRange: 0 ..< 480,
        dimensionResults: [PerformanceAssessmentDimensionResult(
            dimension: .exactPitch,
            outcome: .incorrect,
            evidenceStatus: .observed,
            sampleCount: 1,
            confidence: 0.8,
            evidence: []
        )],
        confidence: 0.8,
        provenance: MusicalIssueProvenance(
            planID: ScorePerformancePlanID(rawValue: "plan"),
            sourceGeneration: 1,
            rubricVersion: .capabilityAware
        )
    )
    let action = CoachingAction(
        kind: .pitchAccuracy,
        scoreRange: issue.scoreRange,
        handFocus: ScoreHandAssignment(hand: .right, provenance: .heuristic, confidence: 0.8),
        fingerings: [
            MusicXMLFingering(text: "1", hand: .right, provenance: .score),
            MusicXMLFingering(text: "2", hand: .right, provenance: .teacher),
        ],
        repeatCount: 1,
        completionCondition: CoachingCompletionCondition(
            target: .dimensionOutcome(dimension: .exactPitch, outcome: .correct)
        )
    )

    viewModel.present(event, coachingDecision: CoachingDecision(issue: issue, action: action))

    let presentation = try #require(viewModel.coachingPresentation)
    #expect(presentation.fingeringText == "1–2")
    #expect(presentation.sourceLabel.localizedStandardContains("推测"))
    #expect(presentation.sourceLabel.localizedStandardContains("原谱"))
    #expect(presentation.sourceLabel.localizedStandardContains("教师"))
    viewModel.cancel()
    #expect(viewModel.coachingPresentation == nil)
}

@Test @MainActor
func scenePresentationInvalidationIsSynchronous() {
    let viewModel = ARGuideViewModel(
        appState: AppState(),
        practiceSetupState: PracticeSetupState()
    )
    let event = PracticeFeedbackEvent(
        sequence: 1,
        sourceMeasureID: nil,
        kind: .roundSummaryReady
    )
    viewModel.practiceFeedbackViewModel.present(event)
    viewModel.practiceSessionViewModel.latestFeedbackEvent = event

    viewModel.invalidatePracticeFeedbackPresentation()

    #expect(viewModel.practiceFeedbackViewModel.cue == nil)
    #expect(viewModel.practiceSessionViewModel.latestFeedbackEvent == nil)
}

private struct NeverFeedbackSleeper: SleeperProtocol {
    func sleep(for _: Duration) async throws {
        try await Task.sleep(for: .seconds(60))
    }
}
