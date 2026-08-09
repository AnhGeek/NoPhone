import SwiftUI

/// How the budget appears on the Lock Screen.
///
/// The Lock Screen is where this product actually does its job — it's the
/// surface you see forty times a day, before you unlock and lose the argument.
/// So it gets four genuinely different treatments rather than one with options:
/// people glance differently, and the style that works for one person is noise
/// for another.
enum LockScreenStyle: String, Codable, CaseIterable, Identifiable {
    /// Stacked candy bars, one per pinned app. Most information, still glanceable.
    case rainbowStack
    /// Concentric arcs — a single compact cluster that reads as one object.
    case dials
    /// Ten chunky pips per app. The most legible at arm's length.
    case blocks
    /// Just Bloop and one number. For people who want a nudge, not a report.
    case mascot

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rainbowStack: "Rainbow Stack"
        case .dials:        "Dials"
        case .blocks:       "Blocks"
        case .mascot:       "Bloop"
        }
    }

    var blurb: String {
        switch self {
        case .rainbowStack: "One bar per app. The full picture at a glance."
        case .dials:        "Compact rings that cluster into a single mark."
        case .blocks:       "Chunky pips — readable from across the room."
        case .mascot:       "Bloop and one number. Minimum guilt, maximum nudge."
        }
    }

    var symbol: String {
        switch self {
        case .rainbowStack: "chart.bar.fill"
        case .dials:        "circle.circle.fill"
        case .blocks:       "square.grid.3x1.fill.below.line.grid.1x2"
        case .mascot:       "face.smiling.inverse"
        }
    }

    /// How many apps the style can show before it stops being glanceable.
    var appCapacity: Int {
        switch self {
        case .rainbowStack: 4
        case .dials:        5
        case .blocks:       3
        case .mascot:       1
        }
    }
}

/// The minimal slice of state a Lock Screen widget needs.
///
/// Kept as its own `Codable` type so the widget extension never has to reach
/// into the full model — it reads one small JSON blob from the shared App
/// Group container and renders. Nothing here should ever grow expensive to
/// compute; widget timelines refresh on a budget.
struct LockScreenSnapshot: Codable, Hashable {
    struct Item: Codable, Hashable, Identifiable {
        var id: UUID
        var name: String
        var symbol: String
        var tint: AppTint
        var remainingSeconds: TimeInterval
        var fraction: Double
    }

    var items: [Item]
    var totalRemaining: TimeInterval
    var totalFraction: Double
    var style: LockScreenStyle
    var generatedAt: Date

    static let placeholder = LockScreenSnapshot(
        items: [
            .init(id: UUID(), name: "Chirp", symbol: "bird.fill", tint: .sky,
                  remainingSeconds: 120, fraction: 0.03),
            .init(id: UUID(), name: "Loopz", symbol: "play.rectangle.fill", tint: .cherry,
                  remainingSeconds: 0, fraction: 0),
            .init(id: UUID(), name: "Pixel Pals", symbol: "gamecontroller.fill", tint: .grape,
                  remainingSeconds: 3960, fraction: 0.6)
        ],
        totalRemaining: 4080,
        totalFraction: 0.42,
        style: .rainbowStack,
        generatedAt: .now
    )
}

extension LockScreenSnapshot {
    /// Build the payload from App Group data alone, with no running app.
    ///
    /// The cached snapshot is only as fresh as the last time NoPhone was open,
    /// so a widget that reads it renders frozen bars while the person is
    /// actually burning time — the thing the Lock Screen exists to show. The
    /// monitor extension, meanwhile, writes real usage every tick with the app
    /// killed. So the widget derives its numbers the same way the app does,
    /// from `roster` + `usage`, and keeps only the *style* from the cache:
    /// that is a preference the app owns, and nothing in the bridge carries it.
    ///
    /// Returns nil when there is no roster to project — the caller falls back
    /// to the cached snapshot rather than rendering an empty accessory.
    static func live(style: LockScreenStyle) -> LockScreenSnapshot? {
        let roster = UsageBridge.readRoster()
        guard !roster.isEmpty else { return nil }

        // If the monitor never got its midnight wake-up, both the roster's
        // usage and the bridge's belong to a day that has ended. Bars refill at
        // midnight, so the honest reading is zero rather than yesterday.
        let staleDay = UsageBridge.usageDayStart.map {
            !Calendar.current.isDate($0, inSameDayAs: .now)
        } ?? true
        let usage = staleDay ? [:] : UsageBridge.readUsage()

        var apps = roster
        for index in apps.indices {
            if staleDay {
                apps[index].usedSeconds = 0
                apps[index].bonusSeconds = 0
            } else {
                // The monitor's figure is cumulative and absolute; the roster's
                // is whatever the app last folded in. Highest wins, so neither
                // a missed fold nor a missed tick walks the number backwards.
                apps[index].usedSeconds = max(apps[index].usedSeconds,
                                              usage[apps[index].id] ?? 0)
            }
        }

        let pinned = apps
            .filter(\.pinnedToLockScreen)
            .sorted { $0.remainingFraction < $1.remainingFraction }
        let items = pinned.prefix(style.appCapacity).map {
            Item(id: $0.id, name: $0.name, symbol: $0.symbol, tint: $0.tint,
                 remainingSeconds: $0.remainingSeconds, fraction: $0.remainingFraction)
        }

        let totalRemaining = apps.reduce(0) { $0 + $1.remainingSeconds }
        let totalBudget = apps.reduce(0) { $0 + $1.totalSeconds }

        return LockScreenSnapshot(
            items: Array(items),
            totalRemaining: totalRemaining,
            totalFraction: totalBudget > 0 ? min(1, max(0, totalRemaining / totalBudget)) : 0,
            style: style,
            generatedAt: .now
        )
    }
}

extension AppState {
    /// Project current state into the widget payload.
    var lockScreenSnapshot: LockScreenSnapshot {
        let items = lockScreenApps.prefix(lockScreenStyle.appCapacity).map {
            LockScreenSnapshot.Item(
                id: $0.id, name: $0.name, symbol: $0.symbol, tint: $0.tint,
                remainingSeconds: $0.remainingSeconds, fraction: $0.remainingFraction
            )
        }
        return LockScreenSnapshot(
            items: Array(items),
            totalRemaining: totalRemaining,
            totalFraction: dayFraction,
            style: lockScreenStyle,
            generatedAt: .now
        )
    }
}
