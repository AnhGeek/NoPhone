import SwiftUI

// MARK: - Jelly button

/// The primary action control. A candy lozenge with a thick outline that
/// squashes into its own shadow when pressed.
struct JellyButton: View {
    var title: String
    var symbol: String?
    var tint: AppTint = .grape
    var size: Size = .regular
    var fullWidth: Bool = false
    var enabled: Bool = true
    var action: () -> Void

    enum Size {
        case small, regular, large

        var font: Font {
            switch self {
            case .small:   Typo.caption
            case .regular: Typo.body
            case .large:   Typo.headline
            }
        }
        var padding: (h: CGFloat, v: CGFloat) {
            switch self {
            case .small:   (Space.sm, Space.xs)
            case .regular: (Space.lg, Space.sm + 2)
            case .large:   (Space.xl, Space.md)
            }
        }
        var radius: CGFloat {
            switch self {
            case .small:   Radius.sm
            case .regular: Radius.md
            case .large:   Radius.lg
            }
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.xs) {
                if let symbol {
                    Image(systemName: symbol).font(size.font.weight(.black))
                }
                Text(title).font(size.font.weight(.heavy))
            }
            .foregroundStyle(enabled ? tint.contrastInk : Theme.textTertiary)
            .padding(.horizontal, size.padding.h)
            .padding(.vertical, size.padding.v)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: size.radius, style: .continuous)
                        .fill(enabled ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(Theme.surfaceSunk))
                    Gloss(radius: size.radius, intensity: enabled ? 0.5 : 0)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: size.radius, style: .continuous)
                    .strokeBorder(enabled ? Theme.outline : Theme.outlineSoft, lineWidth: Stroke.medium)
            )
            .background(
                RoundedRectangle(cornerRadius: size.radius, style: .continuous)
                    .fill(enabled ? Theme.shadowHard : .clear)
                    .offset(y: 5)
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .jellyPress()
    }
}

// MARK: - Ghost button

/// Secondary action: outline only, no fill. Used where two actions sit side by
/// side and only one should own the color.
struct GhostButton: View {
    var title: String
    var symbol: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.xs) {
                if let symbol { Image(systemName: symbol).font(Typo.body.weight(.black)) }
                Text(title).font(Typo.body.weight(.heavy))
            }
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.sm + 2)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .strokeBorder(Theme.outline, lineWidth: Stroke.medium)
            )
        }
        .buttonStyle(.plain)
        .jellyPress()
    }
}

// MARK: - Icon button

struct IconButton: View {
    var symbol: String
    var tint: AppTint = .sky
    var size: CGFloat = 44
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.4, weight: .black))
                .foregroundStyle(tint.contrastInk)
                .frame(width: size, height: size)
                .background(Circle().fill(tint.gradient))
                .overlay(Circle().fill(
                    LinearGradient(colors: [.white.opacity(0.5), .clear],
                                   startPoint: .top, endPoint: .center)
                ).padding(2))
                .overlay(Circle().strokeBorder(Theme.outline, lineWidth: Stroke.medium))
                .background(Circle().fill(Theme.shadowHard).offset(y: 4))
        }
        .buttonStyle(.plain)
        .jellyPress()
    }
}

// MARK: - Chips & badges

/// Small labelled pill. `solid` for emphasis, outline otherwise.
struct Chip: View {
    var text: String
    var symbol: String?
    var tint: AppTint = .sky
    var solid: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).font(Typo.micro.weight(.black)) }
            Text(text).font(Typo.micro)
        }
        .tracking(0.6)
        .foregroundStyle(solid ? tint.contrastInk : tint.deep)
        .padding(.horizontal, Space.xs + 2)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(solid ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(tint.base.opacity(0.16)))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(solid ? Theme.outline : tint.base.opacity(0.5),
                              lineWidth: solid ? Stroke.thin : 1.5)
        )
    }
}

