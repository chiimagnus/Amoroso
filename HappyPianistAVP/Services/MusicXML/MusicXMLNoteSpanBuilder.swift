import Foundation

struct MusicXMLNoteSpanBuilder {
    private struct Key: Hashable {
        let partID: String
        let midiNote: Int
        let staff: Int
        let voice: Int
    }

    func buildSpans(
        from notes: [MusicXMLNoteEvent],
        performanceTimingEnabled: Bool = false,
        expressivity: MusicXMLExpressivityOptions = MusicXMLExpressivityOptions(),
        interpretationProfile: MusicXMLInterpretationProfile = .generic
    ) -> [MusicXMLNoteSpan] {
        let timingSchedule = ScoreTimingScheduleBuilder().build(
            notes: notes,
            performanceTimingEnabled: performanceTimingEnabled,
            interpretationProfile: interpretationProfile
        )
        let orderedNoteIndices = notes.indices.sorted { lhsIndex, rhsIndex in
            let lhs = notes[lhsIndex]
            let rhs = notes[rhsIndex]
            if lhs.tick != rhs.tick { return lhs.tick < rhs.tick }
            return (lhs.midiNote ?? -1) < (rhs.midiNote ?? -1)
        }

        let gracePlan = expressivity.graceEnabled ? GracePlan(notes: notes) : nil
        let arpeggiatePlan = expressivity.arpeggiateEnabled ? ArpeggiatePlan(notes: notes) : nil

        var output: [MusicXMLNoteSpan] = []
        output.reserveCapacity(orderedNoteIndices.count)

        var activeSpanIndexByKey: [Key: Int] = [:]

        for noteIndex in orderedNoteIndices {
            let note = notes[noteIndex]
            let timing = timingSchedule[noteIndex]
            guard note.isRest == false else { continue }
            if note.isGrace, expressivity.graceEnabled == false { continue }
            guard let midiNote = note.midiNote else { continue }

            let staff = note.staff ?? 1
            let voice = note.voice ?? 1
            let key = Key(partID: note.partID, midiNote: midiNote, staff: staff, voice: voice)
            let category: Category = if note.tieStart, note.tieStop {
                .middle
            } else if note.tieStart {
                .start
            } else if note.tieStop {
                .end
            } else {
                .normal
            }

            switch category {
            case .start:
                if activeSpanIndexByKey[key] != nil {
                    activeSpanIndexByKey[key] = nil
                }

                let arpeggiateOffset = note.isGrace ? 0 : (arpeggiatePlan?.offsetTicksByNoteIndex[noteIndex] ?? 0)
                let baseTick = note.tick + max(0, arpeggiateOffset)
                let onTick = baseTick + timing.onsetOffsetTicks
                let offTick = max(onTick, baseTick + max(0, note.durationTicks))
                let span = MusicXMLNoteSpan(
                    midiNote: midiNote,
                    staff: staff,
                    voice: voice,
                    onTick: onTick,
                    offTick: offTick
                )
                output.append(span)
                activeSpanIndexByKey[key] = output.count - 1
            case .middle:
                if let existingIndex = activeSpanIndexByKey[key] {
                    let existing = output[existingIndex]
                    output[existingIndex] = MusicXMLNoteSpan(
                        midiNote: existing.midiNote,
                        staff: existing.staff,
                        voice: existing.voice,
                        onTick: existing.onTick,
                        offTick: existing.offTick + max(0, note.durationTicks)
                    )
                } else {
                    let arpeggiateOffset = note.isGrace ? 0 : (arpeggiatePlan?.offsetTicksByNoteIndex[noteIndex] ?? 0)
                    let baseTick = note.tick + max(0, arpeggiateOffset)
                    let onTick = baseTick + timing.onsetOffsetTicks
                    let offTick = max(onTick, baseTick + max(0, note.durationTicks))
                    let span = MusicXMLNoteSpan(
                        midiNote: midiNote,
                        staff: staff,
                        voice: voice,
                        onTick: onTick,
                        offTick: offTick
                    )
                    output.append(span)
                    activeSpanIndexByKey[key] = output.count - 1
                }
            case .end:
                let releaseTicks = timing.releaseOffsetTicks
                if let existingIndex = activeSpanIndexByKey[key] {
                    let existing = output[existingIndex]
                    output[existingIndex] = MusicXMLNoteSpan(
                        midiNote: existing.midiNote,
                        staff: existing.staff,
                        voice: existing.voice,
                        onTick: existing.onTick,
                        offTick: max(
                            existing.onTick,
                            existing.offTick + max(0, note.durationTicks) + releaseTicks
                        )
                    )
                    activeSpanIndexByKey[key] = nil
                } else {
                    let arpeggiateOffset = note.isGrace ? 0 : (arpeggiatePlan?.offsetTicksByNoteIndex[noteIndex] ?? 0)
                    let baseTick = note.tick + max(0, arpeggiateOffset)
                    let onTick = baseTick + timing.onsetOffsetTicks
                    output.append(
                        MusicXMLNoteSpan(
                            midiNote: midiNote,
                            staff: staff,
                            voice: voice,
                            onTick: onTick,
                            offTick: max(
                                onTick,
                                baseTick + max(0, note.durationTicks) + releaseTicks
                            )
                        )
                    )
                }
            case .normal:
                let plannedGrace = note.isGrace ? gracePlan?.scheduleByNoteIndex[noteIndex] : nil
                let arpeggiateOffset = note.isGrace ? 0 : (arpeggiatePlan?.offsetTicksByNoteIndex[noteIndex] ?? 0)
                let baseTick = (plannedGrace?.onTick ?? note.tick) + max(0, arpeggiateOffset)
                let rawDurationTicks = if let plannedGrace {
                    plannedGrace.durationTicks
                } else if let reduction = gracePlan?.durationReductionTicksByKey[GraceKey(
                    partID: note.partID,
                    staff: staff,
                    voice: voice,
                    tick: note.tick
                )] {
                    max(1, note.durationTicks - reduction)
                } else {
                    note.durationTicks
                }

                let onTick = baseTick + timing.onsetOffsetTicks
                let effectiveDurationTicks = note.isGrace
                    ? rawDurationTicks
                    : max(0, timing.performedOffTick - timing.performedOnTick)
                let offTick = max(
                    onTick,
                    onTick + max(0, effectiveDurationTicks)
                )
                output.append(
                    MusicXMLNoteSpan(
                        midiNote: midiNote,
                        staff: staff,
                        voice: voice,
                        onTick: onTick,
                        offTick: offTick
                    )
                )
            }
        }

        return output.sorted { lhs, rhs in
            if lhs.onTick != rhs.onTick { return lhs.onTick < rhs.onTick }
            if lhs.midiNote != rhs.midiNote { return lhs.midiNote < rhs.midiNote }
            return lhs.offTick < rhs.offTick
        }
    }

