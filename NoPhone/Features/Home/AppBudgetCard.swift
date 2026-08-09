import SwiftUI

/// One app's day, as a row on the home screen.
///
/// Reading order is deliberate: glyph (which app) → name → big remaining time
/// → bar → footnotes. The remaining time is the largest element in the row
/// because it is the only number that answers "can I open this right now?".
struct AppBudgetCard: View {
    let app: TrackedApp
    var onTap: () -> Void = {}

    private var spent: Bool { app.status == .spent }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Space.sm) {
                header
                TimeBudgetBar(fraction: app.remainingFraction,
                              bonusFraction: app.bonusFraction,
                              tint: app.tint,
                              height: 20)
                footer
            }
            .padding(Space.md)
            .cardSurface()
            // Spent apps recede rather than shout. The red is in the status
            // chip; desaturating the whole card would make the list a wall of
            // failure states by evening.
            .opacity(spent ? 0.72 : 1)
        }
        .buttonStyle(.plain)
        .jellyPress(scale: 0.975, sink: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(app.name)
        .accessibilityValue("\(Fmt.spoken(app.remainingSeconds)) remaining of \(Fmt.spoken(app.totalSeconds))")
        .accessibilityHint("Opens details")
    }

    private var header: some View {
        HStack(spacing: Space.sm) {
            AppGlyph(symbol: app.symbol, tint: app.tint, size: 46, dimmed: spent)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(Typo.headline)
                    .foregroundStyle(Theme.textPrimary)
                HStack(spacing: 5) {
                    Image(systemName: app.status.symbol)
                        .font(.system(size: 10, weight: .black))
                    Text(app.status.label)
                        .font(Typo.caption)
                }
                .foregroundStyle(app.status.color)
            }

            Spacer(minLength: Space.xs)

            VStack(alignment: .trailing, spacing: 0) {
                Text(Fmt.short(app.remainingSeconds))
                    .font(Typo.timer(24))
                    .foregroundStyle(spent ? Theme.textTertiary : Theme.textPrimary)
                Text("left")
                    .font(Typo.micro)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: Space.xs) {
            Label {
                Text("\(app.openCount) opens")
            } icon: {
                Image(systemName: "hand.tap.fill")
            }
            .font(Typo.caption)
            .foregroundStyle(Theme.textSecondary)

            Divider().frame(height: 12)

            Label {
                Text("\(Fmt.short(app.usedSeconds)) used")
            } icon: {
                Image(systemName: "hourglass")
            }
            .font(Typo.caption)
            .foregroundStyle(Theme.textSecondary)

            Spacer()

            if app.bonusSeconds > 0 {
                Chip(text: "+\(Int(app.bonusSeconds / 60)) earned",
                     symbol: "sparkles", tint: .sunshine, solid: true)
            }
            if !app.pinnedToLockScreen {
                Image(systemName: "lock.slash.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }
}

/// Squircle app glyph. Stands in for a real icon, and stays consistent with the
/// rest of the style — real third-party icons can only be drawn through
/// `FamilyControls`, which won't accept our outline treatment anyway.
struct AppGlyph: View {
    var symbol: String
    var tint: AppTint
    var size: CGFloat = 46
    var dimmed: Bool = false

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.44, weight: .black))
            .foregroundStyle(tint.contrastInk)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
                    .fill(tint.gradient)
            )
            .glossy(radius: size * 0.31, intensity: 0.5)
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
                    .strokeBorder(Theme.outline, lineWidth: Stroke.thin)
            )
            .saturation(dimmed ? 0.45 : 1)
            .shadow(color: tint.base.opacity(dimmed ? 0 : 0.35), radius: 6, y: 3)
    }
}

/// Dense variant for the horizontal "at a glance" strip at the top of Home.
struct AppMiniTile: View {
    let app: TrackedApp
    var onTap: () -> Void = {}
    /// Long-press affordance. Untracking is destructive and the tile is small,
    /// so the caller owns the confirmation — this only reports the intent.
    var onDelete: (() -> Void)?

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Space.xs) {
                MiniRing(fraction: app.remainingFraction, tint: app.tint,
                         symbol: app.symbol, size: 52, lineWidth: 7)
                Text(Fmt.short(app.remainingSeconds))
                    .font(Typo.caption.monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
                Text(app.name)
                    .font(Typo.micro)
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
            .frame(width: 76)
            .padding(.vertical, Space.sm)
            .padding(.horizontal, Space.xxs)
            .cardSurface(radius: Radius.md, shadow: .tight)
        }
        .buttonStyle(.plain)
        .jellyPress()
        // A `contextMenu` here would be system chrome in the middle of a
        // sticker sheet, so the hold raises this app's own confirm card
        // instead. Simultaneous so it never steals the tap that opens detail.
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45)
                .onEnded { _ in onDelete?() }
        )
    }
}

#Preview("App cards") {
    ScrollView {
        VStack(spacing: Space.md) {
            ForEach(SampleData.apps) { app in
                AppBudgetCard(app: app)
            }
        }
        .padding(Space.gutter)
    }
    .playgroundBackground()
}
