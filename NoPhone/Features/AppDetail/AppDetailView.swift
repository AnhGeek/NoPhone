import SwiftUI
import FamilyControls
import ManagedSettings

/// One app, in full.
///
/// Answers three questions in order: how much is left, where did it go, and
/// what can I do about it. The "where did it go" part is the reason this
/// screen exists — the home row tells you the total; only the timeline tells
/// you it was fourteen pickups.
struct AppDetailView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let appID: UUID

    @State private var showBudgetSheet = false

    private var app: TrackedApp? { state.app(with: appID) }

    var body: some View {
        ScrollView {
            if let app {
                VStack(spacing: Space.lg) {
                    hero(app)
                    stats(app)
                    timeline(app)
                    sessionList(app)
                    actions(app)
                }
                .padding(.horizontal, Space.gutter)
                .padding(.bottom, Space.tabBarClearance)
            } else {
                ContentUnavailableView("App not found", systemImage: "questionmark.app.dashed")
                    .padding(.top, 80)
            }
        }
        .scrollIndicators(.hidden)
        .playgroundBackground(tints: [app?.tint ?? .grape, .sky, .bubblegum])
        .navigationTitle(app?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let app { pinToggle(app) }
            }
        }
        .sheet(isPresented: $showBudgetSheet) {
            if let app { BudgetEditorSheet(app: app) }
        }
    }

    // MARK: - Lock Screen pin

    /// A `JellyButton` in miniature — same lozenge, outline, and offset shadow —
    /// but the symbol trails the label here, and the fill carries the state:
    /// candy when the app is on the widget, plain surface when it isn't.
    private func pinToggle(_ app: TrackedApp) -> some View {
        let pinned = app.pinnedToLockScreen
        return Button {
            withAnimation(Motion.jelly) { state.togglePin(app.id) }
        } label: {
            HStack(spacing: Space.xxs) {
                Text("Show on the widget").font(Typo.caption.weight(.heavy))
                Image(systemName: pinned ? "lock.fill" : "lock.slash")
                    .font(Typo.caption.weight(.black))
            }
            .foregroundStyle(pinned ? app.tint.contrastInk : Theme.textPrimary)
            .padding(.horizontal, Space.sm)
            .padding(.vertical, Space.xxs + 2)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(pinned ? AnyShapeStyle(app.tint.gradient)
                                     : AnyShapeStyle(Theme.surface))
                    Gloss(radius: Radius.sm, intensity: pinned ? 0.5 : 0)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .strokeBorder(Theme.outline, lineWidth: Stroke.medium)
            )
            .background(
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(Theme.shadowHard)
                    .offset(y: 4)
            )
            // One hit target: the words read as part of the control, so tapping
            // them must do what tapping the lock does.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .jellyPress()
        .accessibilityLabel(pinned ? "Remove from Lock Screen" : "Show on Lock Screen")
    }

    // MARK: - Hero

    private func hero(_ app: TrackedApp) -> some View {
        VStack(spacing: Space.md) {
            BudgetRing(fraction: app.remainingFraction, tint: app.tint, lineWidth: 24) {
                VStack(spacing: 2) {
                    AppGlyph(symbol: app.symbol, tint: app.tint, size: 44)
                    Text(Fmt.short(app.remainingSeconds))
                        .font(Typo.timer(30))
                        .foregroundStyle(Theme.textPrimary)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("left today")
                        .font(Typo.micro)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .frame(width: 210, height: 210)
            .padding(.bottom)
            .padding(.top)

            TimeBudgetBar(fraction: app.remainingFraction,
                          bonusFraction: app.bonusFraction,
                          tint: app.tint, height: 24)
                .padding(.horizontal, Space.xs)

            HStack(spacing: Space.xs) {
                Chip(text: app.status.label, symbol: app.status.symbol,
                     tint: app.tint, solid: true)
                Chip(text: app.category.title, symbol: app.category.symbol, tint: app.tint)
                if app.bonusSeconds > 0 {
                    Chip(text: "+\(Int(app.bonusSeconds / 60))m earned",
                         symbol: "sparkles", tint: .sunshine, solid: true)
                }
            }

            if let target = app.target {
                TrackingRow(target: target)
            }

            if app.overageSeconds > 0 {
                Text("You went \(Fmt.short(app.overageSeconds)) past the line today.")
                    .font(Typo.caption)
                    .foregroundStyle(Theme.danger)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, Space.md)
        .padding(.horizontal, Space.sm)
        .cardSurface(radius: Radius.xl, shadow: .lift)
    }

    // MARK: - Stats

    private func stats(_ app: TrackedApp) -> some View {
        HStack(spacing: Space.sm) {
            StatBubble(value: "\(app.openCount)", label: "opens",
                       symbol: "hand.tap.fill", tint: app.tint)
            StatBubble(value: Fmt.short(app.usedSeconds), label: "used",
                       symbol: "hourglass", tint: app.tint)
            StatBubble(value: Fmt.short(app.longestSession), label: "longest",
                       symbol: "timer", tint: app.tint)
            StatBubble(value: Fmt.short(app.totalSeconds), label: "allowance",
                       symbol: "target", tint: app.tint)
        }
    }

    // MARK: - Timeline chart

    /// Usage by hour. Deliberately a simple bar chart drawn by hand rather than
    /// Swift Charts — it has to match the sticker style, and it only ever plots
    /// 24 values.
    private func timeline(_ app: TrackedApp) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(eyebrow: "Today", title: "When you opened it",
                          symbol: "clock.badge.checkmark.fill")

            HourlyUsageChart(sessions: app.sessions, tint: app.tint)
                .frame(height: 132)
                .padding(.top, Space.xxs)

            HStack(spacing: 0) {
                ForEach(Array(["12a", "6a", "12p", "6p", "12a"].enumerated()), id: \.offset) { index, label in
                    if index > 0 { Spacer(minLength: 0) }
                    Text(label)
                        .font(Typo.micro)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .padding(Space.md)
        .cardSurface()
    }

    // MARK: - Sessions

    private func sessionList(_ app: TrackedApp) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(eyebrow: "Detail", title: "Every pickup", symbol: "list.bullet.rectangle.fill") {
                Chip(text: "\(app.sessions.count)", tint: app.tint)
            }

            if app.sessions.isEmpty {
                EmptyNote(symbol: "moon.stars.fill",
                          text: "Not opened yet today. Nice.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(app.sessions.enumerated().reversed()), id: \.element.id) { index, session in
                        SessionRow(session: session, tint: app.tint, index: index + 1)
                        if session.id != app.sessions.first?.id {
                            Divider().overlay(Theme.outlineSoft)
                        }
                    }
                }
                .padding(Space.sm)
                .cardSurface()
            }
        }
    }

    // MARK: - Actions

    private func actions(_ app: TrackedApp) -> some View {
        VStack(spacing: Space.sm) {
            JellyButton(title: "Adjust daily allowance", symbol: "slider.horizontal.3",
                        tint: app.tint, fullWidth: true) {
                showBudgetSheet = true
            }

            GhostButton(title: "Stop tracking this app", symbol: "minus.circle") {
                state.untrack(app.id)
                dismiss()
            }
        }
        .padding(.top, Space.xs)
    }
}

