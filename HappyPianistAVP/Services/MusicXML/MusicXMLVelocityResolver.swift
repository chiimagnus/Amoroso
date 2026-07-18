import Foundation

struct MusicXMLVelocityResolver {
    struct WedgeSpan: Equatable {
        let start: MusicXMLWedgeEvent
        let stop: MusicXMLWedgeEvent
    }

    let dynamicEvents: [MusicXMLDynamicEvent]
    let wedgeEvents: [MusicXMLWedgeEvent]
    let wedgeEnabled: Bool
    let defaultVelocity: UInt8
    let wedgeApproximations: [MusicXMLWedgeApproximation]
    private let wedgeSpans: [WedgeSpan]

    init(
        dynamicEvents: [MusicXMLDynamicEvent],
        wedgeEvents: [MusicXMLWedgeEvent] = [],
        wedgeEnabled: Bool = false,
        defaultVelocity: UInt8 = 96
    ) {
        self.dynamicEvents = dynamicEvents
        self.wedgeEvents = wedgeEvents
        self.wedgeEnabled = wedgeEnabled
        self.defaultVelocity = defaultVelocity
        let pairing = Self.buildWedgeSpans(from: wedgeEvents)
        wedgeSpans = pairing.spans
        wedgeApproximations = pairing.approximations
    }

    func velocity(for note: MusicXMLNoteEvent) -> UInt8 {
        if let override = note.dynamicsOverrideVelocity {
            return applyArticulations(note: note, velocity: override)
        }

        let baseVelocity: UInt8
        if wedgeEnabled,
           let wedgeVelocity = wedgeVelocity(
               partID: note.partID,
               tick: note.tick,
               staff: note.staff,
               voice: note.voice
           )
        {
            baseVelocity = wedgeVelocity
        } else {
            baseVelocity = resolvedDynamicEvent(
                partID: note.partID,
                tick: note.tick,
                staff: note.staff,
                voice: note.voice
            )?.velocity ?? defaultVelocity
        }

        return applyArticulations(note: note, velocity: baseVelocity)
    }

    private func applyArticulations(note: MusicXMLNoteEvent, velocity: UInt8) -> UInt8 {
        var value = Int(velocity)
        if note.articulations.contains(.accent) {
            value += 10
        }
        if note.articulations.contains(.marcato) {
            value += 15
        }
        return UInt8(min(127, max(0, value)))
    }

    private func resolvedDynamicEvent(
        partID: String,
        tick: Int,
        staff: Int?,
        voice: Int?
    ) -> MusicXMLDynamicEvent? {
        dynamicEvents
            .filter { event in
                event.scope.partID == partID
                    && event.tick <= tick
                    && scope(event.scope, matchesStaff: staff, voice: voice)
            }
            .max(by: { lhs, rhs in
                if lhs.tick != rhs.tick { return lhs.tick < rhs.tick }
                let lhsSpecificity = scopeSpecificity(lhs.scope, staff: staff, voice: voice)
                let rhsSpecificity = scopeSpecificity(rhs.scope, staff: staff, voice: voice)
                if lhsSpecificity != rhsSpecificity { return lhsSpecificity < rhsSpecificity }
                let lhsSource = sourcePrecedence(lhs.source)
                let rhsSource = sourcePrecedence(rhs.source)
                if lhsSource != rhsSource { return lhsSource < rhsSource }
                let lhsIdentity = lhs.sourceID?.description ?? ""
                let rhsIdentity = rhs.sourceID?.description ?? ""
                if lhsIdentity != rhsIdentity { return lhsIdentity < rhsIdentity }
                return lhs.velocity < rhs.velocity
            })
    }

    private func wedgeVelocity(
        partID: String,
        tick: Int,
        staff: Int?,
        voice: Int?
    ) -> UInt8? {
        let candidates = wedgeSpans.filter { span in
            span.start.scope.partID == partID
                && span.start.tick <= tick
                && tick <= span.stop.tick
                && scope(span.start.scope, matchesStaff: staff, voice: voice)
        }
        guard let span = candidates.max(by: { lhs, rhs in
            if lhs.start.tick != rhs.start.tick { return lhs.start.tick < rhs.start.tick }
            let lhsSpecificity = scopeSpecificity(lhs.start.scope, staff: staff, voice: voice)
            let rhsSpecificity = scopeSpecificity(rhs.start.scope, staff: staff, voice: voice)
            if lhsSpecificity != rhsSpecificity { return lhsSpecificity < rhsSpecificity }
            return lhs.start.normalizedNumberToken < rhs.start.normalizedNumberToken
        }),
        span.stop.tick > span.start.tick
        else {
            return nil
        }

        let startVelocity = resolvedDynamicEvent(
            partID: partID,
            tick: span.start.tick,
            staff: staff,
            voice: voice
        )?.velocity ?? defaultVelocity
        guard let endVelocity = firstDynamicEvent(
            atOrAfterTick: span.stop.tick,
            partID: partID,
            staff: staff,
            voice: voice
        )?.velocity else {
            return nil
        }

        let progress = Double(tick - span.start.tick) / Double(span.stop.tick - span.start.tick)
        let interpolated = Double(startVelocity) + (Double(endVelocity) - Double(startVelocity)) * progress
        return UInt8(min(127, max(0, Int(interpolated.rounded()))))
    }