    private struct GraceKey: Hashable {
        let partID: String
        let staff: Int
        let voice: Int
        let tick: Int
    }

    private struct GraceSchedule: Equatable {
        let onTick: Int
        let durationTicks: Int
    }

    private struct GracePlan {
        let scheduleByNoteIndex: [Int: GraceSchedule]
        let durationReductionTicksByKey: [GraceKey: Int]

        init(notes: [MusicXMLNoteEvent]) {
            var graceIndicesByKey: [GraceKey: [Int]] = [:]
            var followingDurationTicksByKey: [GraceKey: Int] = [:]

            for (noteIndex, note) in notes.enumerated() where note.isRest == false {
                let staff = note.staff ?? 1
                let voice = note.voice ?? 1
                let key = GraceKey(partID: note.partID, staff: staff, voice: voice, tick: note.tick)

                if note.isGrace {
                    graceIndicesByKey[key, default: []].append(noteIndex)
                } else if followingDurationTicksByKey[key] == nil {
                    followingDurationTicksByKey[key] = max(0, note.durationTicks)
                }
            }

            var schedule: [Int: GraceSchedule] = [:]
            var reductions: [GraceKey: Int] = [:]

            for (key, graceNoteIndices) in graceIndicesByKey {
                guard let followingDuration = followingDurationTicksByKey[key], followingDuration > 0 else { continue }

                let stealFraction: Double = graceNoteIndices.compactMap { notes[$0].graceStealTimeFollowing }.first
                    ?? graceNoteIndices.compactMap { notes[$0].graceStealTimePrevious }.first
                    ?? 0.25

                let totalStolenTicks = max(
                    1,
                    min(followingDuration - 1, Int((Double(followingDuration) * stealFraction).rounded()))
                )
                reductions[key] = totalStolenTicks

                let startTick = max(0, key.tick - totalStolenTicks)
                let slice = max(1, totalStolenTicks / max(1, graceNoteIndices.count))

                var cursor = startTick
                for (offset, graceNoteIndex) in graceNoteIndices.enumerated() {
                    var duration = slice
                    if offset == graceNoteIndices.count - 1 {
                        duration = max(1, key.tick - cursor)
                    }
                    if notes[graceNoteIndex].graceSlash {
                        duration = max(1, duration / 2)
                    }
                    schedule[graceNoteIndex] = GraceSchedule(onTick: cursor, durationTicks: duration)
                    cursor += duration
                }
            }

            scheduleByNoteIndex = schedule
            durationReductionTicksByKey = reductions
        }
    }

