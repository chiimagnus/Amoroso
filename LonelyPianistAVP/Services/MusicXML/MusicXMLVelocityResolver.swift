import Foundation

struct MusicXMLVelocityResolver {
    let dynamicEvents: [MusicXMLDynamicEvent]
    let defaultVelocity: UInt8

    init(dynamicEvents: [MusicXMLDynamicEvent], defaultVelocity: UInt8 = 96) {
        self.dynamicEvents = dynamicEvents
        self.defaultVelocity = defaultVelocity
    }

    func velocity(for note: MusicXMLNoteEvent) -> UInt8 {
        if let override = note.dynamicsOverrideVelocity {
            return override
        }

        let noteStaff = note.staff ?? 1

        if let velocity = resolvedVelocity(
            source: .soundDynamicsAttribute,
            partID: note.partID,
            tick: note.tick,
            staff: noteStaff
        ) {
            return velocity
        }

        if let velocity = resolvedVelocity(
            source: .directionDynamics,
            partID: note.partID,
            tick: note.tick,
            staff: noteStaff
        ) {
            return velocity
        }

        return defaultVelocity
    }

    private func resolvedVelocity(
        source: MusicXMLDynamicEventSource,
        partID: String,
        tick: Int,
        staff: Int
    ) -> UInt8? {
        if let staffSpecific = dynamicEvents
            .reversed()
            .first(where: { event in
                event.source == source &&
                    event.scope.partID == partID &&
                    event.tick <= tick &&
                    event.scope.staff == staff
            })
        {
            return staffSpecific.velocity
        }

        if let global = dynamicEvents
            .reversed()
            .first(where: { event in
                event.source == source &&
                    event.scope.partID == partID &&
                    event.tick <= tick &&
                    event.scope.staff == nil
            })
        {
            return global.velocity
        }

        return nil
    }
}

