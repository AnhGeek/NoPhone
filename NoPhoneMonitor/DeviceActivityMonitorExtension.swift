import DeviceActivity
import ManagedSettings
import Foundation
import WidgetKit

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
        // Category shields must lift too. Clearing only `applications` left a
        // category budget blocked through the new day with a full bar.
        store.shield.applicationCategories = nil
        // Every bar on the Lock Screen just went back to full.
        WidgetCenter.shared.reloadAllTimelines()
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
        let roster = UsageBridge.readRoster()
        guard let app = roster.first(where: { $0.id == appID }) else {
            // Silent before: this returns without shielding, so the app would
            // stay usable until the host app next folded usage on foreground —
            // which looks exactly like "the block only happens when I reopen
            // the app". It has to be visible in the trail.
            DiagLog.write("threshold: app not in roster (roster=\(roster.count)) — NOT shielded",
                          source: .monitor)
            return
        }

        if usedSeconds >= app.totalSeconds {
            shield(app)
            DiagLog.write("threshold: budget spent — shield applied", source: .monitor)
        } else {
            let left = Int((app.totalSeconds - usedSeconds) / 60)
            DiagLog.write("threshold: \(left)m left — no shield", source: .monitor)
        }

        reloadWidgetsIfVisible(app)
    }

    /// Push the Lock Screen a new reading — but only for a bar someone can see.
    ///
    /// WidgetKit rations reloads (tens per day, not hundreds). A tick on an
    /// unpinned app changes nothing on the Lock Screen, so spending a reload on
    /// it would buy nothing and could starve the pinned apps later in the day.
    private func reloadWidgetsIfVisible(_ app: TrackedApp) {
        guard app.pinnedToLockScreen else { return }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func shield(_ app: TrackedApp) {
        switch app.target {
        case .application(let data):
            guard let token = try? JSONDecoder().decode(ApplicationToken.self, from: data) else {
                DiagLog.write("threshold: token undecodable — cannot shield", source: .monitor)
                return
            }
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