/// Hand-drawn 24-hour histogram in the house style.
struct HourlyUsageChart: View {
    var sessions: [UsageSession]
    var tint: AppTint

    /// Minutes used in each hour bucket. Sessions are attributed to their start
    /// hour — spreading across hours would be more accurate and much harder to
    /// read at this size.
    private var buckets: [Double] {
        var result = [Double](repeating: 0, count: 24)
        let calendar = Calendar.current
        for session in sessions {
            let hour = calendar.component(.hour, from: session.start)
            result[hour] += session.duration / 60
        }
        return result
    }

    var body: some View {
        let values = buckets
        let peak = max(values.max() ?? 1, 1)

        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<24, id: \.self) { hour in
                let value = values[hour]
                VStack(spacing: 3) {
                    if value > 0 {
                        Text("\(Int(value))")
                            .font(.system(size: 8, weight: .heavy, design: .rounded))
                            .foregroundStyle(tint.deep)
                    }
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(value > 0 ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(Theme.well))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(value > 0 ? Theme.outline : Theme.outlineSoft,
                                              lineWidth: value > 0 ? 1.5 : 1)
                        )
                        .frame(height: max(6, CGFloat(value / peak) * 92))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .animation(Motion.smooth, value: sessions.count)
    }
}

struct SessionRow: View {
    var session: UsageSession
    var tint: AppTint
    var index: Int

    var body: some View {
        HStack(spacing: Space.sm) {
            Text("\(index)")
                .font(Typo.caption.monospacedDigit())
                .foregroundStyle(tint.contrastInk)
                .frame(width: 24, height: 24)
                .background(Circle().fill(tint.gradient))
                .overlay(Circle().strokeBorder(Theme.outline, lineWidth: 1.5))

            VStack(alignment: .leading, spacing: 1) {
                Text("\(Fmt.time(session.start)) – \(Fmt.time(session.end))")
                    .font(Typo.body)
                    .foregroundStyle(Theme.textPrimary)
                Text(Fmt.relative(session.start))
                    .font(Typo.micro)
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer()

            Text(Fmt.short(session.duration))
                .font(Typo.body.monospacedDigit())
                .foregroundStyle(tint.deep)
        }
        .padding(.vertical, Space.xs)
    }
}

struct EmptyNote: View {
    var symbol: String
    var text: String