    private func firstDynamicEvent(
        atOrAfterTick tick: Int,
        partID: String,
        staff: Int?,
        voice: Int?
    ) -> MusicXMLDynamicEvent? {
        dynamicEvents
            .filter { event in
                event.scope.partID == partID
                    && event.tick >= tick
                    && scope(event.scope, matchesStaff: staff, voice: voice)
            }
            .min(by: { lhs, rhs in
                if lhs.tick != rhs.tick { return lhs.tick < rhs.tick }
                let lhsSpecificity = scopeSpecificity(lhs.scope, staff: staff, voice: voice)
                let rhsSpecificity = scopeSpecificity(rhs.scope, staff: staff, voice: voice)
                if lhsSpecificity != rhsSpecificity { return lhsSpecificity > rhsSpecificity }
                let lhsSource = sourcePrecedence(lhs.source)
                let rhsSource = sourcePrecedence(rhs.source)
                if lhsSource != rhsSource { return lhsSource > rhsSource }
                return (lhs.sourceID?.description ?? "") < (rhs.sourceID?.description ?? "")
            })
    }

    private func scope(_ scope: MusicXMLEventScope, matchesStaff staff: Int?, voice: Int?) -> Bool {
        (scope.staff == nil || scope.staff == staff)
            && (scope.voice == nil || scope.voice == voice)
    }

    private func scopeSpecificity(_ scope: MusicXMLEventScope, staff: Int?, voice: Int?) -> Int {
        var value = 0
        if scope.staff != nil, scope.staff == staff { value += 1 }
        if scope.voice != nil, scope.voice == voice { value += 2 }
        return value
    }

    private func sourcePrecedence(_ source: MusicXMLDynamicEventSource) -> Int {
        switch source {
        case .directionDynamics:
            0
        case .soundDynamicsAttribute:
            1
        }
    }

    private static func buildWedgeSpans(
        from wedgeEvents: [MusicXMLWedgeEvent]
    ) -> (spans: [WedgeSpan], approximations: [MusicXMLWedgeApproximation]) {
        let orderedEvents = wedgeEvents.sorted { lhs, rhs in
            if lhs.tick != rhs.tick { return lhs.tick < rhs.tick }
            let lhsKind = kindOrder(lhs.kind)
            let rhsKind = kindOrder(rhs.kind)
            if lhsKind != rhsKind { return lhsKind < rhsKind }
            return (lhs.sourceID?.description ?? "") < (rhs.sourceID?.description ?? "")
        }
        var active: [MusicXMLWedgePairKey: MusicXMLWedgeEvent] = [:]
        var spans: [WedgeSpan] = []
        var approximations: [MusicXMLWedgeApproximation] = []

        for event in orderedEvents {
            switch event.kind {
            case .crescendoStart, .diminuendoStart:
                if let replaced = active.updateValue(event, forKey: event.pairKey) {
                    approximations.append(MusicXMLWedgeApproximation(
                        sourceID: replaced.sourceID,
                        reason: "wedge-start-replaced-before-stop"
                    ))
                }
            case .stop:
                guard let start = active.removeValue(forKey: event.pairKey) else {
                    approximations.append(MusicXMLWedgeApproximation(
                        sourceID: event.sourceID,
                        reason: "wedge-stop-without-start"
                    ))
                    continue
                }
                spans.append(WedgeSpan(start: start, stop: event))
            }
        }

        for event in active.values.sorted(by: { $0.tick < $1.tick }) {
            approximations.append(MusicXMLWedgeApproximation(
                sourceID: event.sourceID,
                reason: "wedge-start-without-stop"
            ))
        }
        return (spans: spans, approximations: approximations)
    }

    private static func kindOrder(_ kind: MusicXMLWedgeKind) -> Int {
        switch kind {
        case .crescendoStart, .diminuendoStart:
            0
        case .stop:
            1
        }
    }
}
