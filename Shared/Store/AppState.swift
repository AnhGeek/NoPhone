import SwiftUI
import Observation

/// Single source of truth for the session.
///
/// Deliberately a plain in-memory model with JSON persistence: the shape of the
/// data is what the UI is designed against, and swapping the backing store for
/// DeviceActivity + a real API later touches only `refreshUsage()` and
/// `QuestCatalog`.
@Observable
final class AppState {

    // MARK: - State

    var profile: UserProfile
    var apps: [TrackedApp]
    var quests: [Quest]
    var ledger: [RewardGrant]
    var lockScreenStyle: LockScreenStyle
    /// Day boundary the current numbers belong to; crossing it refills bars.
    var dayStart: Date

    /// Set when a reward lands, so the UI can throw confetti and say what was
    /// earned. Cleared by the presenting view.
    var pendingCelebration: Celebration?

    // MARK: - Init

    init(profile: UserProfile = .sample,
         apps: [TrackedApp] = SampleData.apps,
         quests: [Quest] = SampleData.quests,
         ledger: [RewardGrant] = SampleData.ledger,
         lockScreenStyle: LockScreenStyle = .rainbowStack) {
        self.profile = profile
        self.apps = apps
        self.quests = quests
        self.ledger = ledger
        self.lockScreenStyle = lockScreenStyle
        self.dayStart = Calendar.current.startOfDay(for: .now)
    }

    // MARK: - Aggregates

    var totalBudget: TimeInterval { apps.reduce(0) { $0 + $1.totalSeconds } }
    var totalUsed: TimeInterval { apps.reduce(0) { $0 + $1.usedSeconds } }
    var totalRemaining: TimeInterval { apps.reduce(0) { $0 + $1.remainingSeconds } }
    var totalEarnedToday: TimeInterval { apps.reduce(0) { $0 + $1.bonusSeconds } }
    var totalOpens: Int { apps.reduce(0) { $0 + $1.openCount } }

    var dayFraction: Double {
        guard totalBudget > 0 else { return 0 }
        return min(1, max(0, totalRemaining / totalBudget))
    }

    var overallStatus: BudgetStatus {
        switch dayFraction {
        case ..<0.001: .spent
        case ..<0.15:  .critical
        case ..<0.4:   .low
        default:       .healthy
        }
    }

    /// Ordered for the home list: the apps closest to empty first, because
    /// those are the ones a decision is pending on.
    var appsByUrgency: [TrackedApp] {
        apps.sorted { $0.remainingFraction < $1.remainingFraction }
    }

    var lockScreenApps: [TrackedApp] {
        apps.filter(\.pinnedToLockScreen).sorted { $0.remainingFraction < $1.remainingFraction }
    }

    var claimableQuests: [Quest] {
        quests.filter { $0.isClaimable(for: profile.tier) }
    }

    var lockedQuests: [Quest] {
        quests.filter { !profile.tier.canAccess($0.tier) }
    }

    /// Minutes still on the table today — the headline on the quests screen.
    /// Uses the *effective* payout so a Champion sees the number they'd
    /// actually receive, not the base figure.
    var claimableMinutes: Int {
        claimableQuests.reduce(0) {
            $0 + effectiveReward(for: $1) * ($1.maxPerWindow - $1.completionsInWindow)
        }
    }

    // MARK: - Mutations

