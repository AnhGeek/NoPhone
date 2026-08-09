#if targetEnvironment(simulator)
import SwiftUI
import Observation

/// Development harness. **Compiled out of every device build.**
///
/// The Simulator has no Screen Time stack — `AuthorizationCenter` always fails
/// and no `DeviceActivity` threshold ever fires — so without this the app is
/// stuck on its permission gate and nothing downstream can be looked at.
///
/// The important constraint: this stands in for **Apple's callback only**, not
/// for the app's data path. It writes to `UsageBridge` exactly as the monitor
/// extension does, and the app folds it in with the same `foldMonitorUsage()`.
/// So what you see in the Simulator is the real pipeline with one end
/// substituted — not a parallel fake path that can drift from it.
///
/// What it cannot reproduce: `ManagedSettings` shields. Blocking is enforced by
/// iOS, so verifying an app actually gets blocked still needs a device.
@Observable
final class SimulatorUsageDriver {

    /// Wall-clock seconds between simulated thresholds. Short enough to watch a
    /// bar drain, long enough to see the damped spring settle between steps.
    static let secondsPerTick: TimeInterval = 2

    private(set) var isRunning = false
    private var timer: Timer?

    /// Populate the roster with the fixture apps, which carry no
    /// `ApplicationToken` — so `ScreenTimeService` skips them when registering
    /// events and can never confuse a demo app for a real one.
    @MainActor
    func seedApps(into state: AppState) {
        guard state.apps.isEmpty else { return }
        withAnimation(Motion.bounce) { state.apps = SampleData.apps }
        UsageBridge.writeRoster(state.apps)
    }

    @MainActor
    func start(driving state: AppState) {
        guard !isRunning, !state.apps.isEmpty else { return }
        isRunning = true

        timer = Timer.scheduledTimer(withTimeInterval: Self.secondsPerTick, repeats: true) { _ in
            Task { @MainActor in self.tick(state) }
        }
    }

    @MainActor
    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    /// One threshold's worth of usage on one app, chosen at random — the shape
    /// real usage arrives in, since only the app in the foreground burns time.
    /// Apps already at zero are skipped; a spent budget stops draining rather
    /// than running up an ever-growing overage.
    @MainActor
    private func tick(_ state: AppState) {
        let live = state.apps.filter { $0.remainingSeconds > 0 }
        guard let app = live.randomElement() else { stop(); return }

        let observed = UsageBridge.readUsage()[app.id] ?? app.usedSeconds
        UsageBridge.setUsage(seconds: observed + UsageBridge.tickMinutes * 60, for: app.id)

        withAnimation(Motion.smooth) { state.foldMonitorUsage() }
    }
}
#endif
