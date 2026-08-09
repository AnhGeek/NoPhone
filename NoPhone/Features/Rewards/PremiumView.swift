import SwiftUI

/// The Champion paywall.
///
/// Deliberately concrete: it lists the exact multiplier and slot counts the
/// logic uses, pulled from `MembershipPerks`, so there is no gap between the
/// promise and the code. Vague premium copy is how people end up feeling
/// tricked, and this app's whole premise is that the numbers are trustworthy.
struct PremiumView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: Plan = .yearly
    @State private var shimmer = false

    enum Plan: String, CaseIterable, Identifiable {
        case monthly, yearly

        var id: String { rawValue }
        var title: String { self == .monthly ? "Monthly" : "Yearly" }
        var price: String { self == .monthly ? "$4.99" : "$34.99" }
        var note: String { self == .monthly ? "per month" : "per year — save 41%" }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Space.lg) {
                hero
                perks
                planPicker
                cta
                fineprint
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.xxl)
        }
        .scrollIndicators(.hidden)
        .playgroundBackground(tints: [.grape, .bubblegum, .sunshine, .sky])
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Theme.surface))
                    .overlay(Circle().strokeBorder(Theme.outline, lineWidth: 2))
            }
            .buttonStyle(.plain)
            .padding(Space.md)
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: Space.sm) {
            ZStack {
                ForEach(0..<3, id: \.self) { ring in
                    Circle()
                        .stroke(AppTint.grape.base.opacity(0.18), lineWidth: 2)
                        .frame(width: 120 + CGFloat(ring) * 34)
                        .scaleEffect(shimmer ? 1.06 : 0.98)
                        .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)
                            .delay(Double(ring) * 0.2), value: shimmer)
                }
                Mascot(mood: .celebrating, tint: .grape, size: 118)
                Image(systemName: "crown.fill")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(Palette.sunshine)
                    .shadow(color: Palette.tangerine.opacity(0.8), radius: 10)
                    .offset(y: -74)
            }
            .frame(height: 190)

            Text("Become a Champion")
                .font(Typo.title)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)

            Text("Every quest pays more, and there are more of them.")
                .font(Typo.callout)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Space.lg)
        .onAppear { shimmer = true }
    }

    // MARK: - Perks

    private var perks: some View {
        VStack(spacing: Space.sm) {
            PerkRow(symbol: "bolt.fill", tint: .sunshine,
                    title: "\(Int((MembershipPerks.premiumMultiplier - 1) * 100))% bigger rewards",
                    detail: "A 20-minute quest pays \(Int(20 * MembershipPerks.premiumMultiplier)) minutes.")
            PerkRow(symbol: "list.bullet.rectangle.fill", tint: .mint,
                    title: "\(MembershipPerks.premiumDailyQuestSlots) daily quests",
                    detail: "Up from \(MembershipPerks.freeDailyQuestSlots) — more ways to earn back.")
            PerkRow(symbol: "square.on.square.dashed", tint: .sky,
                    title: "All Lock Screen styles",
                    detail: "Including Dials and Bloop, plus custom bar skins.")
            PerkRow(symbol: "chart.line.uptrend.xyaxis", tint: .bubblegum,
                    title: "Full history",
                    detail: "Weekly and monthly trends, not just today.")
            PerkRow(symbol: "person.2.fill", tint: .tangerine,
                    title: "Family plan",
                    detail: "Up to six people, one subscription, shared quest board.")
        }
    }

    // MARK: - Plans

    private var planPicker: some View {
        HStack(spacing: Space.sm) {
            ForEach(Plan.allCases) { plan in
                Button {
                    withAnimation(Motion.jelly) { selectedPlan = plan }
                } label: {
                    VStack(spacing: 4) {
                        Text(plan.title)
                            .font(Typo.caption)
                            .foregroundStyle(Theme.textSecondary)
                        Text(plan.price)
                            .font(Typo.timer(28))
                            .foregroundStyle(Theme.textPrimary)
                        Text(plan.note)
                            .font(Typo.micro)
                            .foregroundStyle(selectedPlan == plan ? Theme.brand : Theme.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.md)
                    .cardSurface(radius: Radius.lg, shadow: selectedPlan == plan ? .card : .tight)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                            .strokeBorder(selectedPlan == plan ? Theme.brand : .clear,
                                          lineWidth: Stroke.thick)
                    )
                    .overlay(alignment: .top) {
                        if plan == .yearly {
                            Chip(text: "Best value", symbol: "star.fill", tint: .sunshine, solid: true)
                                .offset(y: -10)
                        }
                    }
                }
                .buttonStyle(.plain)
                .jellyPress(scale: 0.97)
            }
        }
        .padding(.top, Space.xs)
    }

    private var cta: some View {
        VStack(spacing: Space.sm) {
            JellyButton(title: "Start 7 days free", symbol: "crown.fill",
                        tint: .grape, size: .large, fullWidth: true) {
                state.upgradeToPremium()
                dismiss()
            }
            GhostButton(title: "Not right now") { dismiss() }
        }
    }

    private var fineprint: some View {
        Text("Cancel any time. Rewards you already earned stay earned — downgrading never takes minutes back.")
            .font(Typo.micro)
            .foregroundStyle(Theme.textTertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Space.md)
    }
}

struct PerkRow: View {
    var symbol: String
    var tint: AppTint
    var title: String
    var detail: String

    var body: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(tint.contrastInk)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.gradient))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.outline, lineWidth: Stroke.thin))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typo.body)
                    .foregroundStyle(Theme.textPrimary)
                Text(detail)
                    .font(Typo.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Space.sm)
        .cardSurface(radius: Radius.md, shadow: .tight)
    }
}

#Preview("Premium") {
    PremiumView().environment(AppState.preview)
}
