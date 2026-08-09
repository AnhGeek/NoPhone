import SwiftUI
import WidgetKit

@main
struct NoPhoneApp: App {
    @State private var state = AppState()
    @State private var screenTime = ScreenTimeService()
    #if targetEnvironment(simulator)
    @State private var driver = SimulatorUsageDriver()
    #endif
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(state)
                .environment(screenTime)
                #if targetEnvironment(simulator)
                .environment(driver)
                #endif
                // Rounded, heavy type is the identity; the system's default
                // sans undoes it wherever we forget an explicit font.
                .fontDesign(.rounded)
                .tint(Theme.brand)
                .task {
                    DiagLog.write("launch: build \(DiagLog.buildStamp)")
                    DiagLog.checkAppGroup()
                    screenTime.refreshAuthorization()
                    #if targetEnvironment(simulator)
                    // No way to tap a permission prompt from a test harness,
                    // so ask directly and let the log record what happens.
                    await screenTime.requestAuthorization()
                    #endif
                    state.apps = UsageBridge.readRoster()
                    syncFromMonitor()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                // The monitor has been running while we were away; this is the
                // only moment the app can catch up on what it recorded.
                syncFromMonitor()
            } else {
                publishSnapshot()
            }
        }
    }

    /// Fold in real usage, then make the world consistent with it: shields
    /// follow the numbers, and the roster the monitor reads follows any budget
    /// or bonus change the person made while the app was open.
    private func syncFromMonitor() {
        if let day = UsageBridge.usageDayStart,
           !Calendar.current.isDate(day, inSameDayAs: .now) {
            state.rolloverDay()
        }
        state.foldMonitorUsage()

        guard state.hasTrackedApps else { return }
        screenTime.startMonitoring(apps: state.apps)
        screenTime.applyShields(for: state.apps)
        publishSnapshot()
    }

    private func publishSnapshot() {
        UsageBridge.writeRoster(state.apps)
        SharedStore.write(state.lockScreenSnapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
