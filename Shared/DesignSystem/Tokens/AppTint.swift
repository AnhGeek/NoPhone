import SwiftUI

/// Per-app color identity.
///
/// Each tracked app owns one tint for its whole lifetime in the UI — the tile,
/// the budget bar, the detail header and the lock-screen row all agree. That
/// consistency is what lets someone read the lock screen at a glance: they
/// learn "pink = the one I keep opening" without reading a single label.
enum AppTint: String, CaseIterable, Codable, Identifiable {
    case bubblegum, tangerine, sunshine, mint, sky, grape, cherry

    var id: String { rawValue }

    /// Mid value — fills, text on light backgrounds.
    var base: Color {
        switch self {
        case .bubblegum: Palette.bubblegum
        case .tangerine: Palette.tangerine
        case .sunshine:  Palette.sunshine
        case .mint:      Palette.mint
        case .sky:       Palette.sky
        case .grape:     Palette.grape
        case .cherry:    Palette.cherry
        }
    }

    /// Highlight — the top of a fill gradient, glow halos.
    var light: Color {
        switch self {
        case .bubblegum: Palette.bubblegumUp
        case .tangerine: Palette.tangerineUp
        case .sunshine:  Palette.sunshineUp
        case .mint:      Palette.mintUp
        case .sky:       Palette.skyUp
        case .grape:     Palette.grapeUp
        case .cherry:    Palette.cherryUp
        }
    }

    /// Shade — bottom of a fill, pressed states, inner shadow.
    var deep: Color {
        switch self {
        case .bubblegum: Palette.bubblegumDn
        case .tangerine: Palette.tangerineDn
        case .sunshine:  Palette.sunshineDn
        case .mint:      Palette.mintDn
        case .sky:       Palette.skyDn
        case .grape:     Palette.grapeDn
        case .cherry:    Palette.cherryDn
        }
    }

    /// The glossy top-lit fill used on every candy surface.
    var gradient: LinearGradient {
        LinearGradient(colors: [light, base, deep],
                       startPoint: .top, endPoint: .bottom)
    }

    /// Flatter variant for large areas, where the full ramp gets noisy.
    var softGradient: LinearGradient {
        LinearGradient(colors: [light.opacity(0.9), base],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Sunshine is too light to carry white text at small sizes.
    var contrastInk: Color {
        self == .sunshine ? Palette.ink : .white
    }
}
