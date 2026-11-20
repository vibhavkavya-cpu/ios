import SwiftUI

@main
@MainActor
struct DigicamApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            CameraView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                appState.cameraManager.resumeSession()
            case .background, .inactive:
                appState.cameraManager.pauseSession()
            @unknown default:
                break
            }
        }
    }
}
