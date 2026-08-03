import SwiftUI

/// The core object of the product: a day's allowance for one app, drawn as a
/// bar that starts **full** at midnight and drains as the app is used.
///
/// Design decisions worth keeping:
/// * The fill is anchored leading and shrinks. Draining left-to-right is the
///   only direction that reads as "spending" rather than "progress".
/// * Earned bonus time is drawn as a distinct sparkled segment at the trailing
///   edge, so a reward is visibly *extra* — it never silently merges into the
///   base allowance.
/// * Tick marks sit on the track, not the fill, giving a sense of scale
///   without competing with the candy gradient.
/// * At the critical threshold the cap glows and breathes. That is the only
///   ambient animation in the component, reserved for the one state that
///   warrants attention.
struct TimeBudgetBar: View {
    var fraction: Double
    var bonusFraction: Double = 0
    var tint: AppTint
    var height: CGFloat = 22
    var showTicks: Bool = true
    var showCap: Bool = true
    /// Animate on appear — off inside widgets, which get one static render.
    var animated: Bool = true

    @State private var revealed: Double = 0
    @State private var breathing = false

    private var clamped: Double { min(1, max(0, fraction)) }
    private var isCritical: Bool { clamped > 0 && clamped <= 0.15 }
    private var isEmpty: Bool { clamped <= 0.001 }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let fillWidth = max(isEmpty ? 0 : height, width * revealed)
            let bonusWidth = min(fillWidth, width * min(bonusFraction, revealed))

            ZStack(alignment: .leading) {
                track

                if !isEmpty {
                    fill(width: fillWidth, bonusWidth: bonusWidth, height: height)
                        .frame(width: fillWidth, height: height)
                }

                if showTicks { ticks(width: width) }

                if showCap && !isEmpty {
                    cap
                        .offset(x: fillWidth - height * 0.72)
                }
            }
            .frame(height: height)
        }
        .frame(height: height)
        .onAppear {
            guard animated else { revealed = clamped; return }
            withAnimation(Motion.smooth.delay(0.05)) { revealed = clamped }
            if isCritical { withAnimation(Motion.pulse) { breathing = true } }
        }
        .onChange(of: fraction) { _, newValue in
            withAnimation(animated ? Motion.smooth : nil) {
                revealed = min(1, max(0, newValue))
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Time remaining")
        .accessibilityValue("\(Int(clamped * 100)) percent")
    }

    // MARK: - Pieces

    private var track: some View {
        Capsule(style: .continuous)
            .fill(Theme.well)
            .overlay(
                // Inner shade at the top sells the trough as recessed — the
                // inverse of the gloss used on raised surfaces.
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.outline.opacity(0.18), .clear],
                            startPoint: .top, endPoint: .center
                        )
                    )
            )
            .overlay(Capsule(style: .continuous).strokeBorder(Theme.outline, lineWidth: Stroke.thin))
            .frame(height: height)
    }

    private func fill(width: CGFloat, bonusWidth: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .trailing) {
            Capsule(style: .continuous)
                .fill(tint.gradient)

            if bonusWidth > height * 0.5 {
                // Bonus segment: brighter, sparkled, and clipped back into the
                // capsule so it keeps the rounded trailing end.
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(colors: [tint.light, .white.opacity(0.85)],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .overlay(SparkleField(count: 5, tint: tint.deep))
                    .frame(width: bonusWidth)
                    .clipShape(Capsule(style: .continuous))
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Theme.outline.opacity(0.55))
                            .frame(width: Stroke.thin)
                    }
            }
        }
        .glossy(radius: height / 2, intensity: 0.55)
        .overlay(Capsule(style: .continuous).strokeBorder(Theme.outline, lineWidth: Stroke.thin))
        .clipShape(Capsule(style: .continuous))
        .shadow(color: tint.base.opacity(isCritical ? 0.6 : 0.3),
                radius: isCritical && breathing ? 10 : 4, y: 1)
    }

    /// Quarter-day marks. Subtle by design: they are a ruler, not a feature.
    private func ticks(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(1..<4, id: \.self) { _ in
                Spacer()
                Rectangle()
                    .fill(Theme.outline.opacity(0.16))
                    .frame(width: 1.5, height: height * 0.42)
            }
            Spacer()
        }
        .frame(width: width)
        .allowsHitTesting(false)
    }

    /// The rounded knob at the leading edge of the empty space — a physical
    /// "here's where you are now" marker.
    private var cap: some View {
        Circle()
            .fill(.white)
            .overlay(Circle().fill(tint.light).padding(3))
            .overlay(Circle().strokeBorder(Theme.outline, lineWidth: Stroke.thin))
            .frame(width: height * 0.72, height: height * 0.72)
            .scaleEffect(isCritical && breathing ? 1.18 : 1)
            .shadow(color: Theme.outline.opacity(0.35), radius: 2, y: 1)
    }
}

/// Tiny drifting sparkles used inside bonus segments and reward chips.
struct SparkleField: View {
    var count: Int = 6
    var tint: Color = .white
    @State private var phase = false

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<count, id: \.self) { i in
                let seed = Double(i)
                Image(systemName: "sparkle")
                    .font(.system(size: 6 + (seed.truncatingRemainder(dividingBy: 3)) * 2,
                                  weight: .black))
                    .foregroundStyle(tint.opacity(0.75))
                    .position(
                        x: geo.size.width * ((seed * 0.37).truncatingRemainder(dividingBy: 1)),
                        y: geo.size.height * (phase
                            ? (seed * 0.61).truncatingRemainder(dividingBy: 1)
                            : (seed * 0.23).truncatingRemainder(dividingBy: 1))
                    )
                    .animation(
                        .easeInOut(duration: 2.2 + seed * 0.3).repeatForever(autoreverses: true),
                        value: phase
                    )
            }
        }
        .onAppear { phase = true }
        .allowsHitTesting(false)
    }
}

// MARK: - Segmented variant

/// Chunkier alternative used on the lock screen's "Blocks" style, where a
/// smooth gradient loses legibility at a glance. Each pip is roughly 10% of
/// the day.
struct SegmentedBudgetBar: View {
    var fraction: Double
    var tint: AppTint
    var segments: Int = 10
    var height: CGFloat = 14

    private var litCount: Int {
        Int((min(1, max(0, fraction)) * Double(segments)).rounded(.up))
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<segments, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(index < litCount
                          ? AnyShapeStyle(tint.gradient)
                          : AnyShapeStyle(Theme.well))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(Theme.outline.opacity(index < litCount ? 1 : 0.35),
                                          lineWidth: 1.5)
                    )
            }
        }
        .frame(height: height)
        .animation(Motion.smooth, value: litCount)
    }
}

#Preview("Budget bars") {
    VStack(spacing: Space.lg) {
        TimeBudgetBar(fraction: 0.82, bonusFraction: 0.2, tint: .mint)
        TimeBudgetBar(fraction: 0.45, tint: .sky)
        TimeBudgetBar(fraction: 0.12, tint: .tangerine)
        TimeBudgetBar(fraction: 0, tint: .cherry)
        SegmentedBudgetBar(fraction: 0.6, tint: .grape)
    }
    .padding(Space.lg)
    .background(Theme.canvas)
}
