import SwiftUI

/// One app whose screen time we budget.
///
/// The mental model the whole product hangs on: every app starts the day with a
/// **full** bar. Opening the app drains it. Finishing quests refills it. So
/// `budgetSeconds` is the *base* allowance, `bonusSeconds` is what you earned
/// back today, and `usedSeconds` is what you have spent.
struct TrackedApp: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    /// SF Symbol standing in for the real app icon. Icons for third-party apps
    /// can only be rendered via `FamilyControls`' opaque `Label`, so the
    /// design uses our own glyph set and stays consistent either way.
    var symbol: String
    var tint: AppTint
    var category: AppCategory

    /// Base daily allowance, in seconds. Set by the person (or their admin).
    var budgetSeconds: TimeInterval
    /// Extra seconds earned from quests today. Resets with the day.
    var bonusSeconds: TimeInterval
    /// Seconds burned today.
    var usedSeconds: TimeInterval

    /// Individual pickups, newest last. Powers the timeline on the detail view.
    var sessions: [UsageSession]

    /// Whether this app appears on the lock screen widget.
    var pinnedToLockScreen: Bool

    init(id: UUID = UUID(),
         name: String,
         symbol: String,
         tint: AppTint,
         category: AppCategory,
         budgetMinutes: Double,
         bonusMinutes: Double = 0,
         usedMinutes: Double = 0,
         sessions: [UsageSession] = [],
         pinnedToLockScreen: Bool = true) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.tint = tint
        self.category = category
        self.budgetSeconds = budgetMinutes * 60
        self.bonusSeconds = bonusMinutes * 60
        self.usedSeconds = usedMinutes * 60
        self.sessions = sessions
        self.pinnedToLockScreen = pinnedToLockScreen
    }

    // MARK: - Derived

    /// Everything available today: base allowance plus what you earned back.
    var totalSeconds: TimeInterval { budgetSeconds + bonusSeconds }

    /// Never negative — an overrun reads as "empty", not as a debt.
    var remainingSeconds: TimeInterval { max(0, totalSeconds - usedSeconds) }

    /// How far past the allowance we went, for the "over by" callout.
    var overageSeconds: TimeInterval { max(0, usedSeconds - totalSeconds) }

    /// 1.0 at the start of the day, 0.0 when spent. The bar *drains*.
    var remainingFraction: Double {
        guard totalSeconds > 0 else { return 0 }
        return min(1, max(0, remainingSeconds / totalSeconds))
    }

    /// Portion of the bar that exists only because of earned bonus time.
    /// Rendered as a distinct segment so a refill is visibly a reward.
    var bonusFraction: Double {
        guard totalSeconds > 0 else { return 0 }
        return min(1, bonusSeconds / totalSeconds)
    }

    var openCount: Int { sessions.count }

    var status: BudgetStatus {
        if remainingSeconds <= 0 { return .spent }
        if remainingFraction <= 0.15 { return .critical }
        if remainingFraction <= 0.4 { return .low }
        return .healthy
    }

    /// The longest single sitting today — the number that usually surprises
    /// people more than the daily total does.
    var longestSession: TimeInterval { sessions.map(\.duration).max() ?? 0 }
}

/// Four states, each with its own voice. The copy matters as much as the color:
/// this app nudges, it does not scold.
enum BudgetStatus {
    case healthy, low, critical, spent

    var color: Color {
        switch self {
        case .healthy:  Theme.good
        case .low:      Theme.caution
        case .critical: Theme.warning
        case .spent:    Theme.danger
        }
    }

    var label: String {
        switch self {
        case .healthy:  "Plenty left"
        case .low:      "Running low"
        case .critical: "Almost gone"
        case .spent:    "All used up"
        }
    }

    var symbol: String {
        switch self {
        case .healthy:  "sparkles"
        case .low:      "hourglass"
        case .critical: "exclamationmark.2"
        case .spent:    "moon.zzz.fill"
        }
    }
}

enum AppCategory: String, Codable, CaseIterable, Identifiable {
    case social, video, games, messaging, shopping, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .social:    "Social"
        case .video:     "Video"
        case .games:     "Games"
        case .messaging: "Messaging"
        case .shopping:  "Shopping"
        case .other:     "Other"
        }
    }

    var symbol: String {
        switch self {
        case .social:    "person.2.fill"
        case .video:     "play.rectangle.fill"
        case .games:     "gamecontroller.fill"
        case .messaging: "bubble.left.and.bubble.right.fill"
        case .shopping:  "bag.fill"
        case .other:     "square.grid.2x2.fill"
        }
    }
}

/// A single pickup.
struct UsageSession: Identifiable, Codable, Hashable {
    let id: UUID
    var start: Date
    var duration: TimeInterval

    init(id: UUID = UUID(), start: Date, minutes: Double) {
        self.id = id
        self.start = start
        self.duration = minutes * 60
    }

    var end: Date { start.addingTimeInterval(duration) }
}
