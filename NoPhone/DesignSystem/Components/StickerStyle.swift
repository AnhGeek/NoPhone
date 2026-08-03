import SwiftUI

// MARK: - Sticker surface

/// The one modifier that defines the product's look: a rounded fill, a chunky
/// ink outline, and an opaque offset shadow so the element reads as a die-cut
/// sticker resting on the page.
struct StickerSurface: ViewModifier {
    var fill: AnyShapeStyle
    var radius: CGFloat = Radius.md
    var stroke: CGFloat = Stroke.medium
    var strokeColor: Color = Theme.outline
    var shadow: StickerShadow = .card
    var shadowColor: Color = Theme.shadowHard

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(strokeColor, lineWidth: stroke)
            )
            .background(
                // Drawn behind the fill so the offset copy peeks out as a solid
                // edge rather than bleeding through a translucent surface.
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(shadowColor)
                    .offset(x: shadow.offset.width, y: shadow.offset.height)
                    .blur(radius: shadow.blur)
            )
            .clipShape(
                // Generous room for the offset copy; nothing else extends past
                // the outline, so this only ever trims stray blur.
                RoundedRectangle(cornerRadius: radius + 16, style: .continuous)
                    .inset(by: -40)
            )
    }
}

extension View {
    /// Sticker surface with a solid color fill.
    func sticker(_ color: Color,
                 radius: CGFloat = Radius.md,
                 stroke: CGFloat = Stroke.medium,
                 shadow: StickerShadow = .card) -> some View {
        modifier(StickerSurface(fill: AnyShapeStyle(color),
                                radius: radius, stroke: stroke, shadow: shadow))
    }

    /// Sticker surface with a gradient (or any shape style) fill.
    func sticker<S: ShapeStyle>(_ style: S,
                                radius: CGFloat = Radius.md,
                                stroke: CGFloat = Stroke.medium,
                                shadow: StickerShadow = .card) -> some View {
        modifier(StickerSurface(fill: AnyShapeStyle(style),
                                radius: radius, stroke: stroke, shadow: shadow))
    }

    /// The standard content card: surface fill, medium outline, card shadow.
    func cardSurface(radius: CGFloat = Radius.lg,
                     shadow: StickerShadow = .card) -> some View {
        modifier(StickerSurface(fill: AnyShapeStyle(Theme.surface),
                                radius: radius, stroke: Stroke.medium, shadow: shadow))
    }
}

// MARK: - Gloss

/// The specular sheen across the top of candy surfaces. Cheap, and it does
/// more for the "gummy" read than any amount of gradient tuning.
struct Gloss: View {
    var radius: CGFloat = Radius.md
    var intensity: Double = 0.45
    var inset: CGFloat = 3

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(intensity), location: 0),
                        .init(color: .white.opacity(intensity * 0.25), location: 0.38),
                        .init(color: .clear, location: 0.62)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .padding(inset)
            .allowsHitTesting(false)
    }
}

extension View {
    func glossy(radius: CGFloat = Radius.md, intensity: Double = 0.45) -> some View {
        overlay(Gloss(radius: radius, intensity: intensity))
    }
}

// MARK: - Jelly press

/// Press feedback: squash toward the shadow, so the sticker looks pressed flat
/// against the page instead of merely scaled.
struct JellyPress: ViewModifier {
    var scale: CGFloat = 0.94
    var sink: CGFloat = 3
    @GestureState private var pressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(pressed ? scale : 1, anchor: .center)
            .offset(y: pressed ? sink : 0)
            .animation(Motion.jelly, value: pressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($pressed) { _, state, _ in state = true }
            )
    }
}

extension View {
    func jellyPress(scale: CGFloat = 0.94, sink: CGFloat = 3) -> some View {
        modifier(JellyPress(scale: scale, sink: sink))
    }
}

// MARK: - Outlined text

/// Cartoon lettering: an ink halo behind the glyphs so headline numerals stay
/// legible on top of saturated fills and photo wallpapers.
struct OutlinedText: ViewModifier {
    var color: Color = Theme.outline
    var width: CGFloat = 1.6

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    ForEach(0..<8, id: \.self) { i in
                        let angle = Double(i) / 8 * 2 * .pi
                        content
                            .foregroundStyle(color)
                            .offset(x: cos(angle) * width, y: sin(angle) * width)
                    }
                }
            )
    }
}

extension View {
    func inkOutline(_ color: Color = Theme.outline, width: CGFloat = 1.6) -> some View {
        modifier(OutlinedText(color: color, width: width))
    }
}
