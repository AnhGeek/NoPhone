import SwiftUI

// MARK: - Confirm overlay

/// "Are you sure?", in this product's voice.
///
/// UIKit's `confirmationDialog` and `alert` are system chrome — translucent,
/// system font, system blue — and they land on this design like the stock tab
/// bar would. This is the same sticker vocabulary as everything else: a card
/// with the deep-indigo outline and offset shadow, a `JellyButton` for the act
/// and a `GhostButton` for the way out.
///
/// Presented as an overlay rather than a sheet so the spring can overshoot on
/// the way in; a sheet's own transition would fight it.
struct ConfirmOverlay: View {
    var title: String
    var message: String
    var symbol: String
    var confirmTitle: String
    var cancelTitle: String = "Never mind"
    /// The colour of the consequence, not of the app being acted on — red for
    /// destructive, so the card reads the same wherever it's used.
    var tint: AppTint = .cherry
    var onConfirm: () -> Void
    var onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            Palette.ink.opacity(0.42)
                .ignoresSafeArea()
                // Tapping out is the safe answer, always the cancel.
                .onTapGesture(perform: onCancel)

            VStack(spacing: Space.sm) {
                ZStack {
                    Circle()
                        .fill(tint.gradient)
                        .frame(width: 72, height: 72)
                        .overlay(Circle().strokeBorder(Theme.outline, lineWidth: Stroke.medium))
                        .background(Circle().fill(Theme.shadowHard).offset(y: 4))
                    Image(systemName: symbol)
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(tint.contrastInk)
                }
                .padding(.bottom, Space.xxs)

                Text(title)
                    .font(Typo.headline)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(Typo.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.xs)

                VStack(spacing: Space.xs) {
                    JellyButton(title: confirmTitle, symbol: "trash.fill",
                                tint: tint, fullWidth: true, action: onConfirm)
                    GhostButton(title: cancelTitle, action: onCancel)
                }
                .padding(.top, Space.xs)
            }
            .padding(Space.lg)
            .frame(maxWidth: 320)
            .cardSurface(radius: Radius.xl, shadow: .lift)
            .padding(.horizontal, Space.gutter)
            .scaleEffect(appeared ? 1 : 0.86)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            guard !reduceMotion else { appeared = true; return }
            withAnimation(Motion.bounce) { appeared = true }
        }
    }
}

#Preview("Confirm") {
    ZStack {
        Color.gray
        ConfirmOverlay(title: "Stop tracking Loopz?",
                       message: "Its budget, today's usage, and any earned time go away. The app stops being blocked.",
                       symbol: "trash.fill",
                       confirmTitle: "Stop tracking",
                       cancelTitle: "Keep it",
                       onConfirm: {}, onCancel: {})
    }
}
