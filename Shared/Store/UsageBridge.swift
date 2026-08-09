import Foundation

/// The app ↔ monitor-extension bridge.
///
/// `DeviceActivityMonitor` runs in a separate, short-lived process that is woken
/// by the system and cannot see `AppState`. So the two sides share the App Group
/// container, and each owns a strictly separate key to avoid a last-writer-wins
/// race between two processes that are never coordinated:
///
/// - `roster` — written by the **app** only. What to watch: tokens, budgets.
/// - `usage` — written by the **monitor** only. Seconds burned, per app.
///
/// The app folds `usage` into its own model on foreground; it never writes that
/// key, and the monitor never writes the roster. That one rule is what keeps the
/// bridge correct without locking.
enum UsageBridge {
    private static let rosterKey = "monitorRoster"
    private static let usageKey  = "monitorUsage"
    private static let dayKey    = "monitorDayStart"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: SharedStore.appGroupID)
    }

    /// Usage is credited in fixed steps. DeviceActivity only calls back at
    /// thresholds we register in advance, so this is the real resolution of
    /// every number in the app — there is no continuous meter to read.
    static let tickMinutes: Double = 5

    /// iOS caps the events registrable per activity. At a 5-minute tick this
    /// still covers a 3-hour budget per app, and anything past the cap is
    /// beyond the budget anyway — the app is already shielded by then.
    static let maxEventsPerApp = 36

    // MARK: - Roster (app writes, monitor reads)

    static func writeRoster(_ apps: [TrackedApp]) {
        guard let data = try? JSONEncoder().encode(apps) else { return }
        defaults?.set(data, forKey: rosterKey)
    }

    static func readRoster() -> [TrackedApp] {
        guard
            let data = defaults?.data(forKey: rosterKey),
            let apps = try? JSONDecoder().decode([TrackedApp].self, from: data)
        else { return [] }
        return apps
    }

    // MARK: - Usage (monitor writes, app reads)

    /// Seconds burned today, keyed by `TrackedApp.id`.
    static func readUsage() -> [UUID: TimeInterval] {
        guard let raw = defaults?.dictionary(forKey: usageKey) as? [String: Double] else { return [:] }
        return raw.reduce(into: [:]) { result, pair in
            if let id = UUID(uuidString: pair.key) { result[id] = pair.value }
        }
    }

    /// Called from the monitor process when a threshold fires.
    ///
    /// Absolute, not additive: DeviceActivity thresholds are cumulative totals,
    /// so a missed wake-up is corrected by the next one instead of leaving the
    /// count permanently short.
    static func setUsage(seconds: TimeInterval, for appID: UUID) {
        var raw = defaults?.dictionary(forKey: usageKey) as? [String: Double] ?? [:]
        raw[appID.uuidString] = max(raw[appID.uuidString] ?? 0, seconds)
        defaults?.set(raw, forKey: usageKey)
    }

    static func resetUsage() {
        defaults?.set([String: Double](), forKey: usageKey)
        defaults?.set(Date.now, forKey: dayKey)
    }

    /// The day the current usage numbers belong to. The monitor stamps this at
    /// interval start so the app can tell a stale carry-over from a real zero.
    static var usageDayStart: Date? {
        defaults?.object(forKey: dayKey) as? Date
    }

    // MARK: - Event naming

    /// A `DeviceActivityEvent` carries no payload — only its name comes back in
    /// the callback. So the name *is* the payload: which app, and which tick.
    /// Kept here, as plain strings, so the registering side (app) and the
    /// interpreting side (monitor) can never drift apart, and neither forces
    /// `DeviceActivity` into `Shared/`.
    static func eventName(appID: UUID, tick: Int) -> String {
        "\(appID.uuidString)#\(tick)"
    }

    static func decodeEventName(_ name: String) -> (appID: UUID, tick: Int)? {
        let parts = name.split(separator: "#")
        guard parts.count == 2,
              let id = UUID(uuidString: String(parts[0])),
              let tick = Int(parts[1])
        else { return nil }
        return (id, tick)
    }
}
