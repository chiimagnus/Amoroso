import Foundation

final class DefaultMappingEngine: MappingEngineProtocol {
    private var pressedNotes: Set<Int> = []
    private var triggeredChordRuleIDs: Set<UUID> = []

    func reset() {
        pressedNotes.removeAll(keepingCapacity: false)
        triggeredChordRuleIDs.removeAll(keepingCapacity: false)
    }

    func process(event: MIDIEvent, profile: MappingProfile) -> [ResolvedKeyStroke] {
        switch event.type {
        case .noteOn(let note, let velocity):
            return processNoteOn(note: note, velocity: velocity, profile: profile)
        case .noteOff(let note, _):
            processNoteOff(note: note, profile: profile)
            return []
        case .controlChange:
            return []
        }
    }

    private func processNoteOn(
        note: Int,
        velocity: Int,
        profile: MappingProfile
    ) -> [ResolvedKeyStroke] {
        pressedNotes.insert(note)

        var resolved: [ResolvedKeyStroke] = []

        if let output = resolveSingleKeyOutput(note: note, velocity: velocity, profile: profile) {
            resolved.append(
                ResolvedKeyStroke(
                    triggerType: .singleKey,
                    keyStroke: output,
                    sourceDescription: MIDINote(note).name
                )
            )
        }

        resolved.append(contentsOf: resolveChordActions(profile: profile))
        return resolved
    }

    private func resolveSingleKeyOutput(note: Int, velocity: Int, profile: MappingProfile) -> KeyStroke? {
        guard let rule = profile.payload.singleKeyRules.first(where: { $0.note == note }) else {
            return nil
        }

        let baseOutput = KeyStroke(keyCode: rule.output.keyCode)

        guard profile.payload.velocityEnabled else {
            return baseOutput
        }

        let threshold = rule.velocityThreshold ?? profile.payload.defaultVelocityThreshold
        if velocity >= threshold {
            return baseOutput.adding(.shift)
        }

        return baseOutput
    }

    private func processNoteOff(note: Int, profile: MappingProfile) {
        pressedNotes.remove(note)

        let rulesByID = Dictionary(uniqueKeysWithValues: profile.payload.chordRules.map { ($0.id, $0) })
        triggeredChordRuleIDs = triggeredChordRuleIDs.filter { ruleID in
            guard let rule = rulesByID[ruleID] else { return false }
            let requiredNotes = Set(rule.notes)
            return requiredNotes.isSubset(of: pressedNotes)
        }
    }

    private func resolveChordActions(profile: MappingProfile) -> [ResolvedKeyStroke] {
        guard !pressedNotes.isEmpty else { return [] }

        var actions: [ResolvedKeyStroke] = []

        for rule in profile.payload.chordRules {
            let requiredNotes = Set(rule.notes)
            guard !requiredNotes.isEmpty else { continue }
            guard requiredNotes == pressedNotes else { continue }
            guard !triggeredChordRuleIDs.contains(rule.id) else { continue }

            triggeredChordRuleIDs.insert(rule.id)
            let label = rule.notes.map { MIDINote($0).name }.joined(separator: "+")
            actions.append(
                ResolvedKeyStroke(
                    triggerType: .chord,
                    keyStroke: rule.output,
                    sourceDescription: label
                )
            )
        }

        return actions
    }
}
