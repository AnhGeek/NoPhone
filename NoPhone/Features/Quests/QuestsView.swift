import SwiftUI

/// Earn time back.
///
/// The reward number is the hero of every row — it is the reason anyone opens
/// this tab. Rewards are admin-set and shown as fixed tokens with a small
/// "set by your admin" note, so it is unambiguous that the number is not
/// negotiable and not something the app made up.
struct QuestsView: View {
    @Environment(AppState.self) private var state
    @State private var filter: QuestFilter = .all
    @State private var showPaywall = false

    enum QuestFilter: String, CaseIterable, Identifiable {
        case all, daily, weekly, locked
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all:    "All"
            case .daily:  "Daily"
            case .weekly: "Weekly"
            case .locked: "Champion"
            }
        }
    }

    private var visibleQuests: [Quest] {
        switch filter {
        case .all:    state.quests
        case .daily:  state.quests.filter { $0.cadence == .daily }
        case .weekly: state.quests.filter { $0.cadence != .daily }
        case .locked: state.quests.filter { $0.tier == .premium }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Space.lg) {
                banner
                filterBar
                questList
                if state.profile.tier == .free { upsell }
                ledgerSection
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .playgroundBackground(tints: [.mint, .sunshine, .sky, .bubblegum])
        .sheet(isPresented: $showPaywall) { PremiumView() }
    }

    // MARK: - Banner

    private var banner: some View {
        VStack(spacing: Space.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Quests")
                        .eyebrow()
                        .foregroundStyle(Theme.textTertiary)
                    Text("Do stuff, earn time")
                        .font(Typo.title)
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer()
                Mascot(mood: .celebrating, tint: .sunshine, size: 64)
            }

            HStack(spacing: Space.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Up for grabs today")
                        .font(Typo.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Text("\(state.claimableMinutes) min")
                        .font(Typo.timer(34))
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer()
                RewardToken(minutes: state.claimableMinutes, tint: .mint, size: 1.25)
            }
            .padding(Space.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(Theme.surfaceSunk)
            )

            LevelBar(profile: state.profile)
        }
        .padding(Space.md)
        .cardSurface(radius: Radius.xl, shadow: .lift)
    }

    // MARK: - Filters

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.xs) {
                ForEach(QuestFilter.allCases) { option in
                    Button {
                        withAnimation(Motion.jelly) { filter = option }
                    } label: {
                        Text(option.title)
                            .font(Typo.caption.weight(.heavy))
                            .foregroundStyle(filter == option ? Color.white : Theme.textSecondary)
                            .padding(.horizontal, Space.md)
                            .padding(.vertical, Space.xs)
                            .background(
                                Capsule().fill(filter == option
                                               ? AnyShapeStyle(AppTint.grape.gradient)
                                               : AnyShapeStyle(Theme.surface))
                            )
                            .overlay(Capsule().strokeBorder(Theme.outline, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .jellyPress()
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - List

    private var questList: some View {
        VStack(spacing: Space.sm) {
            ForEach(visibleQuests) { quest in
                QuestCard(quest: quest,
                          userTier: state.profile.tier,
                          payout: state.effectiveReward(for: quest),
                          onClaim: { state.claim(quest) },
                          onUnlock: { showPaywall = true })
            }

            if visibleQuests.isEmpty {
                EmptyNote(symbol: "checkmark.seal.fill", text: "Nothing here right now.")
            }
        }
    }

    // MARK: - Upsell

    private var upsell: some View {
        Button { showPaywall = true } label: {
            HStack(spacing: Space.sm) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(AppTint.grape.gradient))
                    .overlay(Circle().strokeBorder(Theme.outline, lineWidth: Stroke.thin))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Champion rewards")
                        .font(Typo.headline)
                        .foregroundStyle(.white)
                    Text("\(Int(MembershipPerks.premiumMultiplier * 100 - 100))% more minutes on every quest")
                        .font(Typo.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(Space.md)
            .sticker(
                LinearGradient(colors: [Palette.grape, Palette.bubblegum, Palette.tangerine],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                radius: Radius.lg
            )
        }
        .buttonStyle(.plain)
        .jellyPress(scale: 0.97)
    }

    // MARK: - Ledger

    private var ledgerSection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(eyebrow: "History", title: "Time you earned",
                          symbol: "clock.arrow.circlepath")

            if state.ledger.isEmpty {
                EmptyNote(symbol: "tray", text: "No rewards yet today. Pick a quest above.")
            } else {
                VStack(spacing: 0) {
                    ForEach(state.ledger) { grant in
                        HStack(spacing: Space.sm) {
                            Image(systemName: grant.symbol)
                                .font(.system(size: 14, weight: .black))
                                .foregroundStyle(grant.tint.contrastInk)
                                .frame(width: 32, height: 32)
                                .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(grant.tint.gradient))
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Theme.outline, lineWidth: 1.5))

                            VStack(alignment: .leading, spacing: 1) {
                                Text(grant.questTitle)
                                    .font(Typo.body)
                                    .foregroundStyle(Theme.textPrimary)
                                Text(grant.appName.map { "→ \($0)" } ?? "→ shared across apps")
                                    .font(Typo.micro)
                                    .foregroundStyle(Theme.textTertiary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 1) {
                                Text("+\(grant.minutes)m")
                                    .font(Typo.body.monospacedDigit())
                                    .foregroundStyle(Theme.good)
                                Text(Fmt.relative(grant.grantedAt))
                                    .font(Typo.micro)
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                        .padding(.vertical, Space.xs)

                        if grant.id != state.ledger.last?.id {
                            Divider().overlay(Theme.outlineSoft)
                        }
                    }
                }
                .padding(Space.sm)
                .cardSurface()
            }
        }
    }
}

/// XP bar. Cosmetic progression only — levels unlock mascot outfits and bar
/// skins, never extra time. Time comes from quests, and only from quests.
struct LevelBar: View {
    var profile: UserProfile

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            HStack {
                Text("Level \(profile.level)")
                    .font(Typo.caption)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(profile.xp)/\(profile.xpToNextLevel) XP")
                    .font(Typo.micro.monospacedDigit())
                    .foregroundStyle(Theme.textTertiary)
            }
            TimeBudgetBar(fraction: profile.xpFraction, tint: .grape,
                          height: 12, showTicks: false, showCap: false)
        }
    }
}

#Preview("Quests") {
    QuestsView().environment(AppState())
}
