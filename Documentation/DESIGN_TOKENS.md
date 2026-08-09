# Design tokens

The single reference for every value the UI is allowed to use. If a number or a
color is not in this document, it does not belong in a view.

**Design language:** playground plastic — sticker sheets and gummy candy, not
enterprise dashboard. Chunky indigo outlines, top-lit candy fills, heavy rounded
type, rubber motion.

## The three-level rule

```
Palette   ── raw hex ramp.        Features must NEVER reference this.
Theme     ── semantic roles.      What views name: surface, textPrimary, outline.
AppTint   ── per-app identity.    One tint per app, for its whole life in the UI.
```

Editing `Palette.swift` re-skins the entire product, in both targets, including
the widgets. That only stays true while features name roles.

---

## Color

### Palette — raw ramp
`Shared/DesignSystem/Tokens/Palette.swift`

Each candy hue ships three stops: `Up` (highlight) / base / `Dn` (shade). The
three-stop ramp is what produces the gummy top-lit fill.

| Hue | Light (`…Up`) | Base | Deep (`…Dn`) |
|---|---|---|---|
| bubblegum | `#FF9CC6` | `#FF6BA9` | `#E0417F` |
| tangerine | `#FFB06B` | `#FF8A3D` | `#E06A1C` |
| sunshine  | `#FFE07A` | `#FFCB3D` | `#E8A800` |
| mint      | `#7BECC4` | `#3ED9A4` | `#18B283` |
| sky       | `#8FD5FF` | `#4FB8FF` | `#1E8FE0` |
| grape     | `#BFA0FF` | `#9B6BFF` | `#7442E6` |
| cherry    | `#FF8C8C` | `#FF5A5A` | `#E03434` |

**Ink** — outlines and text. Never pure black; black reads as "chart", indigo
stays warm against candy.

| Token | Value |
|---|---|
| `ink` | `#241B4A` |
| `inkSoft` | `#4B4070` |
| `inkFaint` | `#8981AD` |

**Paper** — light-mode grounds. Warm cream, not white.

| Token | Value |
|---|---|
| `paper` | `#FFFDF7` |
| `paperTint` | `#FFF3E2` |
| `paperDeep` | `#F4E9D8` |

**Night** — dark mode stays playful; deep grape, never gunmetal grey.

| Token | Value |
|---|---|
| `nightBase` | `#1A1338` |
| `nightRaised` | `#261B4E` |
| `nightHigh` | `#33266A` |
| `nightInk` | `#FFF6EA` |
| `nightSoft` | `#C9BEF0` |
| `nightFaint` | `#8B7FC4` |

Helper: `Color(hex: 0xFF6BA9, opacity: 1)`.

### Theme — semantic roles
`Shared/DesignSystem/Tokens/Theme.swift` — **this is what views use.**

Every token is a dynamic color resolved per trait collection, so light/dark works
in widgets, snapshots and previews without any `colorScheme` plumbing.

| Role | Light | Dark | Use for |
|---|---|---|---|
| `canvas` | `paper` | `nightBase` | The page itself |
| `surface` | white | `nightRaised` | Cards, sheets |
| `surfaceSunk` | `paperTint` | `nightHigh` | Track backgrounds, inset rows, disabled chips |
| `well` | `paperDeep` | `#140E2C` | Deepest recess — bar troughs, input wells |
| `textPrimary` | `ink` | `nightInk` | Headings, values |
| `textSecondary` | `inkSoft` | `nightSoft` | Supporting copy |
| `textTertiary` | `inkFaint` | `nightFaint` | Metadata |
| `textOnColor` | white | white | Text on a saturated fill |
| `outline` | `ink` | `#0D0824` | The signature chunky border |
| `outlineSoft` | `ink` @16% | white @14% | Nested elements that would look heavy |
| `shadowHard` | `ink` @90% | black @75% | The opaque sticker shadow |

**Status** — `good` = mint, `caution` = sunshine, `warning` = tangerine,
`danger` = cherry, `premium` = grape.

**Brand** — `brand` = grape, `brandAlt` = sky, `brandGradient` = grape →
bubblegum → tangerine (topLeading → bottomTrailing).

**`canvasWash(for:)`** — the dawn gradient behind Home. Light: cream → pink →
blue, a sunrise that means *your day just refilled*. Dark: night → `#2A1B57` →
night.

### AppTint — per-app identity
`Shared/DesignSystem/Tokens/AppTint.swift`

Seven cases matching the candy ramp. Each exposes:

| Member | Meaning |
|---|---|
| `base` | Mid value — fills, text on light grounds |
| `light` | Highlight — top of a gradient, glow halos |
| `deep` | Shade — bottom of a fill, pressed states, inner shadow |
| `gradient` | `light → base → deep`, top to bottom. The glossy candy fill. |
| `softGradient` | Flatter diagonal variant for large areas, where the full ramp gets noisy |
| `contrastInk` | White — **except sunshine**, which is too light to carry white text at small sizes, so it returns `ink` |

