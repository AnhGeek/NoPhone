import SwiftUI

/// Spacing scale — a 4pt grid with named steps so layout code never invents
/// a `13`.
enum Space {
    static let xxs: CGFloat = 4
    static let xs:  CGFloat = 8
    static let sm:  CGFloat = 12
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 44

    /// Standard screen gutter.
    static let gutter: CGFloat = 20

    /// Bottom inset for any scrolling screen inside the tab shell.
    ///
    /// The tab bar floats *over* content rather than reserving space, so every
    /// scroll view has to clear it by hand — including screens pushed onto the
    /// navigation stack, where it is easy to forget because the bar is not part
    /// of that screen's own layout. Without this the last control on a screen
    /// sits permanently under the bar and cannot be tapped.
    ///
    /// Sheets and full-screen covers are *outside* the shell and must not use
    /// it; `Space.xxl` is the right inset there.
    static let tabBarClearance: CGFloat = 120
}

/// Corner radii. Cartoon UI lives on *very* round corners — the squircles are
/// closer to lozenges than to rectangles.
enum Radius {
    static let xs:   CGFloat = 10
    static let sm:   CGFloat = 16
    static let md:   CGFloat = 22
    static let lg:   CGFloat = 30
    static let xl:   CGFloat = 40
    /// Fully rounded ends — pills, bars, chips.
    static let pill: CGFloat = 999
}

/// Outline weights. The chunky border is the load-bearing element of the
/// style, so it gets its own scale.
enum Stroke {
    static let hair:   CGFloat = 1.5
    static let thin:   CGFloat = 2
    static let medium: CGFloat = 3
    static let thick:  CGFloat = 4
    static let chunky: CGFloat = 5
}

/// Hard-offset "sticker" shadows. Unlike soft iOS shadows these are opaque and
/// displaced, so an element looks die-cut and laid on top of the page.
struct StickerShadow {
    let offset: CGSize
    let blur: CGFloat

    static let none  = StickerShadow(offset: .zero,                blur: 0)
    static let tight = StickerShadow(offset: .init(width: 0, height: 2), blur: 0)
    static let card  = StickerShadow(offset: .init(width: 0, height: 5), blur: 0)
    static let lift  = StickerShadow(offset: .init(width: 0, height: 8), blur: 0)
    /// Only for floating overlays, where a little blur sells the height.
    static let float = StickerShadow(offset: .init(width: 0, height: 12), blur: 18)
}

/// Motion tokens. Springs are deliberately bouncy — this UI should feel like
/// it is made of rubber, but never so loose that a tap feels unacknowledged.
enum Motion {
    /// Default for taps and state flips.
    static let jelly   = Animation.spring(response: 0.34, dampingFraction: 0.62)
    /// Bigger, showier — sheet arrivals, reward grants.
    static let bounce  = Animation.spring(response: 0.5,  dampingFraction: 0.55)
    /// Progress bars and rings; overshoot on a budget bar looks like a bug.
    static let smooth  = Animation.spring(response: 0.6,  dampingFraction: 0.9)
    /// Ambient looping motion (floating blobs, mascot idle).
    static let drift   = Animation.easeInOut(duration: 4).repeatForever(autoreverses: true)
    /// Attention pulse for a nearly-empty budget.
    static let pulse   = Animation.easeInOut(duration: 1.1).repeatForever(autoreverses: true)
}
