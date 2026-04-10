import Foundation

enum DefaultProfileFactory {
    static func makeProfiles(referenceDate: Date = .now) -> [MappingProfile] {
        [
            makeDefaultQwertyProfile(referenceDate: referenceDate),
            makeCodingProfile(referenceDate: referenceDate)
        ]
    }

    private static func makeDefaultQwertyProfile(referenceDate: Date) -> MappingProfile {
        let noteStart = 48
        let characters = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        let singleRules: [SingleKeyMappingRule] = characters.enumerated().map { index, character in
            let note = noteStart + index
            let keyCode = KeyStroke.keyCode(for: character) ?? 0
            return SingleKeyMappingRule(
                note: note,
                output: KeyStroke(keyCode: keyCode),
                velocityThreshold: 100
            )
        }

        let chordRules: [ChordMappingRule] = [
            ChordMappingRule(notes: [60, 64, 67], output: keyStroke("c", modifiers: [.command])),
            ChordMappingRule(notes: [62, 65, 69], output: keyStroke("v", modifiers: [.command])),
            ChordMappingRule(notes: [59, 62, 65], output: keyStroke("z", modifiers: [.command]))
        ]

        let melodyRules: [MelodyMappingRule] = [
            MelodyMappingRule(notes: [64, 64, 67], maxIntervalMilliseconds: 600, output: keyStroke("h")),
            MelodyMappingRule(notes: [60, 62, 64, 67], maxIntervalMilliseconds: 500, output: keyStroke("n", modifiers: [.command]))
        ]

        return MappingProfile(
            id: UUID(),
            name: "Default QWERTY",
            isBuiltIn: true,
            isActive: true,
            createdAt: referenceDate,
            updatedAt: referenceDate,
            payload: MappingProfilePayload(
                velocityEnabled: true,
                defaultVelocityThreshold: 100,
                singleKeyRules: singleRules,
                chordRules: chordRules,
                melodyRules: melodyRules
            )
        )
    }

    private static func makeCodingProfile(referenceDate: Date) -> MappingProfile {
        let baseNotes = Array(60...75)
        let symbols = ["{", "}", "(", ")", "[", "]", ";", ":", "<", ">", "=", "+", "-", "_", "/", "*"]

        let singleRules: [SingleKeyMappingRule] = zip(baseNotes, symbols).map { note, symbol in
            SingleKeyMappingRule(
                note: note,
                output: keyStroke(symbol.first ?? "a"),
                velocityThreshold: 95
            )
        }

        let chordRules: [ChordMappingRule] = [
            ChordMappingRule(notes: [60, 63, 67], output: keyStroke("4", modifiers: [.command, .shift])),
            ChordMappingRule(notes: [62, 65, 69], output: KeyStroke(keyCode: 49, modifiers: [.command])),
            ChordMappingRule(notes: [64, 67, 71], output: keyStroke("k", modifiers: [.command]))
        ]

        let melodyRules: [MelodyMappingRule] = [
            MelodyMappingRule(notes: [67, 69, 71], maxIntervalMilliseconds: 450, output: keyStroke("f")),
            MelodyMappingRule(notes: [71, 69, 67], maxIntervalMilliseconds: 450, output: keyStroke("r"))
        ]

        return MappingProfile(
            id: UUID(),
            name: "Code Mode",
            isBuiltIn: true,
            isActive: false,
            createdAt: referenceDate,
            updatedAt: referenceDate,
            payload: MappingProfilePayload(
                velocityEnabled: true,
                defaultVelocityThreshold: 95,
                singleKeyRules: singleRules,
                chordRules: chordRules,
                melodyRules: melodyRules
            )
        )
    }

    private static func keyStroke(_ character: Character, modifiers: KeyStrokeModifiers = []) -> KeyStroke {
        let keyCode = KeyStroke.keyCode(for: character) ?? 0
        return KeyStroke(keyCode: keyCode, modifiers: modifiers)
    }
}
