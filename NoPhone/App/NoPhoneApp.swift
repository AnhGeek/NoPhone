import SwiftUI
import WidgetKit

@main
struct NoPhoneApp: App {
    @State private var state = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(state)
                // Rounded, heavy type is the identity; the system's default
                // sans undoes it wherever we forget an explicit font.
                .fontDesign(.rounded)
                .tint(Theme.brand)
        }
        .onChange(of: scenePhase) { _, phase in
            // Push a fresh snapshot whenever the app leaves the foreground —
            // that is exactly when the Lock Screen is about to be looked at.
            if phase != .active { publishSnapshot() }
        }
    }

    private func publishSnapshot() {
        SharedStore.write(state.lockScreenSnapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
