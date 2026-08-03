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
struct MascotSpeech: View {
    var mood: Mascot.Mood
    var tint: AppTint = .grape
    var text: String?
    var size: CGFloat = 96

    var body: some View {
        HStack(alignment: .center, spacing: Space.sm) {
            Mascot(mood: mood, tint: tint, size: size)

            Text(text ?? mood.line)
                .font(Typo.callout.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Space.sm)
                .padding(.vertical, Space.xs + 2)
                .background(
                    SpeechBubble()
                        .fill(Theme.surface)
                        .overlay(SpeechBubble().stroke(Theme.outline, lineWidth: Stroke.thin))
                )
        }
    }
}

/// Rounded rect with a little tail pointing left toward the mascot.
struct SpeechBubble: Shape {
    var tail: CGFloat = 8

    func path(in rect: CGRect) -> Path {
        let bodyRect = CGRect(x: rect.minX + tail, y: rect.minY,
                              width: rect.width - tail, height: rect.height)
        var path = Path(roundedRect: bodyRect, cornerRadius: Radius.sm, style: .continuous)
        let midY = rect.midY
        path.move(to: CGPoint(x: rect.minX, y: midY))
        path.addLine(to: CGPoint(x: rect.minX + tail + 1, y: midY - tail))
        path.addLine(to: CGPoint(x: rect.minX + tail + 1, y: midY + tail))
        path.closeSubpath()
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
