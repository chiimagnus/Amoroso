import Foundation
@testable import HappyPianistAVP

func makeTestPreparedPractice(
    identity: PracticeSongIdentity = PracticeSongIdentity(songID: UUID(), scoreRevision: "test"),
    steps: [PracticeStep] = [
        PracticeStep(
            tick: 0,
            notes: [PracticeStepNote(midiNote: 60, staff: 1, handAssignment: .unknown)]
        ),
    ],
    file: ImportedMusicXMLFile = ImportedMusicXMLFile(
        fileName: "Test",
        storedURL: URL(fileURLWithPath: "/dev/null"),
        importedAt: .now
    ),
    tempoMap: MusicXMLTempoMap = MusicXMLTempoMap(tempoEvents: []),
    pedalTimeline: MusicXMLPedalTimeline? = nil,
    fermataTimeline: MusicXMLFermataTimeline? = nil,
    attributeTimeline: MusicXMLAttributeTimeline? = nil,
    highlightGuides: [PianoHighlightGuide] = [],
    measureSpans: [MusicXMLMeasureSpan] = [
        MusicXMLMeasureSpan(
            partID: "P1",
            measureNumber: 1,
            sourceMeasureIndex: 0,
            sourceMeasureNumberToken: "1",
            occurrenceIndex: 0,
            startTick: 0,
            endTick: MusicXMLTempoMap.ticksPerQuarter
        ),
    ],
    unsupportedNoteCount: Int = 0,
    scoreContext: PreparedPracticeScoreContext = makeTestPreparedPracticeScoreContext(),
    performancePlan: ScorePerformancePlan? = nil
) -> PreparedPractice {
    PreparedPractice(
        identity: identity,
        performancePlan: performancePlan ?? makeTestScorePerformancePlan(
            identity: identity,
            steps: steps,
            scoreContext: scoreContext
        ),
        steps: steps,
        file: file,
        tempoMap: tempoMap,
        pedalTimeline: pedalTimeline,
        fermataTimeline: fermataTimeline,
        attributeTimeline: attributeTimeline,
        highlightGuides: highlightGuides,
        measureSpans: measureSpans,
        unsupportedNoteCount: unsupportedNoteCount,
        scoreContext: scoreContext
    )
}

func makeTestScorePerformancePlan(
    identity: PracticeSongIdentity,
    steps: [PracticeStep],
    scoreContext: PreparedPracticeScoreContext = makeTestPreparedPracticeScoreContext()
) -> ScorePerformancePlan {
    var ordinal = 0
    var noteEvents: [ScorePerformanceNoteEvent] = []

    for step in steps {
        for note in step.notes {
            let generatedSourceNoteID = MusicXMLSourceNoteID(
                partID: scoreContext.structuralPartID,
                sourceMeasureIndex: 0,
                sourceMeasureNumberToken: "1",
                staff: note.staff,
                voice: note.voice,
                sourceOrdinal: ordinal
            )
            let sourceNoteIDs = note.sourceNoteIDs.isEmpty ? [generatedSourceNoteID] : note.sourceNoteIDs
            let sourceNoteID = sourceNoteIDs[0]
            let performedNoteID = MusicXMLPerformedNoteID(sourceID: sourceNoteID, occurrenceIndex: 0)
            let performedOnTick = step.tick + note.onTickOffset
            noteEvents.append(ScorePerformanceNoteEvent(
                id: ScorePerformanceNoteEventID(performedNoteID: performedNoteID, generatedOrdinal: nil),
                sourceNoteID: sourceNoteID,
                performedNoteID: performedNoteID,
                contributingSourceNoteIDs: sourceNoteIDs,
                contributingPerformedNoteIDs: [performedNoteID],
                purpose: .source,
                writtenOnTick: step.tick,
                writtenOffTick: step.tick + MusicXMLTempoMap.ticksPerQuarter,
                performedOnTick: performedOnTick,
                performedOffTick: performedOnTick + MusicXMLTempoMap.ticksPerQuarter,
                writtenPitch: nil,
                midiNote: note.midiNote,
                velocityResolution: ScorePerformanceVelocityResolution(
                    baseVelocity: Int(note.velocity),
                    curveVelocity: nil,
                    articulationDelta: 0,
                    unclampedVelocity: Int(note.velocity),
                    velocity: note.velocity
                ),
                staff: note.staff ?? 1,
                voice: note.voice ?? 1,
                handAssignment: note.handAssignment,
                fingeringText: note.fingeringText,
                timingProvenance: []
            ))
            ordinal += 1
        }
    }

    return ScorePerformancePlan(
        id: ScorePerformancePlanID(rawValue: "test:\(identity.songID.uuidString):\(identity.scoreRevision)"),
        sourceScoreIdentity: ScorePerformanceSourceIdentity(
            songID: identity.songID,
            scoreRevision: identity.scoreRevision,
            logicalInstrumentID: scoreContext.logicalInstrument.id
        ),
        order: scoreContext.orderSelection,
        resolution: ScorePerformanceTickResolution(ticksPerQuarter: MusicXMLTempoMap.ticksPerQuarter),
        noteEvents: noteEvents,
        tempoEvents: [],
        controllerEvents: [],
        annotations: [],
        approximations: []
    )
}

func makeTestScorePerformancePlan(
    from score: MusicXMLScore,
    expressivity: MusicXMLExpressivityOptions = MusicXMLExpressivityOptions(),
    handAssignments: [MusicXMLSourceNoteID: ScoreHandAssignment] = [:],
    performanceTimingEnabled: Bool = false
) -> ScorePerformancePlan {
    // ponytail: fixture scores are single logical pianos; multi-instrument tests must pass an explicit plan.
    let memberPartIDs = Set(score.notes.map(\.partID)).sorted()
    let logicalInstrument = MusicXMLLogicalInstrument(
        id: "test-piano",
        memberPartIDs: memberPartIDs,
        classification: .piano,
        evidence: []
    )
    let timingSchedule = ScoreTimingScheduleBuilder().build(
        notes: score.notes,
        performanceTimingEnabled: performanceTimingEnabled,
        graceEnabled: expressivity.graceEnabled,
        logicalInstruments: [logicalInstrument],
        arpeggiateEnabled: expressivity.arpeggiateEnabled
    )
    let velocityResolver = MusicXMLVelocityResolver(
        dynamicEvents: score.dynamicEvents,
        wedgeEvents: score.wedgeEvents,
        wedgeEnabled: expressivity.wedgeEnabled
    )
    return ScorePerformancePlanBuilder().build(
        sourceIdentity: ScorePerformanceSourceIdentity(
            songID: UUID(),
            scoreRevision: "test",
            logicalInstrumentID: logicalInstrument.id
        ),
        order: MusicXMLOrderSelection(requested: .written, applied: .written),
        logicalInstrument: logicalInstrument,
        notes: score.notes,
        timingSchedule: timingSchedule,
        velocityResolver: velocityResolver,
        expressivity: expressivity,
        handAssignments: handAssignments
    )
}
