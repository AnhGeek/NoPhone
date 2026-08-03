import SwiftUI

/// Raw, non-semantic color values.
///
/// Nothing in a feature view should reach into `Palette` directly — features
/// talk to `Theme` (semantic) or `AppTint` (per-app identity) instead. Keeping
/// the raw ramp in one place is what lets us re-skin the whole product by
/// editing a single file.
///
/// The vibe: playground plastic. Saturated, high-chroma, slightly "sugary"
/// hues with deep ink outlines — think sticker sheets and gummy candy, not
/// enterprise dashboards.
enum Palette {

    // MARK: - Core candy ramp

    static let bubblegum   = Color(hex: 0xFF6BA9)
    static let bubblegumUp = Color(hex: 0xFF9CC6)
    static let bubblegumDn = Color(hex: 0xE0417F)

    static let tangerine   = Color(hex: 0xFF8A3D)
    static let tangerineUp = Color(hex: 0xFFB06B)
    static let tangerineDn = Color(hex: 0xE06A1C)

    static let sunshine    = Color(hex: 0xFFCB3D)
    static let sunshineUp  = Color(hex: 0xFFE07A)
    static let sunshineDn  = Color(hex: 0xE8A800)

    static let mint        = Color(hex: 0x3ED9A4)
    static let mintUp      = Color(hex: 0x7BECC4)
    static let mintDn      = Color(hex: 0x18B283)

    static let sky         = Color(hex: 0x4FB8FF)
    static let skyUp       = Color(hex: 0x8FD5FF)
    static let skyDn       = Color(hex: 0x1E8FE0)

    static let grape       = Color(hex: 0x9B6BFF)
    static let grapeUp     = Color(hex: 0xBFA0FF)
    static let grapeDn     = Color(hex: 0x7442E6)

    static let cherry      = Color(hex: 0xFF5A5A)
    static let cherryUp    = Color(hex: 0xFF8C8C)
    static let cherryDn    = Color(hex: 0xE03434)

    // MARK: - Ink & paper

    /// Cartoon outlines are never pure black — that reads as "chart", not
    /// "sticker". A deep indigo keeps the outline warm against candy fills.
    static let ink         = Color(hex: 0x241B4A)
    static let inkSoft     = Color(hex: 0x4B4070)
    static let inkFaint    = Color(hex: 0x8981AD)

    static let paper       = Color(hex: 0xFFFDF7)
    static let paperTint   = Color(hex: 0xFFF3E2)
    static let paperDeep   = Color(hex: 0xF4E9D8)

    // MARK: - Night mode (kept playful, never gunmetal grey)

    static let nightBase   = Color(hex: 0x1A1338)
    static let nightRaised = Color(hex: 0x261B4E)
    static let nightHigh   = Color(hex: 0x33266A)
    static let nightInk    = Color(hex: 0xFFF6EA)
    static let nightSoft   = Color(hex: 0xC9BEF0)
    static let nightFaint  = Color(hex: 0x8B7FC4)
}

// MARK: - Hex convenience

extension Color {
    /// `Color(hex: 0xFF6BA9)` — terser than the four-argument initializer and
    /// keeps the palette above scannable as a table of values.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red:     Double((hex >> 16) & 0xFF) / 255,
            green:   Double((hex >> 8)  & 0xFF) / 255,
            blue:    Double( hex        & 0xFF) / 255,
            opacity: opacity
        )
    }
}