    /// Grant a quest's reward. The minutes come from the quest definition, so
    /// there is no path here that lets the client inflate a payout.
    @discardableResult
    func claim(_ quest: Quest) -> Bool {
        guard let index = quests.firstIndex(where: { $0.id == quest.id }) else { return false }
        guard quests[index].isClaimable(for: profile.tier) else { return false }

        let earned = effectiveReward(for: quests[index])
        quests[index].completionsInWindow += 1
        quests[index].lastCompletedAt = .now

        let targetName = applyMinutes(earned, to: quests[index].targetAppID)

        ledger.insert(
            RewardGrant(questTitle: quest.title,
                        minutes: earned,
                        appName: targetName,
                        symbol: quest.symbol,
                        tint: quest.tint),
            at: 0
        )

        profile.xp += earned * 2
        while profile.xp >= profile.xpToNextLevel {
            profile.xp -= profile.xpToNextLevel
            profile.level += 1
            profile.xpToNextLevel = Int(Double(profile.xpToNextLevel) * 1.25)
        }

        pendingCelebration = Celebration(
            title: "+\(earned) minutes!",
            subtitle: targetName.map { "Added to \($0)" } ?? "Shared across your apps",
            symbol: quest.symbol,
            tint: quest.tint,
            boosted: earned > quest.rewardMinutes
        )
        return true
    }

    /// Champions earn a flat multiplier on base quests. The *base* number is
    /// still admin-set; premium only scales it, and only by a published rate.
    func effectiveReward(for quest: Quest) -> Int {
        guard profile.tier == .premium else { return quest.rewardMinutes }
        return Int((Double(quest.rewardMinutes) * MembershipPerks.premiumMultiplier).rounded())
    }

    /// Distribute earned minutes. A targeted quest tops up one app; an untargeted
    /// one spreads evenly, so a reward never becomes a lever to overload a
    /// single app someone is already struggling with.
    @discardableResult
    private func applyMinutes(_ minutes: Int, to appID: UUID?) -> String? {
        guard minutes > 0 else { return nil }

        if let appID, let index = apps.firstIndex(where: { $0.id == appID }) {
            apps[index].bonusSeconds += Double(minutes) * 60
            return apps[index].name
        }

        let share = Double(minutes) * 60 / Double(max(1, apps.count))
        for index in apps.indices { apps[index].bonusSeconds += share }
        return nil
    }

    /// Manually top up one app — used by the detail screen's "spend earned
    /// time here" control.
    func addBonus(minutes: Int, to appID: UUID) {
        guard let index = apps.firstIndex(where: { $0.id == appID }) else { return }
        apps[index].bonusSeconds += Double(minutes) * 60
    }

    /// Stand-in for the DeviceActivity callback: record a pickup.
    func recordUsage(minutes: Double, for appID: UUID, at date: Date = .now) {
        guard let index = apps.firstIndex(where: { $0.id == appID }) else { return }
        apps[index].usedSeconds += minutes * 60
        apps[index].sessions.append(UsageSession(start: date, minutes: minutes))
    }

    func togglePin(_ appID: UUID) {
        guard let index = apps.firstIndex(where: { $0.id == appID }) else { return }
        apps[index].pinnedToLockScreen.toggle()
    }

    func setBudget(minutes: Double, for appID: UUID) {
        guard let index = apps.firstIndex(where: { $0.id == appID }) else { return }
        apps[index].budgetSeconds = minutes * 60
    }

    /// New day: bars refill, bonuses expire, daily quests come back.
    func rolloverDay() {
        let metGoal = totalUsed <= totalBudget
        profile.streakDays = metGoal ? profile.streakDays + 1 : 0

        for index in apps.indices {
            apps[index].usedSeconds = 0
            apps[index].bonusSeconds = 0
            apps[index].sessions = []
        }
        for index in quests.indices where quests[index].cadence == .daily {
            quests[index].completionsInWindow = 0
        }
        dayStart = Calendar.current.startOfDay(for: .now)
    }

    func upgradeToPremium() { profile.tier = .premium }

    func app(with id: UUID) -> TrackedApp? { apps.first { $0.id == id } }
}

/// Payload for the reward celebration overlay.
struct Celebration: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var subtitle: String
    var symbol: String
    var tint: AppTint
    var boosted: Bool
}

/// Published, fixed perk values — surfaced verbatim on the paywall so the
/// numbers a person sees are the numbers the logic uses.
enum MembershipPerks {
    static let premiumMultiplier = 1.5
    static let premiumDailyQuestSlots = 8
    static let freeDailyQuestSlots = 3
}
