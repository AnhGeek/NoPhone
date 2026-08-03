import SwiftUI

/// The daily dashboard.
///
/// Structure, top to bottom: who you are and how you're doing → the one number
/// that matters → a fast strip of every app → the earn-time prompt → the full
/// per-app list. Anything that costs the person time to read is below the
/// answer to "how am I doing?", never above it.
struct HomeView: View {
    @Environment(AppState.self) private var state
    @Binding var selectedAppID: UUID?
    var onOpenQuests: () -> Void

    @State private var showRolloverHint = false

    var body: some View {
        ScrollView {
            VStack(spacing: Space.lg) {
                greeting
                dayHero
                quickStrip
                earnBanner
                appList
                footerNote
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.xs)
            .padding(.bottom, 120)   // clears the floating tab bar
        }
        .scrollIndicators(.hidden)
        .playgroundBackground(tints: [state.overallStatus == .spent ? .cherry : .grape,
                                      .bubblegum, .sky, .sunshine])
    }

    // MARK: - Greeting

    private var greeting: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Fmt.greeting())
                    .eyebrow()
                    .foregroundStyle(Theme.textTertiary)
                Text(state.profile.displayName)
                    .font(Typo.title)
                    .foregroundStyle(Theme.textPrimary)
            }

            Spacer()

            HStack(spacing: Space.xs) {
                StreakPill(days: state.profile.streakDays)
                if state.profile.tier == .premium { CrownBadge() }
            }
        }
        .padding(.top, Space.xs)
    }

    // MARK: - Hero

    /// One ring, one number: the whole day's remaining time. Everything else on
    /// this screen is a breakdown of this.
    private var dayHero: some View {
        VStack(spacing: Space.md) {
            BudgetRing(fraction: state.dayFraction,
                       tint: heroTint,
                       lineWidth: 26) {
                VStack(spacing: 0) {
                    Text(Fmt.clock(state.totalRemaining))
                        .font(Typo.timer(54))
                        .foregroundStyle(Theme.textPrimary)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(Fmt.clockUnit(state.totalRemaining))
                        .font(Typo.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Text(state.overallStatus.label)
                        .font(Typo.micro)
                        .foregroundStyle(state.overallStatus.color)
                        .padding(.top, Space.xxs)
                }
            }
            .frame(width: 230, height: 230)
            .padding(.top, Space.xs)

            MascotSpeech(mood: Mascot.Mood(status: state.overallStatus),
                         tint: heroTint,
                         text: heroLine,
                         size: 78)

            HStack(spacing: Space.sm) {
                StatBubble(value: "\(state.totalOpens)", label: "opens", symbol: "hand.tap.fill", tint: .sky)
                StatBubble(value: Fmt.short(state.totalUsed), label: "used", symbol: "hourglass", tint: .tangerine)
                StatBubble(value: "+\(Int(state.totalEarnedToday / 60))m", label: "earned", symbol: "gift.fill", tint: .mint)
            }
        }
        .padding(.vertical, Space.md)
        .padding(.horizontal, Space.sm)
        .cardSurface(radius: Radius.xl, shadow: .lift)
    }

    private var heroTint: AppTint {
        switch state.overallStatus {
        case .healthy:  .mint
        case .low:      .sunshine
        case .critical: .tangerine
        case .spent:    .cherry
        }
    }

    private var heroLine: String {
        switch state.overallStatus {
        case .healthy:
            "\(Fmt.short(state.totalRemaining)) still on the clock. Spend it well."
        case .low:
            "About \(Fmt.short(state.totalRemaining)) left — worth pacing now."
        case .critical:
            "Nearly out. A quest or two would top you back up."
        case .spent:
            "Today's time is gone. Tomorrow the bars refill on their own."
        }
    }

    // MARK: - Quick strip

    private var quickStrip: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(eyebrow: "At a glance", title: "Every app", symbol: "circle.grid.3x3.fill") {
                Chip(text: "\(state.apps.count)", tint: .grape)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.sm) {
                    ForEach(state.appsByUrgency) { app in
                        AppMiniTile(app: app) { selectedAppID = app.id }
                    }
                }
                .padding(.vertical, Space.xxs)
                .padding(.horizontal, 2)
            }
            // Bleed the scroller to the screen edges so the row reads as
            // continuing past the gutter rather than ending at it.
            .padding(.horizontal, -Space.gutter)
            .padding(.leading, Space.gutter)
        }
    }

    // MARK: - Earn banner

    /// The bridge between "you're running out" and "here's what to do about
    /// it". Shown always, but it changes voice when time is short.
    private var earnBanner: some View {
        Button(action: onOpenQuests) {
            HStack(spacing: Space.sm) {
                ZStack {
                    Circle().fill(Palette.sunshine.gradientish)
                        .frame(width: 52, height: 52)
                        .overlay(Circle().strokeBorder(Theme.outline, lineWidth: Stroke.thin))
                    Image(systemName: "checklist")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(Palette.ink)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(state.overallStatus == .healthy ? "Bank some extra time" : "Need more time?")
                        .font(Typo.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(state.claimableMinutes) min waiting in today's quests")
                        .font(Typo.caption)
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer(minLength: Space.xxs)

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(Space.md)
            .sticker(
                LinearGradient(colors: [Palette.sunshineUp.opacity(0.55), Palette.mintUp.opacity(0.45)],
                               startPoint: .leading, endPoint: .trailing),
                radius: Radius.lg
            )
        }
        .buttonStyle(.plain)
        .jellyPress(scale: 0.97)
    }

    // MARK: - List

    private var appList: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(eyebrow: "Today", title: "Time left per app", symbol: "chart.bar.fill") {
                Chip(text: "Most urgent first", tint: .sky)
            }
            ForEach(state.appsByUrgency) { app in
                AppBudgetCard(app: app) { selectedAppID = app.id }
            }
        }
    }

    private var footerNote: some View {
        VStack(spacing: Space.xs) {
            Image(systemName: "sunrise.fill")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(Palette.tangerine)
            Text("Every bar refills at midnight.")
                .font(Typo.caption)
                .foregroundStyle(Theme.textSecondary)
            Text("Tap to preview tomorrow")
                .font(Typo.micro)
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(Space.md)
        .onTapGesture { showRolloverHint.toggle() }
        .overlay(alignment: .bottom) {
            if showRolloverHint {
                Text("Tomorrow you start with \(Fmt.short(state.totalBudget)).")
                    .font(Typo.caption)
                    .padding(Space.xs)
                    .background(Capsule().fill(Theme.surface))
                    .overlay(Capsule().strokeBorder(Theme.outline, lineWidth: 1.5))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(Motion.jelly, value: showRolloverHint)
    }
}

// MARK: - Small pieces

/// Compact metric bubble used in a row of three under the hero ring.
struct StatBubble: View {
    var value: String
    var label: String
    var symbol: String
    var tint: AppTint

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(tint.deep)
            Text(value)
                .font(Typo.body.monospacedDigit())
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(Typo.micro)
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xs)
        .background(
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .fill(tint.base.opacity(0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .strokeBorder(tint.base.opacity(0.45), lineWidth: 1.5)
        )
    }
}

/// Streak counter. Flames earn their place here — a streak is the one metric
/// people are genuinely competitive with themselves about.
struct StreakPill: View {
    var days: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12, weight: .black))
            Text("\(days)")
                .font(Typo.body.monospacedDigit())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Space.xs + 2)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(
                LinearGradient(colors: [Palette.sunshine, Palette.tangerine, Palette.cherry],
                               startPoint: .top, endPoint: .bottom)
            )
        )
        .overlay(Capsule().strokeBorder(Theme.outline, lineWidth: 2))
        .shadow(color: Palette.tangerine.opacity(0.45), radius: 6, y: 2)
        .accessibilityLabel("\(days) day streak")
    }
}

extension Color {
    /// Convenience for the few places that want a vertical wash of one color
    /// without a full `AppTint`.
    var gradientish: LinearGradient {
        LinearGradient(colors: [opacity(0.95), self], startPoint: .top, endPoint: .bottom)
    }
}

#Preview("Home") {
    HomeView(selectedAppID: .constant(nil), onOpenQuests: {})
        .environment(AppState())
}
