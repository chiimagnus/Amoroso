import Foundation

enum PianoKind: Hashable {
    case real
    case virtual
}

@MainActor
@Observable
final class FlowState {
    var pianoKind: PianoKind?
}
