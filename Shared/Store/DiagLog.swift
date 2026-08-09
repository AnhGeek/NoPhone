import Foundation
import os

/// A small, shareable diagnostic trail.
///
/// Two sinks, because neither alone covers how this app is tested:
/// - `os.Logger`, for when a Mac is attached and Console can be used.
/// - a capped ring buffer in the App Group, so a TestFlight tester on a device
///   with no cable can read and send the trail from inside the app.
///
/// The App Group is deliberate: the monitor extension runs in its own process,
/// and its wake-ups are exactly the events hardest to observe. Sharing the
/// buffer means one ordered trail across both processes.
///
/// **Never log token bytes or app names.** Screen Time data is the one thing
/// this product promises never leaves the device, and a diagnostic the user
/// pastes into a chat is precisely a way for it to leave. Counts and states
/// only — that is enough to debug flow problems, which is all this is for.
enum DiagLog {
    private static let key = "diagLog"
    private static let limit = 400

    private static let logger = Logger(subsystem: "site.lya3hc.nophone",
                                       category: "diagnostics")

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: SharedStore.appGroupID)
    }

    /// Bumped by hand when a build is handed to a device. Without it, a log
    /// tail cannot distinguish "the code didn't run" from "that build predates
    /// the fix" — a distinction that has already cost a debugging round here.
    static let buildStamp = "2026-08-09-H (tab bar clearance)"

    /// Which process wrote the line — the app and the monitor interleave here.
    enum Source: String { case app = "APP", monitor = "MON" }

    static func write(_ message: String, source: Source = .app) {
        logger.log("\(message, privacy: .public)")

        let stamp = Self.formatter.string(from: .now)
        let line = "\(stamp) [\(source.rawValue)] \(message)"

        var lines = defaults?.stringArray(forKey: key) ?? []
        lines.append(line)
        if lines.count > limit { lines.removeFirst(lines.count - limit) }
        defaults?.set(lines, forKey: key)
        // Force the flush. UserDefaults buffers in memory, and this log is read
        // by copying the plist off a connected device — an entry still sitting
        // in memory reads as "the event never happened", which is the one
        // conclusion a diagnostic must never invite.
        defaults?.synchronize()
    }

    /// Prove the App Group actually works, rather than trusting it.
    ///
    /// iOS logs `Couldn't read values in CFPrefsPlistSource … detaching from
    /// cfprefsd` in situations that are sometimes harmless and sometimes mean
    /// the container is genuinely unreachable. The difference matters enormously
    /// here: if it is real, the monitor extension writes usage the app can never
    /// read, budgets never drain, and the widget shows placeholder data — all
    /// without a single error. So write a value, read it back, and say which it
    /// was.
    static func checkAppGroup() {
        let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: SharedStore.appGroupID)

        guard let defaults else {
            write("appgroup: FAILED — no UserDefaults suite for \(SharedStore.appGroupID)")
            return
        }
        guard container != nil else {
            write("appgroup: FAILED — no container URL. Entitlement missing on this build?")
            return
        }

        let probeKey = "appGroupProbe"
        let probe = UUID().uuidString
        defaults.set(probe, forKey: probeKey)
        let readBack = defaults.string(forKey: probeKey)
        defaults.removeObject(forKey: probeKey)

        write(readBack == probe
              ? "appgroup: OK — read/write verified"
              : "appgroup: FAILED — wrote \(probe.prefix(8)) read \(readBack?.prefix(8).description ?? "nil")")
    }

    static var lines: [String] { defaults?.stringArray(forKey: key) ?? [] }

    static var text: String {
        lines.isEmpty ? "No entries yet." : lines.joined(separator: "\n")
    }

    static func clear() { defaults?.removeObject(forKey: key) }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
}
