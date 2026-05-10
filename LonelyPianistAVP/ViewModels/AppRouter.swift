import Foundation

@MainActor
@Observable
final class AppRouter {
    enum Route: Hashable {
        case typePicker
        case realPreparation
        case virtualPreparation
        case library
        case practice
    }

    let flowState: FlowState
    var route: Route = .typePicker

    init(flowState: FlowState) {
        self.flowState = flowState
    }
}