    var body: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(Theme.textTertiary)
            Text(text)
                .font(Typo.callout)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .padding(Space.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Theme.surfaceSunk)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(Theme.outlineSoft, style: .init(lineWidth: 2, dash: [6, 5]))
        )
    }
}

/// Allowance editor. A stepper in five-minute jumps — minute-level precision
/// is false accuracy for a number nobody can feel.
struct BudgetEditorSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let app: TrackedApp

    @State private var minutes: Double = 60

    var body: some View {
        VStack(spacing: Space.lg) {
            Capsule()
                .fill(Theme.outlineSoft)
                .frame(width: 44, height: 5)
                .padding(.top, Space.xs)

            AppGlyph(symbol: app.symbol, tint: app.tint, size: 64)

            VStack(spacing: Space.xxs) {
                Text("Daily allowance")
                    .eyebrow()
                    .foregroundStyle(Theme.textTertiary)
                Text(app.name)
                    .font(Typo.title)
                    .foregroundStyle(Theme.textPrimary)
            }

            Text(Fmt.short(minutes * 60))
                .font(Typo.timer(56))
                .foregroundStyle(app.tint.deep)

            HStack(spacing: Space.md) {
                IconButton(symbol: "minus", tint: app.tint) {
                    withAnimation(Motion.jelly) { minutes = max(5, minutes - 5) }
                }
                TimeBudgetBar(fraction: min(1, minutes / 240), tint: app.tint,
                              height: 20, showTicks: false)
                IconButton(symbol: "plus", tint: app.tint) {
                    withAnimation(Motion.jelly) { minutes = min(240, minutes + 5) }
                }
            }
            .padding(.horizontal, Space.md)

            Text("Tomorrow's bar starts at this length.")
                .font(Typo.caption)
                .foregroundStyle(Theme.textSecondary)

            Spacer()

            JellyButton(title: "Save", symbol: "checkmark", tint: app.tint,
                        size: .large, fullWidth: true) {
                state.setBudget(minutes: minutes, for: app.id)
                dismiss()
            }
            GhostButton(title: "Cancel") { dismiss() }
        }
        .padding(Space.gutter)
        .playgroundBackground(tints: [app.tint, .sky])
        .presentationDetents([.height(560)])
        .presentationBackground(.clear)
        .onAppear { minutes = app.budgetSeconds / 60 }
    }
}

// MARK: - Tracking row

/// Which real app or category this budget is attached to.
///
/// The names in this product are the person's own, so months later "Loopz" may
/// no longer say what it governs. Apple's `Label` is the only thing that can
/// answer that — the token stays opaque to us, iOS draws the name and icon
/// privately. It stays a footnote: the glyph and tint remain the app's identity
/// everywhere else, because the Lock Screen widget has no `FamilyControls`
/// entitlement and could never match a real icon.
///
/// `Equatable` is load-bearing, as in `BudgetSetupView`. `Label` is
/// UIKit-backed and detaches when re-rendered; this row sits inside a hero that
/// redraws on every usage tick, so it must not redraw with it.
private struct TrackingRow: View, Equatable {
    let target: TrackedTarget

    static func == (lhs: TrackingRow, rhs: TrackingRow) -> Bool {
        lhs.target == rhs.target
    }

    var body: some View {
        HStack(spacing: Space.xs) {
            Text("Tracking")
                .font(Typo.micro)
                .tracking(0.6)
                .foregroundStyle(Theme.textTertiary)

            switch target {
            case .application(let data):
                if let token = try? JSONDecoder().decode(ApplicationToken.self, from: data) {
                    Label(token)
                        .labelStyle(.titleAndIcon)
                        .font(Typo.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            case .category(let data):
                if let token = try? JSONDecoder().decode(ActivityCategoryToken.self, from: data) {
                    Label(token)
                        .labelStyle(.titleAndIcon)
                        .font(Typo.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                    Text("· whole category")
                        .font(Typo.micro)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .padding(.horizontal, Space.sm)
        .padding(.vertical, Space.xxs)
        .background(
            Capsule().fill(Theme.surfaceSunk)
        )
    }
}

#Preview("App detail") {
    NavigationStack {
        AppDetailView(appID: SampleData.apps[0].id)
            .environment(AppState.preview)
    }
}
