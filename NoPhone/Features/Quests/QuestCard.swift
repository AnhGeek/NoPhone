import SwiftUI

/// A single quest.
///
/// Three visual states, and they must be distinguishable at a glance:
/// **claimable** (full color, live button), **done for now** (checked, muted,
/// still readable so you get credit for it), and **locked** (visible, greyed,
/// with the crown — the pitch only works if you can see what you're missing).
struct QuestCard: View {
    let quest: Quest
    let userTier: MembershipTier
    /// Minutes actually granted, after any Champion multiplier.
    let payout: Int
    var onClaim: () -> Void
    var onUnlock: () -> Void

    @State private var justClaimed = false

    private var locked: Bool { !userTier.canAccess(quest.tier) }
    private var done: Bool { quest.isExhausted }
    private var boosted: Bool { payout > quest.rewardMinutes }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            header
            if !quest.detail.isEmpty {
                Text(quest.detail)
                    .font(Typo.callout)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            meta
            action
        }
        .padding(Space.md)
        .cardSurface()
        .opacity(done ? 0.75 : 1)
        .saturation(locked ? 0.35 : 1)
        .overlay(alignment: .topTrailing) {
            if locked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white)
                    .padding(7)
                    .background(Circle().fill(AppTint.grape.gradient))
                    .overlay(Circle().strokeBorder(Theme.outline, lineWidth: 2))
                    .offset(x: 6, y: -8)
            }
        }
        .scaleEffect(justClaimed ? 1.03 : 1)
        .animation(Motion.bounce, value: justClaimed)
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(alignment: .top, spacing: Space.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(quest.tint.gradient)
                    .frame(width: 48, height: 48)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Theme.outline, lineWidth: Stroke.thin))
                Image(systemName: done ? "checkmark" : quest.symbol)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(quest.tint.contrastInk)
            }
            .glossy(radius: 16, intensity: 0.45)

            VStack(alignment: .leading, spacing: 3) {
                Text(quest.title)
                    .font(Typo.headline)
                    .foregroundStyle(Theme.textPrimary)
                    .strikethrough(done, color: Theme.textTertiary)
                HStack(spacing: 5) {
                    Chip(text: quest.cadence.title, symbol: quest.cadence.symbol,
                         tint: quest.tint)
                    if quest.tier == .premium {
                        Chip(text: "Champion", symbol: "crown.fill", tint: .grape, solid: true)
                    }
                }
            }

            Spacer(minLength: Space.xxs)

            RewardToken(minutes: payout, tint: boosted ? .grape : .sunshine, boosted: boosted)
        }
    }

    private var meta: some View {
        HStack(spacing: Space.xs) {
            // Per-window pips: "you can claim this twice a day, once done".
            HStack(spacing: 4) {
                ForEach(0..<quest.maxPerWindow, id: \.self) { index in
                    Capsule()
                        .fill(index < quest.completionsInWindow
                              ? AnyShapeStyle(quest.tint.gradient)
                              : AnyShapeStyle(Theme.well))
                        .frame(width: 18, height: 7)
                        .overlay(Capsule().strokeBorder(Theme.outlineSoft, lineWidth: 1))
                }
            }

            Text(done ? "Done for \(quest.cadence == .daily ? "today" : "this week")"
                      : "\(quest.maxPerWindow - quest.completionsInWindow) left")
                .font(Typo.micro)
                .foregroundStyle(Theme.textTertiary)

            Spacer()

            // The integrity note. Small, permanent, and on every quest.
            Label("Set by your admin", systemImage: "checkmark.shield.fill")
                .font(Typo.micro)
                .foregroundStyle(Theme.textTertiary)
        }
    }

    @ViewBuilder
    private var action: some View {
        if locked {
            JellyButton(title: "Unlock with Champion", symbol: "crown.fill",
                        tint: .grape, size: .small, fullWidth: true, action: onUnlock)
        } else if done {
            HStack(spacing: Space.xs) {
                Image(systemName: "checkmark.circle.fill")
                Text("Claimed")
            }
            .font(Typo.caption.weight(.heavy))
            .foregroundStyle(Theme.good)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.xs)
            .background(Capsule().fill(Theme.good.opacity(0.15)))
            .overlay(Capsule().strokeBorder(Theme.good.opacity(0.45), lineWidth: 1.5))
        } else {
            JellyButton(title: "I did it — claim \(payout) min",
                        symbol: "checkmark.circle.fill",
                        tint: quest.tint, size: .small, fullWidth: true) {
                justClaimed = true
                onClaim()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { justClaimed = false }
            }
        }
    }
}

#Preview("Quest cards") {
    ScrollView {
        VStack(spacing: Space.md) {
            QuestCard(quest: SampleData.quests[0], userTier: .free,
                      payout: 5, onClaim: {}, onUnlock: {})
            QuestCard(quest: {
                var q = SampleData.quests[1]; q.completionsInWindow = 2; return q
            }(), userTier: .free, payout: 15, onClaim: {}, onUnlock: {})
            QuestCard(quest: SampleData.quests[6], userTier: .free,
                      payout: 40, onClaim: {}, onUnlock: {})
            QuestCard(quest: SampleData.quests[6], userTier: .premium,
                      payout: 60, onClaim: {}, onUnlock: {})
        }
        .padding(Space.gutter)
    }
    .playgroundBackground()
}
