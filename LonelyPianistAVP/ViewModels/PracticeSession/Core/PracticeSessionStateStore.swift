import Foundation
import Observation

enum PracticeSessionState: Equatable {
    case idle
    case ready
    case guiding(stepIndex: Int)
    case completed
}

@MainActor
@Observable
final class PracticeSessionStateStore {
    var state: PracticeSessionState = .idle
    var steps: [PracticeStep] = []

    var currentStepIndex: Int = 0 {
        didSet {
            if steps.isEmpty {
                state = .idle
            } else {
                state = .guiding(stepIndex: currentStepIndex)
            }
        }
    }
}
