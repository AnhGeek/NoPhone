import Foundation

/// The app ↔ widget bridge.
///
/// One small JSON blob in the shared App Group container. Deliberately not a
/// database: the widget process should do a single decode and render, and any
/// read that can fail should fail into the placeholder rather than an empty
/// widget.
enum SharedStore {
    /// Must match the App Group capability on both the app and the widget
    /// extension targets.
    static let appGroupID = "group.com.nophone.app"
    private static let key = "lockScreenSnapshot"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func write(_ snapshot: LockScreenSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: key)
    }

    /// Falls back to the placeholder so the widget always renders something
    /// shaped like real data — an empty accessory looks broken on a Lock
    /// Screen, and there is no room for an error state.
    static func read() -> LockScreenSnapshot {
        guard
            let data = defaults?.data(forKey: key),
            let snapshot = try? JSONDecoder().decode(LockScreenSnapshot.self, from: data)
        else {
            return .placeholder
        }
        return snapshot
    }
}
