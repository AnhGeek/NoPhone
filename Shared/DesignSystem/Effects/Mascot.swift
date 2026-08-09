import SwiftUI

/// Bloop — the app's mascot, drawn entirely from SwiftUI shapes so it scales
/// cleanly from a 28pt list avatar to a 200pt hero with no assets.
///
/// Bloop's expression tracks the day's budget: cheerful when there's plenty
/// left, sleepy when it's gone. This is the app's emotional register — a
/// character reacting is friendlier than a red number, and it keeps the tone
/// encouraging rather than punitive.
struct Mascot: View {
    var mood: Mood
    var tint: AppTint = .grape
    var size: CGFloat = 120
    var animated: Bool = true

    @State private var bob = false
    @State private var blink = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Mood {
        case happy, chill, worried, sleepy, celebrating

        init(status: BudgetStatus) {
            switch status {
            case .healthy:  self = .happy
            case .low:      self = .chill
            case .critical: self = .worried
            case .spent:    self = .sleepy
            }
        }

        var line: String {
            switch self {
            case .happy:       "Loads of time left!"
            case .chill:       "Pacing nicely."
            case .worried:     "Getting thin — go earn some?"
            case .sleepy:      "That's a wrap for today."
            case .celebrating: "Woohoo! More time!"
            }
        }
    }

    var body: some View {
        ZStack {
            body_
            face
        }
        .frame(width: size, height: size)
        .offset(y: bob ? -4 : 4)
        .onAppear {
            guard animated, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { bob = true }
            withAnimation(.easeInOut(duration: 0.12).repeatForever(autoreverses: true).delay(2.6)) {
                blink = true
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Bloop says: \(mood.line)")
    }

    // MARK: - Body

    private var body_: some View {
        ZStack {
            // Squash-and-stretch: a slightly wider silhouette when celebrating.
            Blob(points: 8, wobble: 0.09)
                .fill(tint.gradient)
                .overlay(Blob(points: 8, wobble: 0.09).fill(
                    LinearGradient(colors: [.white.opacity(0.45), .clear],
                                   startPoint: .top, endPoint: .center)
                ))
                .overlay(Blob(points: 8, wobble: 0.09).stroke(Theme.outline, lineWidth: size * 0.035))
                .scaleEffect(x: mood == .celebrating ? 1.06 : 1,
                             y: mood == .celebrating ? 0.96 : 1)

            // Antenna — the one asymmetric detail that makes the blob a creature.
            antenna
        }
    }

    private var antenna: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(mood == .sleepy ? Theme.textTertiary : Palette.sunshine)
                    .frame(width: size * 0.14, height: size * 0.14)
                    .overlay(Circle().strokeBorder(Theme.outline, lineWidth: size * 0.028))
                    .shadow(color: Palette.sunshine.opacity(mood == .sleepy ? 0 : 0.8),
                            radius: size * 0.08)
            }
            Rectangle()
                .fill(Theme.outline)
                .frame(width: size * 0.03, height: size * 0.14)
        }
        .rotationEffect(.degrees(bob ? 6 : -6), anchor: .bottom)
        .offset(y: -size * 0.46)
    }

    // MARK: - Face

    private var face: some View {
        VStack(spacing: size * 0.06) {
            HStack(spacing: size * 0.18) {
                eye
                eye
            }
            mouth
        }
        .offset(y: size * 0.04)
    }

    private var eye: some View {
        Group {
            switch mood {
            case .sleepy:
                // Closed, contented arcs.
                Arc(start: .degrees(200), end: .degrees(340))
                    .stroke(Theme.outline, style: .init(lineWidth: size * 0.045, lineCap: .round))
                    .frame(width: size * 0.16, height: size * 0.16)
            case .celebrating:
                Image(systemName: "star.fill")
                    .font(.system(size: size * 0.16, weight: .black))
                    .foregroundStyle(Theme.outline)
            default:
                ZStack(alignment: .topTrailing) {
                    Capsule()
                        .fill(Theme.outline)
                        .frame(width: size * 0.11,
                               height: size * (blink ? 0.02 : 0.15))
                    Circle()
                        .fill(.white)
                        .frame(width: size * 0.04, height: size * 0.04)
                        .offset(x: size * 0.005, y: size * 0.025)
                        .opacity(blink ? 0 : 1)
                }
                .frame(height: size * 0.16)
            }
        }
    }

    private var mouth: some View {
        Group {
            switch mood {
            case .happy, .celebrating:
                Arc(start: .degrees(20), end: .degrees(160))
                    .stroke(Theme.outline, style: .init(lineWidth: size * 0.045, lineCap: .round))
                    .frame(width: size * 0.30, height: size * 0.20)
            case .chill:
                Capsule()
                    .fill(Theme.outline)
                    .frame(width: size * 0.18, height: size * 0.045)
            case .worried:
                Arc(start: .degrees(200), end: .degrees(340))
                    .stroke(Theme.outline, style: .init(lineWidth: size * 0.045, lineCap: .round))
                    .frame(width: size * 0.24, height: size * 0.16)
            case .sleepy:
                ZStack {
                    Circle()
                        .fill(Theme.outline)
                        .frame(width: size * 0.10, height: size * 0.10)
                    Text("z")
                        .font(.system(size: size * 0.13, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.outline)
                        .offset(x: size * 0.16, y: -size * 0.06)
                }
            }
        }
    }
}

/// Open arc used for eyes and mouths.
struct Arc: Shape {
    var start: Angle
    var end: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: min(rect.width, rect.height) / 2,
            startAngle: start,
            endAngle: end,
            clockwise: false
        )
        return path
    }
}

