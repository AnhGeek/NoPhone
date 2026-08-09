import SwiftUI

/// A to-do that buys screen time back.
///
/// The reward is **fixed by the admin**, never chosen by the person doing the
/// task — that is the whole integrity of the system. `rewardMinutes` therefore
/// lives on the catalog definition (server-owned), and the client only ever
/// records *completions*.
struct Quest: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var detail: String
    var symbol: String
    var tint: AppTint

    /// Minutes granted on completion. Admin-set, immutable on the client.
    let rewardMinutes: Int
    /// Free members can see premium quests but not claim them — the lock is
    /// part of the pitch, so they stay visible.
    let tier: MembershipTier
    /// How often the quest can be claimed.
    let cadence: QuestCadence
    /// Times claimed within the current cadence window.
    var completionsInWindow: Int
    /// Max claims per window — a 5-minute quest you can farm is not a reward.
    let maxPerWindow: Int
    var lastCompletedAt: Date?

    /// Optional: apply the reward to one specific app rather than the shared
    /// pool. Admins use this to steer time toward, say, a language app.
    var targetAppID: UUID?

    init(id: UUID = UUID(),
         title: String,
         detail: String,
         symbol: String,
         tint: AppTint,
         rewardMinutes: Int,
         tier: MembershipTier = .free,
         cadence: QuestCadence = .daily,
         maxPerWindow: Int = 1,
         completionsInWindow: Int = 0,
         lastCompletedAt: Date? = nil,
         targetAppID: UUID? = nil) {
        self.id = id
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.tint = tint
        self.rewardMinutes = rewardMinutes
        self.tier = tier
        self.cadence = cadence
        self.maxPerWindow = maxPerWindow
        self.completionsInWindow = completionsInWindow
        self.lastCompletedAt = lastCompletedAt
        self.targetAppID = targetAppID
    }

    var isExhausted: Bool { completionsInWindow >= maxPerWindow }

    /// Progress toward the per-window cap, for the little segmented pips.
    var windowProgress: Double {
        guard maxPerWindow > 0 else { return 0 }
        return Double(completionsInWindow) / Double(maxPerWindow)
    }

    func isClaimable(for userTier: MembershipTier) -> Bool {
        !isExhausted && userTier.canAccess(self.tier)
    }
}

enum QuestCadence: String, Codable, CaseIterable {
    case daily, weekly, once

    var title: String {
        switch self {
        case .daily:  "Daily"
        case .weekly: "Weekly"
        case .once:   "One-off"
        }
    }

    var symbol: String {
        switch self {
        case .daily:  "sun.max.fill"
        case .weekly: "calendar"
        case .once:   "star.fill"
        }
    }
}

enum MembershipTier: String, Codable, CaseIterable {
    case free, premium

    var title: String { self == .free ? "Explorer" : "Champion" }

    var badgeSymbol: String { self == .free ? "leaf.fill" : "crown.fill" }

    var tint: AppTint { self == .free ? .mint : .grape }

    /// Premium sees everything; free sees only free.
    func canAccess(_ required: MembershipTier) -> Bool {
        self == .premium || required == .free
    }
}

/// A granted reward, kept for the ledger on the rewards screen. Time earned
/// should always be auditable — "where did my extra 40 minutes come from?"
struct RewardGrant: Identifiable, Codable, Hashable {
    let id: UUID
    var questTitle: String
    var minutes: Int
    var grantedAt: Date
    var appName: String?
    var symbol: String
    var tint: AppTint

    init(id: UUID = UUID(),
         questTitle: String,
         minutes: Int,
         grantedAt: Date = .now,
         appName: String? = nil,
         symbol: String,
         tint: AppTint) {
        self.id = id
        self.questTitle = questTitle
        self.minutes = minutes
        self.grantedAt = grantedAt
        self.appName = appName
        self.symbol = symbol
        self.tint = tint
    }
}

/// The person using the app.
struct UserProfile: Codable, Hashable {
    var displayName: String
    var tier: MembershipTier
    /// Consecutive days finishing under budget.
    var streakDays: Int
    /// Cosmetic progression — levels unlock mascot outfits and bar skins.
    var level: Int
    var xp: Int
    var xpToNextLevel: Int

    var xpFraction: Double {
        guard xpToNextLevel > 0 else { return 0 }
        return min(1, Double(xp) / Double(xpToNextLevel))
    }

    static let sample = UserProfile(
        displayName: "Alex",
        tier: .free,
        streakDays: 6,
        level: 4,
        xp: 320,
        xpToNextLevel: 500
    )
}
