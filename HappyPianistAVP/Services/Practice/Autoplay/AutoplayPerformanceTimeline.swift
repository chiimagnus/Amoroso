import Foundation

struct AutoplayPerformanceTimeline: Equatable {
    enum EventKind: Equatable {
        case pauseSeconds(TimeInterval)
        case noteOff(midi: Int)
        case controlChange(controller: UInt8, value: UInt8)
        case tempo(quarterBPM: Double, endTick: Int?, endQuarterBPM: Double?)
        case noteOn(midi: Int, velocity: UInt8)
        case advanceStep(index: Int)
        case advanceGuide(index: Int, guideID: Int)
    }

    struct Event: Equatable, Identifiable {
        let id: Int
        let sourceEventID: String?
        let tick: Int
        let kind: EventKind

        init(id: Int, sourceEventID: String? = nil, tick: Int, kind: EventKind) {
            self.id = id
            self.sourceEventID = sourceEventID
            self.tick = tick
            self.kind = kind
        }

        var sortPriority: Int {
            switch kind {
            case .pauseSeconds:
                0
            case .noteOff:
                1
            case .controlChange, .tempo:
                2
            case .noteOn:
                3
            case .advanceStep:
                4
            case .advanceGuide:
                5
            }
        }
    }

    private struct RawEvent {
        let tick: Int
        let priority: Int
        let sourceEventID: String?
        let kind: EventKind
    }

    static let empty = AutoplayPerformanceTimeline(events: [])

    let events: [Event]