/// The "+15 min" reward token. Deliberately the loudest small element in the
/// UI — it is the thing every quest is for.
struct RewardToken: View {
    var minutes: Int
    var tint: AppTint = .sunshine
    var boosted: Bool = false
    var size: CGFloat = 1

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: boosted ? "bolt.fill" : "clock.fill")
                .font(.system(size: 11 * size, weight: .black))
            Text("+\(minutes)")
                .font(.system(size: 15 * size, weight: .heavy, design: .rounded))
                .monospacedDigit()
            Text("min")
                .font(.system(size: 10 * size, weight: .heavy, design: .rounded))
                .opacity(0.85)
        }
        .foregroundStyle(tint.contrastInk)
        .padding(.horizontal, Space.xs + 2)
        .padding(.vertical, 5)
        .background(Capsule(style: .continuous).fill(tint.gradient))
        .overlay(Capsule(style: .continuous).fill(
            LinearGradient(colors: [.white.opacity(0.55), .clear],
                           startPoint: .top, endPoint: .center)
        ).padding(2))
        .overlay(Capsule(style: .continuous).strokeBorder(Theme.outline, lineWidth: 2))
        .overlay(alignment: .topTrailing) {
            if boosted {
                Image(systemName: "sparkle")
                    .font(.system(size: 10 * size, weight: .black))
                    .foregroundStyle(.white)
                    .offset(x: 3, y: -4)
            }
        }
    }
}

/// Premium marker used on locked quests and the profile header.
struct CrownBadge: View {
    var text: String = "Champion"

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "crown.fill").font(.system(size: 10, weight: .black))
            Text(text).font(Typo.micro).tracking(0.8)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Space.xs + 2)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(
                LinearGradient(colors: [Palette.sunshine, Palette.tangerine, Palette.bubblegum],
                               startPoint: .leading, endPoint: .trailing)
            )
        )
        .overlay(Capsule().strokeBorder(Theme.outline, lineWidth: 2))
        .shadow(color: Palette.tangerine.opacity(0.5), radius: 6, y: 2)
    }
}

// MARK: - Section header

/// Section header with an eyebrow, a title, and an optional trailing action.
/// Used on every scroll screen so vertical rhythm stays identical throughout.
struct SectionHeader<Trailing: View>: View {
    var eyebrow: String?
    var title: String
    var symbol: String?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                if let eyebrow {
                    Text(eyebrow)
                        .eyebrow()
                        .foregroundStyle(Theme.textTertiary)
                }
                HStack(spacing: Space.xs) {
                    if let symbol {
                        Image(systemName: symbol).font(Typo.headline.weight(.black))
                    }
                    Text(title).font(Typo.headline)
                }
                .foregroundStyle(Theme.textPrimary)
            }
            Spacer(minLength: Space.sm)
            trailing()
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(eyebrow: String? = nil, title: String, symbol: String? = nil) {
        self.init(eyebrow: eyebrow, title: title, symbol: symbol, trailing: { EmptyView() })
    }
}

#Preview("Controls") {
    ScrollView {
        VStack(spacing: Space.lg) {
            JellyButton(title: "Claim reward", symbol: "gift.fill", tint: .mint, size: .large) {}
            JellyButton(title: "Add time", symbol: "plus", tint: .sky, fullWidth: true) {}
            JellyButton(title: "Locked", symbol: "lock.fill", enabled: false) {}
            GhostButton(title: "Maybe later") {}
            HStack {
                IconButton(symbol: "bell.fill", tint: .tangerine) {}
                IconButton(symbol: "gearshape.fill", tint: .grape) {}
            }
            HStack {
                Chip(text: "Daily", symbol: "sun.max.fill", tint: .sunshine)
                Chip(text: "Social", tint: .sky, solid: true)
                CrownBadge()
            }
            HStack {
                RewardToken(minutes: 15)
                RewardToken(minutes: 40, tint: .grape, boosted: true)
            }
            SectionHeader(eyebrow: "Today", title: "Your apps", symbol: "square.grid.2x2.fill") {
                Chip(text: "6 apps", tint: .mint)
            }
        }
        .padding(Space.lg)
    }
    .background(Theme.canvas)
}
