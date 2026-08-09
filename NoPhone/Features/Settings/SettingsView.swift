import SwiftUI

/// Profile and settings.
///
/// Also the home of the **reward table** — a read-only list of every quest's
/// admin-set payout. Publishing the whole table where anyone can check it is
/// what makes the "set by your admin" note on each quest card verifiable
/// rather than just an assertion.
struct SettingsView: View {
    @Environment(AppState.self) private var state
    @Environment(ScreenTimeService.self) private var screenTime
    #if targetEnvironment(simulator)
    @Environment(SimulatorUsageDriver.self) private var driver
    #endif
    @State private var showPaywall = false
    @State private var showRolloverConfirm = false
    @State private var showPicker = false
    @State private var showDiagnostics = false

    private var screenTimeDetail: String {
        switch screenTime.authorization {
        case .approved:            "Granted. Usage is measured by iOS."
        case .denied:              "Denied — budgets can't drain without it."
        case .unavailable(let why): why
        case .unknown:             "Not requested yet."
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Space.lg) {
                profileCard
                membershipCard
                rewardTable
                dataSection
                about
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.tabBarClearance)
        }
        .scrollIndicators(.hidden)
        .playgroundBackground(tints: [.bubblegum, .grape, .mint])
        .sheet(isPresented: $showPaywall) { PremiumView() }
        .screenTimeSetup(isPresented: $showPicker)
        .sheet(isPresented: $showDiagnostics) { DiagnosticsView() }
        .alert("Start a fresh day?", isPresented: $showRolloverConfirm) {
            Button("Roll over", role: .destructive) {
                withAnimation(Motion.smooth) { state.rolloverDay() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every bar refills, today's earned bonus time expires, and daily quests come back. This is what happens automatically at midnight.")
        }
    }

    // MARK: - Profile

    private var profileCard: some View {
        VStack(spacing: Space.sm) {
            Mascot(mood: Mascot.Mood(status: state.overallStatus),
                   tint: state.profile.tier.tint, size: 110)

            Text(state.profile.displayName)
                .font(Typo.title)
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: Space.xs) {
                Chip(text: state.profile.tier.title,
                     symbol: state.profile.tier.badgeSymbol,
                     tint: state.profile.tier.tint, solid: true)
                StreakPill(days: state.profile.streakDays)
            }

            LevelBar(profile: state.profile)
                .padding(.top, Space.xxs)

            HStack(spacing: Space.sm) {
                StatBubble(value: "\(state.apps.count)", label: "tracked",
                           symbol: "square.grid.2x2.fill", tint: .sky)
                StatBubble(value: Fmt.short(state.totalBudget), label: "daily budget",
                           symbol: "target", tint: .grape)
                StatBubble(value: "\(state.ledger.count)", label: "rewards",
                           symbol: "gift.fill", tint: .mint)
            }
        }
        .padding(Space.md)
        .cardSurface(radius: Radius.xl, shadow: .lift)
    }

    // MARK: - Membership

    private var membershipCard: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(eyebrow: "Membership", title: state.profile.tier.title,
                          symbol: state.profile.tier.badgeSymbol)