    func firstEventIndex(atOrAfter tick: Int) -> Int {
        var low = 0
        var high = events.count
        while low < high {
            let mid = (low + high) / 2
            if events[mid].tick < tick {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
    }

    static func build(
        plan: ScorePerformancePlan,
        guideProjection: [PianoHighlightGuide],
        stepProjection: [PracticeStep],
        tempoMap: MusicXMLTempoMap,
        practiceHandMode: PracticeHandMode,
        activeRange: PracticeActiveRange? = nil
    ) -> AutoplayPerformanceTimeline {
        var rawEvents: [RawEvent] = []
        rawEvents.reserveCapacity(
            plan.noteEvents.count * 2 + plan.controllerEvents.count + plan.tempoEvents.count
                + guideProjection.count + stepProjection.count + plan.annotations.count
        )

        for (index, guide) in guideProjection.enumerated()
            where activeRange?.contains(tick: guide.tick) ?? true
        {
            rawEvents.append(RawEvent(
                tick: guide.tick,
                priority: 5,
                sourceEventID: nil,
                kind: .advanceGuide(index: index, guideID: guide.id)
            ))
        }

        for (index, step) in stepProjection.enumerated()
            where activeRange?.contains(stepIndex: index) ?? true
        {
            rawEvents.append(RawEvent(
                tick: step.tick,
                priority: 4,
                sourceEventID: nil,
                kind: .advanceStep(index: index)
            ))
        }

        for note in plan.noteEvents where practiceHandMode.allows(hand: note.handAssignment.hand) {
            guard activeRange?.contains(tick: note.performedOnTick) ?? true else { continue }
            let offTick = max(
                note.performedOnTick + 1,
                activeRange.map { min(note.performedOffTick, $0.tickRange.upperBound) } ?? note.performedOffTick
            )
            let sourceEventID = note.id.description
            rawEvents.append(RawEvent(
                tick: note.performedOnTick,
                priority: 3,
                sourceEventID: sourceEventID,
                kind: .noteOn(midi: note.midiNote, velocity: note.velocity)
            ))
            rawEvents.append(RawEvent(
                tick: offTick,
                priority: 1,
                sourceEventID: sourceEventID,
                kind: .noteOff(midi: note.midiNote)
            ))
        }

        for (index, tempo) in selectedTempoEvents(plan.tempoEvents, activeRange: activeRange).enumerated() {
            rawEvents.append(RawEvent(
                tick: tempo.tick,
                priority: 2,
                sourceEventID: tempo.sourceDirectionID?.description
                    ?? "tempo:\(tempo.performedOccurrenceIndex):\(tempo.tick):\(index)",
                kind: .tempo(
                    quarterBPM: tempo.quarterBPM,
                    endTick: tempo.endTick,
                    endQuarterBPM: tempo.endQuarterBPM
                )
            ))
        }

        for (index, controller) in selectedControllerEvents(
            plan.controllerEvents,
            activeRange: activeRange
        ).enumerated() {
            rawEvents.append(RawEvent(
                tick: controller.tick,
                priority: 2,
                sourceEventID: controller.sourceDirectionID?.description
                    ?? "controller:\(controller.performedOccurrenceIndex):\(controller.tick):\(index)",
                kind: .controlChange(
                    controller: controller.controllerNumber,
                    value: controller.value
                )
            ))
        }

        for (index, annotation) in plan.annotations.enumerated() {
            guard annotation.kind == .pause,
                  let durationTicks = annotation.durationTicks,
                  durationTicks > 0,
                  containsAnnotationTick(annotation.tick, activeRange: activeRange)
            else {
                continue
            }
            let seconds = tempoMap.timeSeconds(atTick: annotation.tick + durationTicks)
                - tempoMap.timeSeconds(atTick: annotation.tick)
            guard seconds > 0 else { continue }
            rawEvents.append(RawEvent(
                tick: annotation.tick,
                priority: 0,
                sourceEventID: annotation.sourceDirectionID?.description
                    ?? annotation.provenance.compactMap(\.sourceIdentity).first
                    ?? "annotation:\(annotation.performedOccurrenceIndex):\(annotation.tick):\(index)",
                kind: .pauseSeconds(seconds)
            ))
        }

        let sortedEvents = rawEvents
            .sorted { lhs, rhs in
                if lhs.tick != rhs.tick { return lhs.tick < rhs.tick }
                if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
                let lhsTie = eventTieBreaker(lhs.kind, sourceEventID: lhs.sourceEventID)
                let rhsTie = eventTieBreaker(rhs.kind, sourceEventID: rhs.sourceEventID)
                return lhsTie < rhsTie
            }
            .enumerated()
            .map { offset, event in
                Event(
                    id: offset,
                    sourceEventID: event.sourceEventID,
                    tick: event.tick,
                    kind: event.kind
                )
            }

        return AutoplayPerformanceTimeline(events: sortedEvents)
    }

    private static func selectedTempoEvents(
        _ events: [ScorePerformanceTempoEvent],
        activeRange: PracticeActiveRange?
    ) -> [ScorePerformanceTempoEvent] {
        guard let activeRange else { return events }
        let lowerBound = activeRange.tickRange.lowerBound
        let hasEventAtLowerBound = events.contains { $0.tick == lowerBound }
        let initial = events.last { $0.tick < lowerBound }.map { event in
            let continuesRamp = event.endTick.map { lowerBound < $0 } ?? false
            let quarterBPM: Double
            if let endTick = event.endTick,
               let endQuarterBPM = event.endQuarterBPM,
               endTick > event.tick {
                let progress = min(1, Double(lowerBound - event.tick) / Double(endTick - event.tick))
                quarterBPM = event.quarterBPM
                    + (endQuarterBPM - event.quarterBPM) * progress
            } else {
                quarterBPM = event.quarterBPM
            }
            return ScorePerformanceTempoEvent(
                sourceDirectionID: event.sourceDirectionID,
                performedOccurrenceIndex: event.performedOccurrenceIndex,
                tick: lowerBound,
                quarterBPM: quarterBPM,
                endTick: continuesRamp ? event.endTick : nil,
                endQuarterBPM: continuesRamp ? event.endQuarterBPM : nil
            )
        }
        return (hasEventAtLowerBound ? [] : [initial].compactMap(\.self))
            + events.filter { activeRange.contains(tick: $0.tick) }
    }

    private static func selectedControllerEvents(
        _ events: [ScorePerformanceControllerEvent],
        activeRange: PracticeActiveRange?
    ) -> [ScorePerformanceControllerEvent] {
        guard let activeRange else { return events }
        let lowerBound = activeRange.tickRange.lowerBound
        let controllersAtLowerBound = Set(
            events.lazy.filter { $0.tick == lowerBound }.map(\.controllerNumber)
        )
        let initialByController = Dictionary(grouping: events.filter { $0.tick < lowerBound }, by: \.controllerNumber)
            .compactMapValues(\.last)
            .values
            .filter { controllersAtLowerBound.contains($0.controllerNumber) == false }
            .map { event in
                ScorePerformanceControllerEvent(
                    sourceDirectionID: event.sourceDirectionID,
                    performedOccurrenceIndex: event.performedOccurrenceIndex,
                    tick: lowerBound,
                    controllerNumber: event.controllerNumber,
                    value: event.value,
                    outputCapabilityRequirement: event.outputCapabilityRequirement
                )
            }
        return initialByController + events.filter { activeRange.contains(tick: $0.tick) }
    }

    private static func containsAnnotationTick(_ tick: Int, activeRange: PracticeActiveRange?) -> Bool {
        guard let activeRange else { return true }
        return tick >= activeRange.tickRange.lowerBound && tick <= activeRange.tickRange.upperBound
    }

    private static func eventTieBreaker(_ kind: EventKind, sourceEventID: String?) -> String {
        let identity = sourceEventID ?? ""
        return switch kind {
        case let .noteOff(midi):
            "noteOff-\(midi)-\(identity)"
        case let .controlChange(controller, value):
            "control-\(controller)-\(value)-\(identity)"
        case let .tempo(quarterBPM, endTick, endQuarterBPM):
            "tempo-\(quarterBPM)-\(endTick ?? -1)-\(endQuarterBPM ?? -1)-\(identity)"
        case let .noteOn(midi, velocity):
            "noteOn-\(midi)-\(velocity)-\(identity)"
        case let .advanceStep(index):
            "advanceStep-\(index)"
        case let .advanceGuide(index, guideID):
            "advanceGuide-\(index)-\(guideID)"
        case let .pauseSeconds(seconds):
            "pause-\(seconds)-\(identity)"
        }
    }
}
