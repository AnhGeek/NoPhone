import SwiftUI

/// Ambient background: soft candy blobs drifting behind the content.
///
/// Heavily blurred and low opacity — the job is to keep large empty areas from
/// feeling like a spreadsheet, without ever competing with a card. Motion is
/// slow enough (4–7s cycles) to register as atmosphere rather than animation.
struct BlobBackground: View {
    var tints: [AppTint] = [.grape, .bubblegum, .sky, .sunshine]
    var intensity: Double = 0.5
    @State private var drift = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(Array(tints.enumerated()), id: \.offset) { index, tint in
                    let seed = Double(index)
                    Blob(points: 6 + index % 3)
                        .fill(tint.base.opacity(intensity * 0.45))
                        .frame(width: geo.size.width * (0.55 + seed * 0.08),
                               height: geo.size.width * (0.55 + seed * 0.08))
                        .blur(radius: 42)
                        .offset(
                            x: geo.size.width * (index.isMultiple(of: 2) ? -0.28 : 0.32),
                            y: geo.size.height * (0.12 + seed * 0.22)
                                + (drift ? 18 : -18) * (index.isMultiple(of: 2) ? 1 : -1)
                        )
                        .animation(
                            reduceMotion ? nil
                                : .easeInOut(duration: 5 + seed).repeatForever(autoreverses: true),
                            value: drift
                        )
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear { drift = true }
    }
}

/// An organic rounded polygon — the cartoon "splat" shape used for blobs and
/// for the mascot's cheeks.
struct Blob: Shape {
    var points: Int = 6
    var wobble: Double = 0.18

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()

        var vertices: [CGPoint] = []
        for i in 0..<points {
            let angle = Double(i) / Double(points) * 2 * .pi
            // Deterministic pseudo-noise: same shape every render, no RNG.
            let noise = 1 + wobble * sin(Double(i) * 2.3) * cos(Double(i) * 1.7)
            vertices.append(
                CGPoint(x: center.x + cos(angle) * radius * noise,
                        y: center.y + sin(angle) * radius * noise)
            )
        }

        guard vertices.count > 2 else { return path }

        // Midpoint-quadratic smoothing turns the polygon into a soft blob.
        path.move(to: midpoint(vertices[vertices.count - 1], vertices[0]))
        for i in 0..<vertices.count {
            let next = vertices[(i + 1) % vertices.count]
            path.addQuadCurve(to: midpoint(vertices[i], next), control: vertices[i])
        }
        path.closeSubpath()
        return path
    }

    private func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }
}

/// Faint dotted paper texture. Keeps the big cream canvas from reading as flat
/// white on OLED screens.
struct DottyPaper: View {
    var spacing: CGFloat = 22
    var dot: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            let columns = Int(geo.size.width / spacing) + 1
            let rows = Int(geo.size.height / spacing) + 1
            Canvas { context, _ in
                for row in 0...rows {
                    for column in 0...columns {
                        let rect = CGRect(
                            x: CGFloat(column) * spacing,
                            y: CGFloat(row) * spacing,
                            width: dot, height: dot
                        )
                        context.fill(Path(ellipseIn: rect),
                                     with: .color(Theme.textTertiary.opacity(0.18)))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Standard screen background: wash + blobs + texture, in one modifier so no
/// screen assembles its own.
struct PlaygroundBackground: ViewModifier {
    var tints: [AppTint] = [.grape, .bubblegum, .sky, .sunshine]
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    Theme.canvasWash(for: scheme)
                    BlobBackground(tints: tints, intensity: scheme == .dark ? 0.7 : 0.42)
                    DottyPaper()
                }
                .ignoresSafeArea()
            }
    }
}

extension View {
    func playgroundBackground(tints: [AppTint] = [.grape, .bubblegum, .sky, .sunshine]) -> some View {
        modifier(PlaygroundBackground(tints: tints))
    }
}
