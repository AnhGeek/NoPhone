import DeviceActivity
import ManagedSettings
import Foundation

/// The only code that learns about real usage as it happens.
///
/// iOS wakes this process for a few seconds at each registered threshold, then
/// kills it. So it does the minimum: credit one tick to the App Group, and
/// shield the app if that tick spent the budget. Everything else — sessions,
/// streaks, celebrations — is the app's job when it next runs.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let store = ManagedSettingsStore()

    /// A new day started: bars refill, so every shield must lift. If this is
    /// missed the user wakes up locked out of an app with a full budget.
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        DiagLog.write("intervalDidStart — day reset, shields cleared", source: .monitor)
        UsageBridge.resetUsage()
        store.shield.applications = nil
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)

        guard let (appID, tick) = UsageBridge.decodeEventName(event.rawValue) else {
            DiagLog.write("threshold: undecodable event name", source: .monitor)
            return
        }
        DiagLog.write("threshold: tick \(tick)", source: .monitor)

        // Thresholds are cumulative — the tick-3 event means "15 minutes total",
        // not "5 more". So set the absolute figure rather than incrementing,
        // which also makes a missed or duplicated wake-up self-correcting.
        let usedSeconds = Double(tick) * UsageBridge.tickMinutes * 60
        UsageBridge.setUsage(seconds: usedSeconds, for: appID)

        // Re-read the roster every time: the app may have edited a budget or
        // granted quest minutes since the last threshold fired.
        guard let app = UsageBridge.readRoster().first(where: { $0.id == appID }) else { return }

        if usedSeconds >= app.totalSeconds {
            shield(app)
        }
    }

    private func shield(_ app: TrackedApp) {
        switch app.target {
        case .application(let data):
            guard let token = try? JSONDecoder().decode(ApplicationToken.self, from: data) else { return }
            var blocked = store.shield.applications ?? []
            blocked.insert(token)
            store.shield.applications = blocked

        case .category(let data):
            guard let token = try? JSONDecoder().decode(ActivityCategoryToken.self, from: data) else { return }
            // `.specific` replaces wholesale, so re-state the existing set
            // rather than dropping categories shielded earlier today.
            var blocked: Set<ActivityCategoryToken> = []
            if case .specific(let existing, except: _)? = store.shield.applicationCategories {
                blocked = existing
            }
            blocked.insert(token)
            store.shield.applicationCategories = .specific(blocked)

        case nil:
            DiagLog.write("threshold: app has no target — cannot shield", source: .monitor)
        }
    }
}