    private enum Category {
        case start
        case middle
        case end
        case normal
    }

    private struct ArpeggiateKey: Hashable {
        let partID: String
        let staff: Int
        let tick: Int
    }

    private struct ArpeggiateCandidate: Equatable {
        let noteIndex: Int
        let midi: Int
        let durationTicks: Int
    }

    private struct ArpeggiatePlan {
        let offsetTicksByNoteIndex: [Int: Int]

        init(notes: [MusicXMLNoteEvent]) {
            var directionTokenByKey: [ArpeggiateKey: String?] = [:]
            directionTokenByKey.reserveCapacity(32)

            for note in notes {
                guard note.isRest == false else { continue }
                guard note.isGrace == false else { continue }
                guard note.arpeggiate != nil else { continue }

                let staff = note.staff ?? 1
                let key = ArpeggiateKey(partID: note.partID, staff: staff, tick: note.tick)
                if directionTokenByKey[key] == nil {
                    directionTokenByKey[key] = note.arpeggiate?.directionToken
                }
            }

            guard directionTokenByKey.isEmpty == false else {
                offsetTicksByNoteIndex = [:]
                return
            }

            var candidatesByKey: [ArpeggiateKey: [ArpeggiateCandidate]] = [:]
            candidatesByKey.reserveCapacity(32)

            for (noteIndex, note) in notes.enumerated() {
                guard note.isRest == false else { continue }
                guard note.isGrace == false else { continue }
                guard let midi = note.midiNote else { continue }

                let staff = note.staff ?? 1
                let key = ArpeggiateKey(partID: note.partID, staff: staff, tick: note.tick)
                guard directionTokenByKey[key] != nil else { continue }

                candidatesByKey[key, default: []].append(
                    ArpeggiateCandidate(
                        noteIndex: noteIndex,
                        midi: midi,
                        durationTicks: max(0, note.durationTicks)
                    )
                )
            }

            var offsets: [Int: Int] = [:]
            offsets.reserveCapacity(candidatesByKey.values.reduce(0) { $0 + $1.count })

            for (key, candidates) in candidatesByKey {
                guard candidates.count >= 2 else {
                    offsets[candidates[0].noteIndex] = 0
                    continue
                }

                let durationTicks = candidates.map(\.durationTicks).max() ?? 0
                guard durationTicks > 0 else {
                    for candidate in candidates {
                        offsets[candidate.noteIndex] = 0
                    }
                    continue
                }

                let spreadUpperBound = min(durationTicks - 1, MusicXMLTempoMap.ticksPerQuarter / 16)
                let totalSpreadTicks = max(1, min(spreadUpperBound, durationTicks / 4))
                let step = max(1, totalSpreadTicks / max(1, candidates.count - 1))

                let directionToken = (directionTokenByKey[key] ?? nil)?.lowercased()
                let ordered = (directionToken == "down")
                    ? candidates.sorted { $0.midi > $1.midi }
                    : candidates.sorted { $0.midi < $1.midi }

                var cursor = 0
                for (i, candidate) in ordered.enumerated() {
                    offsets[candidate.noteIndex] = cursor
                    if i < ordered.count - 1 {
                        cursor = min(totalSpreadTicks, cursor + step)
                    }
                }
            }

            offsetTicksByNoteIndex = offsets
        }
    }
}