            if state.profile.tier == .free {
                Text("Champions earn \(Int((MembershipPerks.premiumMultiplier - 1) * 100))% more from every quest and get \(MembershipPerks.premiumDailyQuestSlots) daily slots instead of \(MembershipPerks.freeDailyQuestSlots).")
                    .font(Typo.callout)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                JellyButton(title: "See Champion", symbol: "crown.fill",
                            tint: .grape, fullWidth: true) { showPaywall = true }
            } else {
                Text("Champion is active. Quest rewards are multiplied by \(MembershipPerks.premiumMultiplier, specifier: "%.1f")×.")
                    .font(Typo.callout)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Chip(text: "Renews yearly", symbol: "arrow.clockwise", tint: .grape)
            }
        }
        .padding(Space.md)
        .cardSurface()
    }

    // MARK: - Reward table

    /// Read-only by design. The client can display these numbers; it can never
    /// author them.
    private var rewardTable: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(eyebrow: "Fixed by your admin", title: "Reward table",
                          symbol: "checkmark.shield.fill") {
                Chip(text: "Read only", symbol: "lock.fill", tint: .sky)
            }

            VStack(spacing: 0) {
                ForEach(state.quests) { quest in
                    HStack(spacing: Space.sm) {
                        Image(systemName: quest.symbol)
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(quest.tint.contrastInk)
                            .frame(width: 30, height: 30)
                            .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(quest.tint.gradient))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(quest.title)
                                .font(Typo.body)
                                .foregroundStyle(Theme.textPrimary)
                            Text("\(quest.cadence.title) · up to \(quest.maxPerWindow)×")
                                .font(Typo.micro)
                                .foregroundStyle(Theme.textTertiary)
                        }

                        Spacer()

                        if quest.tier == .premium {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(Theme.premium)
                        }

                        Text("\(quest.rewardMinutes)m")
                            .font(Typo.body.monospacedDigit())
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 42, alignment: .trailing)
                    }
                    .padding(.vertical, Space.xs)

                    if quest.id != state.quests.last?.id {
                        Divider().overlay(Theme.outlineSoft)
                    }
                }
            }
            .padding(Space.sm)
            .cardSurface()

            Text("Values come from your admin's configuration. The app can show them, never change them.")
                .font(Typo.micro)
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(eyebrow: "Your day", title: "Controls", symbol: "slider.horizontal.3")

            VStack(spacing: Space.sm) {
                SettingRow(symbol: "sunrise.fill", tint: .tangerine,
                           title: "Start a fresh day",
                           detail: "Refill every bar now, the way midnight would.") {
                    showRolloverConfirm = true
                }
                SettingRow(symbol: "apps.iphone", tint: .grape,
                           title: "Tracked apps",
                           detail: "\(state.apps.count) on a budget. Add more or change one.") {
                    showPicker = true
                }
                #if targetEnvironment(simulator)
                // Development only — the Simulator has no Screen Time stack,
                // so this drives the real pipeline by hand.
                SettingRow(symbol: driver.isRunning ? "pause.fill" : "play.fill",
                           tint: .tangerine,
                           title: driver.isRunning ? "Stop simulated usage" : "Simulate usage",
                           detail: "Burns \(Int(UsageBridge.tickMinutes))m every \(Int(SimulatorUsageDriver.secondsPerTick))s through the real usage path.") {
                    if driver.isRunning { driver.stop() } else { driver.start(driving: state) }
                }
                #endif
                SettingRow(symbol: "bell.badge.fill", tint: .bubblegum,
                           title: "Nudges",
                           detail: "A heads-up at 75%, 90% and empty.") {}
                SettingRow(symbol: "hand.raised.fill", tint: .sky,
                           title: "Screen Time permission",
                           detail: screenTimeDetail) {}
                SettingRow(symbol: "stethoscope", tint: .mint,
                           title: "Diagnostics",
                           detail: "What the app and the monitor recorded. Share it when reporting a problem.") {
                    showDiagnostics = true
                }
            }
            .padding(Space.sm)
            .cardSurface()
        }
    }

    private var about: some View {
        VStack(spacing: Space.xs) {
            Mascot(mood: .chill, tint: .sky, size: 54)
            Text("NoPhone")
                .font(Typo.headline)
                .foregroundStyle(Theme.textPrimary)
            Text("Your day starts full. Spend it on purpose.")
                .font(Typo.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.lg)
    }
}

struct SettingRow: View {
    var symbol: String
    var tint: AppTint
    var title: String
    var detail: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.sm) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(tint.contrastInk)
                    .frame(width: 36, height: 36)
                    .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(tint.gradient))
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(Theme.outline, lineWidth: 1.5))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(Typo.body)
                        .foregroundStyle(Theme.textPrimary)
                    Text(detail)
                        .font(Typo.micro)
                        .foregroundStyle(Theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.vertical, Space.xxs)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Settings") {
    SettingsView()
        .environment(AppState.preview)
        .environment(ScreenTimeService())
        #if targetEnvironment(simulator)
        .environment(SimulatorUsageDriver())
        #endif
}
