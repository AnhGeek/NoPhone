import SwiftUI

/// Celebration burst for a granted reward.
///
/// Drawn in a single `Canvas` with a `TimelineView` rather than N animated
/// views — one draw pass, no view-tree churn, and it stays smooth over a
/// blurred backdrop. Respects Reduce Motion by not emitting at all.
struct ConfettiBurst: View {
    var pieceCount: Int = 60
    var duration: Double = 2.2
    var tints: [AppTint] = AppTint.allCases

    @State private var start = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Piece {
        var x: Double, angle: Double, spin: Double
        var scale: Double, delay: Double, drift: Double
        var color: Color, isCircle: Bool
    }

    private var pieces: [Piece] {
        (0..<pieceCount).map { i in
            let seed = Double(i)
            // Deterministic scatter — no RNG, so previews and snapshots match.
            func noise(_ k: Double) -> Double {
                let v = sin(seed * k) * 43758.5453
                return v - v.rounded(.down)
            }
            return Piece(
                x: noise(12.9898),
                angle: noise(4.1414) * 360,
                spin: (noise(7.233) - 0.5) * 900,
                scale: 0.6 + noise(3.77) * 0.9,
                delay: noise(9.11) * 0.35,
                drift: (noise(5.55) - 0.5) * 160,
                color: tints[i % tints.count].base,
                isCircle: i % 3 == 0
            )
        }
    }

    var body: some View {
        if reduceMotion {
            EmptyView()
        } else {
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let elapsed = timeline.date.timeIntervalSince(start)
                    for piece in pieces {
                        let t = (elapsed - piece.delay) / duration
                        guard t > 0, t < 1 else { continue }

                        // Ballistic arc: fast rise, gravity-dominated fall.
                        let rise = -sin(t * .pi) * size.height * 0.55
                        let fall = t * t * size.height * 0.9
                        let x = size.width * piece.x + piece.drift * t
                        let y = size.height * 0.45 + rise + fall

                        let w = 10 * piece.scale
                        let h = (piece.isCircle ? 10 : 14) * piece.scale
                        let opacity = t > 0.75 ? (1 - t) * 4 : 1

                        var layer = context
                        layer.opacity = opacity
                        layer.translateBy(x: x, y: y)
                        layer.rotate(by: .degrees(piece.angle + piece.spin * t))

                        let rect = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
                        let path = piece.isCircle
                            ? Path(ellipseIn: rect)
                            : Path(roundedRect: rect, cornerRadius: 2)

                        layer.fill(path, with: .color(piece.color))
                        layer.stroke(path, with: .color(Palette.ink.opacity(0.55)), lineWidth: 1.2)
                    }
                }
            }
            .allowsHitTesting(false)
            .onAppear { start = .now }
        }
    }
}

/// Full-screen overlay shown when a quest pays out: dimmed backdrop, a big
/// bouncing token, and the burst behind it.
struct CelebrationOverlay: View {
    let celebration: Celebration
    var onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            ConfettiBurst(tints: [celebration.tint, .sunshine, .mint, .sky])

            VStack(spacing: Space.md) {
                ZStack {
                    Circle()
                        .fill(celebration.tint.gradient)
                        .frame(width: 116, height: 116)
                        .overlay(Circle().strokeBorder(Theme.outline, lineWidth: Stroke.thick))
                        .shadow(color: celebration.tint.base.opacity(0.6), radius: 24)

                    Image(systemName: celebration.symbol)
                        .font(.system(size: 48, weight: .black))
                        .foregroundStyle(celebration.tint.contrastInk)
                }
                .scaleEffect(appeared ? 1 : 0.4)
                .rotationEffect(.degrees(appeared ? 0 : -25))

                Text(celebration.title)
                    .font(Typo.title)
                    .foregroundStyle(.white)
                    .inkOutline(width: 2)

                Text(celebration.subtitle)
                    .font(Typo.callout)
                    .foregroundStyle(.white.opacity(0.9))

                if celebration.boosted {
                    CrownBadge(text: "Champion boost applied")
                }

                JellyButton(title: "Nice!", symbol: "hand.thumbsup.fill",
                            tint: celebration.tint, size: .large, action: onDismiss)
                    .padding(.top, Space.xs)
            }
            .padding(Space.xl)
            .scaleEffect(appeared ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear { withAnimation(Motion.bounce) { appeared = true } }
    }
}

#Preview("Celebration") {
    ZStack {
        Color.gray
        CelebrationOverlay(
            celebration: Celebration(title: "+20 minutes!",
                                     subtitle: "Added to Pixel Pals",
                                     symbol: "book.fill",
                                     tint: .tangerine,
                                     boosted: true),
            onDismiss: {}
        )
    }
}
