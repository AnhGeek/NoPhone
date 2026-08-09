import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings
import Observation

/// Everything that talks to Apple's Screen Time frameworks.
///
/// Lives in the app target, not `Shared/`: the widget must never link these —
/// it would need the `family-controls` entitlement to do so, for data it never
/// reads.
///
/// Three frameworks, three jobs:
/// - `FamilyControls` — permission, and the picker that yields tokens.
/// - `DeviceActivity` — wakes our monitor extension at usage thresholds.
/// - `ManagedSettings` — actually blocks an app once its budget is gone.
@Observable
final class ScreenTimeService {

    enum Authorization: Equatable {
        case unknown, approved, denied
        /// The Simulator has no Screen Time stack at all, so authorization
        /// always fails there. Surfaced as its own case to keep that from
        /// looking like a user denial during development.
        case unavailable(String)
    }

    private(set) var authorization: Authorization = .unknown

    /// The activity name we schedule under. One daily activity covers every
    /// tracked app; per-app resolution comes from the event names inside it.
    private static let activity = DeviceActivityName("dailyBudgets")

    private let center = DeviceActivityCenter()
    private let store = ManagedSettingsStore()

    // MARK: - Authorization

    /// Must be granted before a picker will show anything or monitoring will
    /// start. `.individual` is the self-managed case; `.child` requires a
    /// parent's Apple ID and a Family Sharing relationship.
    @MainActor
    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorization = .approved
            DiagLog.write("auth: approved")
        } catch {
            DiagLog.write("auth: request failed - \(error.localizedDescription)")
            #if targetEnvironment(simulator)
            authorization = .unavailable("Screen Time isn't available in the Simulator. Run on a device.")
            #else
            authorization = .denied
            #endif
        }
    }

    /// Read the real status everywhere, including the Simulator.
    ///
    /// This used to short-circuit on the Simulator to `.unavailable`, which
    /// assumed the answer instead of asking. Reading it for real means the
    /// Simulator reports whatever Screen Time actually does there — and the
    /// failure path in `requestAuthorization` still describes it honestly.
    @MainActor
    func refreshAuthorization() {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .approved:     authorization = .approved
        case .denied:       authorization = .denied
        case .notDetermined: authorization = .unknown
        @unknown default:   authorization = .unknown
        }
        DiagLog.write("auth: status=\(String(describing: authorization))")
    }

    // MARK: - Monitoring

    /// (Re)register the thresholds for today.
    ///
    /// Called whenever the roster changes — apps added or removed, a budget
    /// edited, or bonus minutes granted — because a threshold set is a
    /// *prediction* of where the callbacks should land, and a refill moves
    /// them. Cheap to redo, and wrong if skipped.
    func startMonitoring(apps: [TrackedApp]) {
        center.stopMonitoring([Self.activity])
        UsageBridge.writeRoster(apps)

        let events = buildEvents(for: apps)
        let withTokens = apps.filter(\.isTracked).count
        DiagLog.write("monitor: startMonitoring apps=\(apps.count) withToken=\(withTokens) events=\(events.count)")
        guard !events.isEmpty else {
            DiagLog.write("monitor: no events registered — nothing will drain")
            return
        }

        // Midnight to a minute before midnight, repeating: the natural day is
        // the product's whole unit of account.
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        do {
            try center.startMonitoring(Self.activity, during: schedule, events: events)
            DiagLog.write("monitor: registered OK")
        } catch {
            DiagLog.write("monitor: startMonitoring FAILED - \(error.localizedDescription)")
            // A failure here means budgets silently stop draining, so it must
            // be visible rather than swallowed.
            print("[ScreenTime] startMonitoring failed: \(error)")
        }
    }

    func stopMonitoring() {
        center.stopMonitoring([Self.activity])
        clearAllShields()
    }

    /// One event per tick per app. The tick is what makes the bar move at all:
    /// without intermediate thresholds we would only ever hear from the system
    /// once, at the moment the budget was already gone.
    private func buildEvents(
        for apps: [TrackedApp]
    ) -> [DeviceActivityEvent.Name: DeviceActivityEvent] {
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]

        for app in apps {
            // A category event measures every app inside it against one
            // threshold — which is exactly the "one bar for the whole group"
            // the product promises.
            let appTokens: Set<ApplicationToken> = app.applicationToken.map { [$0] } ?? []
            let categoryTokens: Set<ActivityCategoryToken> = app.categoryToken.map { [$0] } ?? []
            guard !appTokens.isEmpty || !categoryTokens.isEmpty else { continue }

            let totalMinutes = app.totalSeconds / 60
            let tickCount = min(
                UsageBridge.maxEventsPerApp,
                max(1, Int(ceil(totalMinutes / UsageBridge.tickMinutes)))
            )

            for tick in 1...tickCount {
                let minutes = Int(Double(tick) * UsageBridge.tickMinutes)
                let name = DeviceActivityEvent.Name(
                    UsageBridge.eventName(appID: app.id, tick: tick)
                )
                events[name] = DeviceActivityEvent(
                    applications: appTokens,
                    categories: categoryTokens,
                    threshold: DateComponents(minute: minutes)
                )
            }
        }
        return events
    }

    // MARK: - Shielding

    /// Block every app whose budget is spent, and only those. Set as a whole
    /// rather than added to incrementally, so a quest refill lifts a shield by
    /// the same code path that applied it — there is no "unshield" to forget.
    func applyShields(for apps: [TrackedApp]) {
        let spent = apps.filter { $0.remainingSeconds <= 0 }
        let blockedApps = spent.compactMap(\.applicationToken)
        let blockedCategories = spent.compactMap(\.categoryToken)

        DiagLog.write("shield: blocking apps=\(blockedApps.count) categories=\(blockedCategories.count) of \(apps.count)")
        store.shield.applications = blockedApps.isEmpty ? nil : Set(blockedApps)
        store.shield.applicationCategories = blockedCategories.isEmpty
            ? nil
            : .specific(Set(blockedCategories))
    }

    func clearAllShields() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
    }
}

// MARK: - Token bridging

extension TrackedApp {
    /// Decode the stored bytes back into a live token. Each accessor returns
    /// nil for the other kind of target, so callers can't accidentally shield
    /// a category as if it were an app.
    var applicationToken: ApplicationToken? {
        guard case .application(let data)? = target else { return nil }
        return try? JSONDecoder().decode(ApplicationToken.self, from: data)
    }

    var categoryToken: ActivityCategoryToken? {
        guard case .category(let data)? = target else { return nil }
        return try? JSONDecoder().decode(ActivityCategoryToken.self, from: data)
    }

    /// True when this budget is attached to something Screen Time can measure.
    var isTracked: Bool { applicationToken != nil || categoryToken != nil }

    static func encode(_ token: ApplicationToken) -> Data? {
        try? JSONEncoder().encode(token)
    }

    static func encode(_ token: ActivityCategoryToken) -> Data? {
        try? JSONEncoder().encode(token)
    }
}
