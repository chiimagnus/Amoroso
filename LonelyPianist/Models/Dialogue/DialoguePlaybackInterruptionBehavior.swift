import Foundation

enum DialoguePlaybackInterruptionBehavior: String, CaseIterable, Identifiable {
    case ignore
    case interrupt
    case queue

    static let userDefaultsKey = "dialoguePlaybackInterruptionBehavior"

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
            case .ignore:
                "A · Ignore"
            case .interrupt:
                "B · Interrupt"
            case .queue:
                "C · Queue"
        }
    }
}
