import SwiftUI

struct PreparationNavigationActions {
    var backToTypePicker: @MainActor () -> Void
    var finishSetup: @MainActor () -> Void

    static let noop = PreparationNavigationActions(
        backToTypePicker: {},
        finishSetup: {}
    )
}

extension EnvironmentValues {
    @Entry var preparationNavigationActions: PreparationNavigationActions = .noop
}