**Assign one tint per app and never vary it.** The Lock Screen's readability
depends on it: people learn "pink = the one I keep opening" without reading a
label.

---

## Typography
`Shared/DesignSystem/Tokens/Typography.swift`

All SF Rounded — the single biggest lever on "cartoon but not childish-cheap".
Weights skew heavy because thin type disappears next to thick outlines.

| Token | Size / weight | Use |
|---|---|---|
| `Typo.mega` | 52 heavy | Hero numerals — "2h 14m left" |
| `Typo.title` | 30 heavy | Screen titles |
| `Typo.headline` | 20 bold | Card headers, app names |
| `Typo.body` | 17 semibold | Row titles |
| `Typo.callout` | 15 medium | Supporting copy |
| `Typo.caption` | 13 semibold | Metadata, timestamps |
| `Typo.micro` | 11 heavy | Pills, badges, eyebrows |

**`Typo.timer(_ size:weight:)`** — tabular numerals. Mandatory for anything that
ticks: a countdown that reflows its own digits reads as broken.

**`.eyebrow()`** — view modifier: micro + uppercase + 1.2 tracking.

---

## Spacing — `Space`
4pt grid, so layout code never invents a `13`.

| Token | Value |
|---|---|
| `xxs` | 4 |
| `xs` | 8 |
| `sm` | 12 |
| `md` | 16 |
| `lg` | 24 |
| `xl` | 32 |
| `xxl` | 44 |
| `gutter` | 20 — standard screen margin |

## Corner radii — `Radius`
Cartoon UI lives on very round corners; these are lozenges, not rectangles.

| Token | Value | Typical |
|---|---|---|
| `xs` | 10 | Chips, small badges |
| `sm` | 16 | Inset rows |
| `md` | 22 | Standard controls |
| `lg` | 30 | Cards (`cardSurface` default) |
| `xl` | 40 | Sheets, hero panels |
| `pill` | 999 | Bars, pills, chips |

Always `style: .continuous`.

## Outline weights — `Stroke`
The chunky border is load-bearing, so it gets its own scale.

| Token | Value |
|---|---|
| `hair` | 1.5 |
| `thin` | 2 |
| `medium` | 3 |
| `thick` | 4 |
| `chunky` | 5 |

## Shadows — `StickerShadow`
**Opaque and displaced, not soft.** This is what makes an element look die-cut
and laid on the page rather than floating in a light-well.

| Token | Offset | Blur |
|---|---|---|
| `none` | 0 | 0 |
| `tight` | y 2 | 0 |
| `card` | y 5 | 0 |
| `lift` | y 8 | 0 |
| `float` | y 12 | 18 — the only blurred one, for floating overlays where blur sells the height |

## Motion — `Motion`
Rubber, but never so loose a tap feels unacknowledged.

| Token | Curve | Use |
|---|---|---|
| `jelly` | spring 0.34 / 0.62 | Default — taps, state flips |
| `bounce` | spring 0.5 / 0.55 | Showier — sheet arrivals, reward grants |
| `smooth` | spring 0.6 / 0.9 | **Progress bars and rings.** Overshoot on a budget bar looks like a bug |
| `drift` | easeInOut 4s, repeating | Ambient — floating blobs, mascot idle |
| `pulse` | easeInOut 1.1s, repeating | Attention — a nearly-empty budget |

All motion must respect Reduce Motion.

---

## Composition primitives
`Shared/DesignSystem/Components/StickerStyle.swift` — not tokens, but the
modifiers that apply them. **Nothing draws its own card.**

| API | Does |
|---|---|
| `StickerSurface` | The signature treatment: rounded fill + chunky `Theme.outline` + opaque offset shadow |
| `.sticker(_:radius:stroke:shadow:)` | Apply it with any `ShapeStyle` fill |
| `.cardSurface(radius:)` | The common case — `Theme.surface`, `Radius.lg`, `.card` shadow |
| `.glossy(radius:intensity:)` | The specular sheen. Does more for the gummy feel than any gradient tuning |
| `.jellyPress(scale:sink:)` | Press feedback — squash + sink |
| `.inkOutline(_:width:)` | Outlined text for numerals sitting on color |

---

## Checklist before you commit UI

- [ ] No raw hex, and no `Palette.` reference outside `Theme` / `AppTint`.
- [ ] No literal spacing, radius, or stroke number — use the scales.
- [ ] Card treatment via `StickerSurface` / `.cardSurface()`, not hand-rolled.
- [ ] Anything that ticks uses `Typo.timer` (tabular numerals).
- [ ] Progress animates with `Motion.smooth`, not `.jelly`.
- [ ] The app's tint is the same one it uses everywhere else.
- [ ] Reduce Motion honoured.
- [ ] Checked in **both** light and dark.
- [ ] Ships a `#Preview`.
