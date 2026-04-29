import SwiftUI

@main
struct LonelyPianistAVPApp: App {
    @State private var appState: AppState
    @State private var services: AppServices
    @State private var homeViewModel: HomeViewModel
    @State private var arGuideViewModel: ARGuideViewModel
    @State private var songLibraryViewModel: SongLibraryViewModel

    init() {
        let appState = AppState()
        appState.loadStoredCalibrationIfPossible()
        let services = AppServices()

        _appState = State(initialValue: appState)
        _services = State(initialValue: services)
        _homeViewModel = State(initialValue: HomeViewModel(appState: appState))
        _arGuideViewModel = State(initialValue: ARGuideViewModel(appState: appState))
        _songLibraryViewModel = State(initialValue: SongLibraryViewModel(appState: appState))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                homeViewModel: homeViewModel,
                arGuideViewModel: arGuideViewModel,
                songLibraryViewModel: songLibraryViewModel
            )
            .environment(appState)
            .environment(services)
        }
        .windowStyle(.automatic)
        .windowResizability(.contentSize)

        ImmersiveSpace(id: appState.immersiveSpaceID) {
            ImmersiveView(viewModel: arGuideViewModel)
                .environment(appState)
                .environment(services)
                .onAppear {
                    appState.immersiveSpaceState = .open
                }
                .onDisappear {
                    appState.immersiveSpaceState = .closed
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
