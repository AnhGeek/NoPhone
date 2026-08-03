import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Semantic color tokens.
///
/// Views name *roles* (`Theme.surface`, `Theme.textPrimary`) rather than hues,
/// so light/dark and any future themes resolve in one place. Every token is
/// dynamic — resolved by the system per trait collection — which means widgets,
/// snapshots and previews all pick up the right variant for free.
enum Theme {

    // MARK: - Backgrounds

    /// The page itself. A warm paper cream by day, deep grape by night.
    static let canvas       = adaptive(light: Palette.paper,      dark: Palette.nightBase)
    /// Cards and sheets sitting on the canvas.
    static let surface      = adaptive(light: .white,             dark: Palette.nightRaised)
    /// Secondary fills: track backgrounds, inset rows, disabled chips.
    static let surfaceSunk  = adaptive(light: Palette.paperTint,  dark: Palette.nightHigh)
    /// The deepest recess — progress-bar troughs, input wells.
    static let well         = adaptive(light: Palette.paperDeep,  dark: Color(hex: 0x140E2C))

    // MARK: - Ink

    static let textPrimary   = adaptive(light: Palette.ink,      dark: Palette.nightInk)
    static let textSecondary = adaptive(light: Palette.inkSoft,  dark: Palette.nightSoft)
    static let textTertiary  = adaptive(light: Palette.inkFaint, dark: Palette.nightFaint)
    /// Text that sits on top of a saturated candy fill.
    static let textOnColor   = Color.white

    // MARK: - Structure

    /// The signature chunky cartoon outline.
    static let outline       = adaptive(light: Palette.ink, dark: Color(hex: 0x0D0824))
    /// A softer outline for nested elements that would otherwise look heavy.
    static let outlineSoft   = adaptive(light: Palette.ink.opacity(0.16),
                                        dark:  Color.white.opacity(0.14))
    /// Hard offset shadow beneath cards — the "sticker peeling off the page".
    static let shadowHard    = adaptive(light: Palette.ink.opacity(0.90),
                                        dark:  Color.black.opacity(0.75))

    // MARK: - Status

    static let good     = Palette.mint
    static let caution  = Palette.sunshine
    static let warning  = Palette.tangerine
    static let danger   = Palette.cherry
    static let premium  = Palette.grape

    // MARK: - Brand

    static let brand          = Palette.grape
    static let brandAlt       = Palette.sky
    static let brandGradient  = LinearGradient(
        colors: [Palette.grape, Palette.bubblegum, Palette.tangerine],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// The dawn wash behind the home screen — a sunrise that means "your day
    /// just refilled".
    static func canvasWash(for scheme: ColorScheme) -> LinearGradient {
        scheme == .dark
            ? LinearGradient(colors: [Palette.nightBase, Color(hex: 0x2A1B57), Palette.nightBase],
                             startPoint: .top, endPoint: .bottom)
            : LinearGradient(colors: [Color(hex: 0xFFF6E6), Color(hex: 0xFFEFF6), Color(hex: 0xEAF6FF)],
                             startPoint: .top, endPoint: .bottom)
    }

    // MARK: - Dynamic resolution

    static func adaptive(light: Color, dark: Color) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { traits in
            UIColor(traits.userInterfaceStyle == .dark ? dark : light)
        })
        #else
        return light
        #endif
    }
}
