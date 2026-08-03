import SwiftUI

/// Type ramp.
///
/// Everything is SF Rounded — the single biggest lever on "cartoon but not
/// childish-cheap". Weights skew heavy (`.bold` / `.heavy`) because thin type
/// disappears next to thick outlines and saturated fills.
///
/// All sizes go through `.relativeTo:` so Dynamic Type still scales the ramp;
/// we set the shape, the user sets the size.
enum Typo {

    /// Hero numerals — the "2h 14m left" on the home ring.
    static let mega     = rounded(52, .heavy,     relativeTo: .largeTitle)
    /// Screen titles.
    static let title    = rounded(30, .heavy,     relativeTo: .title)
    /// Card headers, app names in the list.
    static let headline = rounded(20, .bold,      relativeTo: .headline)
    /// Row titles.
    static let body     = rounded(17, .semibold,  relativeTo: .body)
    /// Supporting copy.
    static let callout  = rounded(15, .medium,    relativeTo: .callout)
    /// Metadata, timestamps.
    static let caption  = rounded(13, .semibold,  relativeTo: .caption)
    /// Pills, badges, all-caps eyebrows.
    static let micro    = rounded(11, .heavy,     relativeTo: .caption2)

    /// Tabular numerals for anything that ticks — a countdown that reflows its
    /// own digits reads as broken.
    static func timer(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }

    private static func rounded(_ size: CGFloat,
                                _ weight: Font.Weight,
                                relativeTo style: Font.TextStyle) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension View {
    /// All-caps eyebrow label with the wide tracking the style relies on.
    func eyebrow() -> some View {
        self.font(Typo.micro)
            .textCase(.uppercase)
            .tracking(1.2)
    }
}