/// Mascot plus a speech bubble — the greeting block on the home screen.
///
/// Comic-panel treatment: chunky ink outline, a hard offset shadow so the
/// balloon reads as cut paper laid on the page, and a halftone dot field
/// behind the mascot standing in for a printed panel.
struct MascotSpeech: View {
    var mood: Mascot.Mood
    var tint: AppTint = .grape
    var text: String?
    var size: CGFloat = 96

    /// Tail width, scaled off the balloon's type so it stays proportional.
    private let tail: CGFloat = 12

    var body: some View {
        HStack(alignment: .center, spacing: Space.xs) {
            Mascot(mood: mood, tint: tint, size: size)
                // Bloop's idle bob and antenna both overrun the nominal frame;
                // the inset keeps them off the balloon and the card edge.
                .padding(Space.xxs)
                .background(
                    Halftone(dot: 2.2, spacing: 8)
                        .fill(tint.base.opacity(0.35))
                        .frame(width: size * 1.05, height: size * 1.05)
                        .clipShape(Circle())
                        .offset(x: size * 0.06, y: size * 0.08)
                )

            Text(text ?? mood.line)
                .font(Typo.callout.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                // The tail eats into the shape's leading edge, so the text
                // inset has to clear it or the first glyph sits on the point.
                .padding(.leading, tail + Space.md)
                .padding(.trailing, Space.md)
                .padding(.vertical, Space.sm)
                .background(
                    ZStack {
                        // The sticker shadow is its own filled silhouette, not a
                        // `.shadow` on the stroked shape — blurring a stroke
                        // offsets both of its edges and prints a second contour
                        // inside the balloon. Straight down, so the left-pointing
                        // tail doesn't cast a visible twin beside itself.
                        SpeechBubble(tail: tail)
                            .fill(Theme.textTertiary.opacity(0.5))
                            .offset(y: StickerShadow.card.offset.height)

                        SpeechBubble(tail: tail)
                            .fill(Theme.surface)
                            .overlay(
                                SpeechBubble(tail: tail)
                                    .stroke(Theme.outline,
                                            style: .init(lineWidth: Stroke.medium,
                                                         lineJoin: .round))
                            )
                    }
                )
        }
    }
}

/// Rounded rect with a little tail pointing left toward the mascot.
///
/// The tail is unioned into the body outline (rather than drawn as a separate
/// triangle) so the ink stroke runs around the whole balloon in one unbroken
/// comic line, with no seam where the point meets the body.
struct SpeechBubble: Shape {
    var tail: CGFloat = 12

    func path(in rect: CGRect) -> Path {
        let bodyRect = CGRect(x: rect.minX + tail, y: rect.minY,
                              width: rect.width - tail, height: rect.height)
        let r = min(Radius.sm, bodyRect.height / 2)
        let x0 = bodyRect.minX, x1 = bodyRect.maxX
        let y0 = bodyRect.minY, y1 = bodyRect.maxY
        // Tail sits just below centre — a hair off-axis reads hand-inked.
        let tipY = rect.midY + tail * 0.15
        let baseTop = min(tipY - tail * 0.55, y1 - r)
        let baseBottom = min(tipY + tail * 0.85, y1 - r)

        var path = Path()
        path.move(to: CGPoint(x: x0 + r, y: y0))
        path.addLine(to: CGPoint(x: x1 - r, y: y0))
        path.addQuadCurve(to: CGPoint(x: x1, y: y0 + r), control: CGPoint(x: x1, y: y0))
        path.addLine(to: CGPoint(x: x1, y: y1 - r))
        path.addQuadCurve(to: CGPoint(x: x1 - r, y: y1), control: CGPoint(x: x1, y: y1))
        path.addLine(to: CGPoint(x: x0 + r, y: y1))
        path.addQuadCurve(to: CGPoint(x: x0, y: y1 - r), control: CGPoint(x: x0, y: y1))
        path.addLine(to: CGPoint(x: x0, y: baseBottom))
        path.addLine(to: CGPoint(x: rect.minX, y: tipY))
        path.addLine(to: CGPoint(x: x0, y: baseTop))
        path.addLine(to: CGPoint(x: x0, y: y0 + r))
        path.addQuadCurve(to: CGPoint(x: x0 + r, y: y0), control: CGPoint(x: x0, y: y0))
        path.closeSubpath()
        return path
    }
}

/// Printed-comic halftone: a grid of dots used as a cheap "this is inked and
/// screened" cue behind the mascot.
struct Halftone: Shape {
    var dot: CGFloat = 2.2
    var spacing: CGFloat = 8

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var y = rect.minY + spacing / 2
        var row = 0
        while y < rect.maxY {
            // Offset every other row so the field reads as a screen, not a grid.
            var x = rect.minX + spacing / 2 + (row.isMultiple(of: 2) ? 0 : spacing / 2)
            while x < rect.maxX {
                path.addEllipse(in: CGRect(x: x - dot / 2, y: y - dot / 2,
                                           width: dot, height: dot))
                x += spacing
            }
            y += spacing
            row += 1
        }
        return path
    }
}

#Preview("Bloop") {
    VStack(spacing: Space.lg) {
        HStack(spacing: Space.md) {
            Mascot(mood: .happy, tint: .mint, size: 90)
            Mascot(mood: .chill, tint: .sky, size: 90)
            Mascot(mood: .worried, tint: .tangerine, size: 90)
        }
        HStack(spacing: Space.md) {
            Mascot(mood: .sleepy, tint: .grape, size: 90)
            Mascot(mood: .celebrating, tint: .bubblegum, size: 90)
        }
        MascotSpeech(mood: .happy, tint: .mint, text: "You've got 3h 20m left today. Go wild.")
    }
    .padding(Space.xl)
    .playgroundBackground()
}
