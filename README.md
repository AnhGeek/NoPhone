# NoPhone

**Your day starts full. Spend it on purpose.**

An iOS screen-time app built in SwiftUI. Every tracked app gets a bar that is
**full at midnight and drains as you use it** — the inverse of a progress bar,
because you are spending an allowance, not making progress. Finish real-world
quests and the bars top back up, by an amount your admin fixed in advance.

The bars live on your **Lock Screen**, which is the only place they can do their
job: you see them forty times a day, before you unlock and lose the argument.

---

## What it does

| | |
|---|---|
| **See today** | Per-app time used, opens, longest sitting, and a 24-hour histogram of when you picked it up. |
| **Watch it drain** | A candy bar per app, full at the start of the day, shrinking with use. Earned bonus time is drawn as a distinct sparkled segment, so a reward is visibly extra. |
| **Lock Screen** | Four widget styles — Rainbow Stack, Dials, Blocks, Bloop — previewed to scale inside a live iPhone mock with your real numbers, under four test wallpapers. |
| **Earn it back** | A quest list (make your bed, walk 3,000 steps, homework). Each pays a **fixed, admin-set** number of minutes. |
| **Champion tier** | Premium members earn 1.5× on every quest and unlock more daily slots. |

### The integrity rule

Reward values are **set by an admin and fixed**. The client can display them and
record completions; it can never author them. That constraint shows up in three
places:

- `Quest.rewardMinutes` is a `let` on the catalog definition.
- Every quest card carries a permanent *"Set by your admin"* note.
- Settings publishes the whole **reward table**, read-only, so the note is
  verifiable rather than just asserted.

Premium scales the base number by one published multiplier
(`MembershipPerks.premiumMultiplier`) — the paywall quotes that same constant,
so the promise and the code cannot drift.

---

## The design language

Modern, magnificent, cartoon — playground plastic rather than enterprise
dashboard. The rules that produce it:

**Sticker surfaces.** Every card is a rounded fill + a chunky deep-indigo
outline + an *opaque offset* shadow, so it reads as die-cut and laid on the
page. One modifier (`StickerSurface`) owns this; nothing draws its own card.

**Ink is never black.** Outlines are deep indigo (`#241B4A`) — black reads as
"chart", indigo stays warm against candy fills.

**Candy fills, top-lit.** Every tint ships a `light / base / deep` ramp plus a
gloss sheen. That specular highlight does more for the gummy feel than any
amount of gradient tuning.

**Heavy rounded type.** SF Rounded throughout, weights at `.bold`/`.heavy` —
thin type disappears next to thick outlines. Anything that ticks uses tabular
numerals so digits don't jitter.

**Rubber motion.** Springs with real overshoot for taps and rewards; a damped
spring for progress, because an overshooting budget bar looks like a bug.
Ambient motion (drifting blobs, mascot bob) runs slow enough to read as
atmosphere. All of it respects Reduce Motion.

**Per-app color identity.** Each app owns one `AppTint` for its whole life in
the UI — tile, bar, detail header, lock-screen row. That's what lets you read
the Lock Screen without reading a single label.

**A character, not a scolding.** Bloop — drawn entirely from SwiftUI shapes, no
assets — changes expression with your remaining budget: cheerful, chill,
worried, asleep. A reacting character is friendlier than a red number, and it
keeps the tone encouraging rather than punitive.

Full reference: [`Documentation/DESIGN_TOKENS.md`](Documentation/DESIGN_TOKENS.md).

### Token files

| File | Owns |
|---|---|
| `Shared/DesignSystem/Tokens/Palette.swift` | Raw candy ramp, ink, paper, night values |
| `Tokens/Theme.swift` | Semantic roles (`surface`, `textPrimary`, `outline`), light/dark resolved dynamically |
| `Tokens/Typography.swift` | The type ramp + tabular-numeral timer face |
| `Tokens/Metrics.swift` | 4pt spacing grid, lozenge radii, stroke weights, sticker shadows, motion springs |
| `Tokens/AppTint.swift` | Per-app color identity and its gradients |

Features never touch `Palette` directly — they name roles, so the whole product
can be re-skinned from one file.

---

## Project layout

```
NoPhone/            App target
  App/              Entry point + shell with the custom floating tab bar
  Features/         Home, AppDetail, Quests, LockScreen, Rewards, Settings
  Resources/        Asset catalog
Shared/             Compiled into BOTH the app and the widget extension
  DesignSystem/     Tokens, components, effects
  Models/           TrackedApp, Quest, LockScreenStyle + widget snapshot
  Store/            AppState, sample data, formatters, App Group bridge
  Widgets/          The widget renderers, shared so preview == reality
NoPhoneWidgets/     Widget extension (Lock Screen + Home Screen)
Config/             Entitlements and the extension Info.plist
```

`Shared/` is a file-system-synchronized group with membership in both targets,
so adding a file there needs no project edit.

Engineering docs live in [`Documentation/`](Documentation/README.md) —
[architecture](Documentation/ARCHITECTURE.md),
[structure](Documentation/STRUCTURE.md),
[design tokens](Documentation/DESIGN_TOKENS.md).

---

## Running it

Requires **Xcode 16+** and **iOS 17+** (uses `@Observable`, `navigationDestination(item:)`,
`containerBackground`, and `symbolEffect`).

```bash
open NoPhone.xcodeproj
```

Pick the **NoPhone** scheme and run. Before running on a device:

1. Set your team on both targets.
2. Change the bundle IDs (`site.lya3hc.nophone`, `site.lya3hc.nophone.widgets`, `site.lya3hc.nophone.monitor`).
3. Update the App Group in `Config/*.entitlements` **and**
   `SharedStore.appGroupID` — they must match, or the widget silently falls
   back to placeholder data.

Every component and screen ships a `#Preview`, so most of the design work
happens in the canvas without launching the app.

### Where the data comes from

Usage is **real**, measured with Apple's Screen Time frameworks: a
`FamilyControls` picker supplies app tokens, `DeviceActivity` wakes the
`NoPhoneMonitor` extension at usage thresholds, and `ManagedSettings` shields an
app once its budget is spent. The app starts with no tracked apps until the
person picks some.

Because Screen Time hands back **opaque tokens** — no name, no icon, no bundle
ID — the person names each app when picking it, and the app assigns its own
glyph and tint. That is what lets the design system apply to real data.

One stand-in remains:

- `SampleData.quests` — the stand-in for the admin's catalog, delivered by the
  backend.

`SampleData.apps` and `.ledger` are preview fixtures only, reached through
`AppState.preview`.

> **Screen Time does not work in the Simulator**, and the `family-controls`
> entitlement must be approved by Apple before App Store distribution. A green
> build proves compilation; only a physical device proves behaviour.

`SharedStore` already writes a snapshot to the App Group whenever the app
leaves the foreground, and asks WidgetKit to reload.
