import SwiftUI

/// The hero dial: how much of the whole day is left.
///
/// Two rings drawn concentrically — a recessed track and a candy fill with a
/// rounded cap and a soft outer glow. The center is a slot for content
/// (countdown, mascot, app glyph) rather than fixed text, so the same ring
/// serves the home screen and the app detail header.
struct BudgetRing<Center: View>: View {
    var fraction: Double
    var tint: AppTint
    var lineWidth: CGFloat = 22
    var animated: Bool = true
    /// Small pips around the dial, one per hour of allowance.
    var tickCount: Int = 12
    @ViewBuilder var center: () -> Center

    @State private var revealed: Double = 0
    @State private var shimmer = false

    private var clamped: Double { min(1, max(0, fraction)) }

    var body: some View {
        ZStack {
            ticks

            Circle()
                .stroke(Theme.well, style: .init(lineWidth: lineWidth, lineCap: .round))
                .overlay(
                    Circle()
                        .stroke(Theme.outline.opacity(0.9), lineWidth: Stroke.thin)
                        .padding(lineWidth / 2)
                )
                .overlay(
                    Circle()
                        .stroke(Theme.outline.opacity(0.9), lineWidth: Stroke.thin)
                        .padding(-lineWidth / 2)
                )

            Circle()
                .trim(from: 0, to: revealed)
                .stroke(
                    AngularGradient(
                        colors: [tint.light, tint.base, tint.deep, tint.light],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: .init(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.base.opacity(0.45), radius: shimmer ? 16 : 8)

            // Ink edging on the fill only, drawn as a thinner trimmed pair so
            // the arc keeps the hand-drawn outline without doubling the glow.
            Circle()
                .trim(from: 0, to: revealed)
                .stroke(Theme.outline.opacity(0.85),
                        style: .init(lineWidth: Stroke.thin, lineCap: .round))
                .padding(lineWidth / 2)
                .rotationEffect(.degrees(-90))

            center()
                .padding(lineWidth + Space.md)
        }
        .onAppear {
            guard animated else { revealed = clamped; return }
            withAnimation(Motion.smooth.delay(0.1)) { revealed = clamped }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
        .onChange(of: fraction) { _, newValue in
            withAnimation(animated ? Motion.smooth : nil) { revealed = min(1, max(0, newValue)) }
        }
        .accessibilityElement(children: .combine)
    }

    private var ticks: some View {
        GeometryReader { geo in
            let radius = min(geo.size.width, geo.size.height) / 2
            ForEach(0..<tickCount, id: \.self) { index in
                let angle = Double(index) / Double(tickCount) * 2 * .pi - .pi / 2
                Circle()
                    .fill(Theme.textTertiary.opacity(0.5))
                    .frame(width: 4, height: 4)
                    .position(
                        x: geo.size.width / 2 + cos(angle) * (radius + lineWidth * 0.85),
                        y: geo.size.height / 2 + sin(angle) * (radius + lineWidth * 0.85)
                    )
            }
        }
    }
}

extension BudgetRing where Center == EmptyView {
    init(fraction: Double, tint: AppTint, lineWidth: CGFloat = 22, animated: Bool = true) {
        self.init(fraction: fraction, tint: tint, lineWidth: lineWidth,
                  animated: animated, center: { EmptyView() })
    }
}

/// Compact ring used in list rows and the lock screen's "Dials" style.
struct MiniRing: View {
    var fraction: Double
    var tint: AppTint
    var symbol: String
    var size: CGFloat = 46
    var lineWidth: CGFloat = 6
    var animated: Bool = true

    var body: some View {
        ZStack {
            Circle().fill(Theme.surfaceSunk)
            Circle()
                .stroke(Theme.well, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(1, max(0, fraction)))
                .stroke(tint.gradient, style: .init(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(animated ? Motion.smooth : nil, value: fraction)
            Image(systemName: symbol)
                .font(.system(size: size * 0.34, weight: .bold))
                .foregroundStyle(tint.base)
        }
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(Theme.outline, lineWidth: Stroke.thin))
    }
}

#Preview("Rings") {
    VStack(spacing: Space.xl) {
        BudgetRing(fraction: 0.62, tint: .grape) {
            VStack(spacing: 2) {
                Text("2:14").font(Typo.timer(46))
                Text("hours left").font(Typo.caption).foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(width: 220, height: 220)

        HStack(spacing: Space.md) {
            MiniRing(fraction: 0.8, tint: .mint, symbol: "bird.fill")
            MiniRing(fraction: 0.35, tint: .tangerine, symbol: "gamecontroller.fill")
            MiniRing(fraction: 0.05, tint: .cherry, symbol: "play.rectangle.fill")
        }
    }
    .padding(Space.xl)
    .background(Theme.canvas)
}
