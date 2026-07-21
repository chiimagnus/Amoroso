@testable import HappyPianistAVP
import Testing

@Test
func performanceDimensionsMapToMusicalIssueTaxonomy() {
    let expected: [PerformanceAssessmentDimension: MusicalIssueKind] = [
        .exactPitch: .pitch,
        .extraNotes: .pitch,
        .missingNotes: .pitch,
        .onset: .onset,
        .tempoRelativeTiming: .tempo,
        .chordSpread: .chordSpread,
        .duration: .duration,
        .release: .duration,
        .articulation: .articulation,
        .velocity: .dynamicContour,
        .dynamicContour: .dynamicContour,
        .voicing: .voicing,
        .pedalTiming: .pedal,
        .pedalValue: .pedal,
        .tempoContinuity: .tempo,
        .phraseContinuity: .phrase,
    ]

    #expect(expected.count == PerformanceAssessmentDimension.allCases.count)
    for dimension in PerformanceAssessmentDimension.allCases {
        #expect(dimension.musicalIssueKind == expected[dimension])
    }
}

@Test
func musicalIssueRetainsAssessmentEvidenceAndBoundsConfidence() {
    let dimension = PerformanceAssessmentDimensionResult(
        dimension: .onset,
        outcome: .incorrect,
        evidenceStatus: .observed,
        measurement: PerformanceAssessmentMeasurement(value: 0.12, unit: .seconds),
        sampleCount: 3,
        confidence: 0.8,
        evidence: []
    )
    let provenance = MusicalIssueProvenance(
        planID: ScorePerformancePlanID(rawValue: "plan"),
        sourceGeneration: 4,
        rubricVersion: .capabilityAware
    )

    let issue = MusicalIssue(
        kind: .onset,
        scoreRange: 480 ..< 960,
        dimensionResults: [dimension],
        confidence: 1.2,
        provenance: provenance
    )

    #expect(issue.scoreRange == 480 ..< 960)
    #expect(issue.dimensionResults == [dimension])
    #expect(issue.confidence == 1)
    #expect(issue.provenance == provenance)

    let unknownConfidence = MusicalIssue(
        kind: .evidence,
        scoreRange: 480 ..< 960,
        dimensionResults: [dimension],
        confidence: .infinity,
        provenance: provenance
    )
    #expect(unknownConfidence.confidence == nil)
}

@Test
func coachingActionCarriesExecutableParametersAndNormalizesBounds() {
    let issue = makeCoachingIssue()
    let handFocus = ScoreHandAssignment(
        hand: .left,
        provenance: .score,
        confidence: 0.9
    )
    let completion = CoachingCompletionCondition(
        target: .dimensionOutcome(dimension: .onset, outcome: .correct),
        consecutiveAssessments: 0
    )
    let action = CoachingAction(
        kind: .onsetAlignment,
        scoreRange: issue.scoreRange,
        tempoRatio: 0.2,
        handFocus: handFocus,
        voiceFocus: CoachingVoiceFocus(partID: "P1", staff: 2, voice: 1),
        repeatCount: 0,
        referenceUse: .manualReplay,
        cueUse: .metronome,
        completionCondition: completion
    )
    let decision = CoachingDecision(issue: issue, action: action)

    #expect(action.tempoRatio == PracticeRoundConfiguration.supportedTempoRange.lowerBound)
    #expect(action.handFocus == handFocus)
    #expect(action.voiceFocus == CoachingVoiceFocus(partID: "P1", staff: 2, voice: 1))
    #expect(action.repeatCount == 1)
    #expect(action.referenceUse == .manualReplay)
    #expect(action.cueUse == .metronome)
    #expect(action.completionCondition.consecutiveAssessments == 1)
    #expect(decision.issue == issue)
    #expect(decision.action == action)
}

private func makeCoachingIssue() -> MusicalIssue {
    let result = PerformanceAssessmentDimensionResult(
        dimension: .onset,
        outcome: .incorrect,
        evidenceStatus: .observed,
        sampleCount: 2,
        confidence: 0.8,
        evidence: []
    )
    return MusicalIssue(
        kind: .onset,
        scoreRange: 0 ..< 480,
        dimensionResults: [result],
        confidence: 0.8,
        provenance: MusicalIssueProvenance(
            planID: ScorePerformancePlanID(rawValue: "plan"),
            sourceGeneration: 1,
            rubricVersion: .capabilityAware
        )
    )
}
