# Architecture

SwiftUI, iOS 17+, no third-party dependencies. Two targets sharing one source
folder. The whole design is shaped by one constraint: **a widget process must be
able to draw the same thing the app draws, in a few milliseconds, without the
app running.**

## The picture

```
┌──────────────────────── App process ────────────────────────┐
│  NoPhoneApp  @State AppState  ──.environment(state)──▶ RootView
│                    │                                    │
│                    │                          Home · Quests · Lock · You
│                    │                                    │
│                    ▼                        reads state, calls mutations
│            state.lockScreenSnapshot                      │
└────────────────────│─────────────────────────────────────────┘
                     │  scenePhase != .active
                     ▼
            SharedStore.write(_:)          WidgetCenter.reloadAllTimelines()
                     │                                  │
        ┌────────────▼─────────────┐                    │
        │  App Group UserDefaults  │                    │
        │  group.com.nophone.app   │                    │
        │  key: lockScreenSnapshot │                    │
        │  one JSON blob           │                    │
        └────────────┬─────────────┘                    │
                     │  SharedStore.read()  ◀───────────┘
┌────────────────────▼──────── Widget process ─────────────────┐
│  BudgetProvider ──▶ BudgetEntry ──▶ LockScreenWidgetViews     │
│                                     (the SAME renderers)      │
└───────────────────────────────────────────────────────────────┘
```

## State

**One observable object, owned by the app, injected through the environment.**

```swift
@main struct NoPhoneApp: App {
    @State private var state = AppState()          // owner
    …  RootView().environment(state)               // injection
}

struct HomeView: View {
    @Environment(AppState.self) private var state  // consumption
}
```

`AppState` is `@Observable` (iOS 17 Observation, not `ObservableObject`), so
views re-render on the properties they actually touch — no `@Published` fan-out,
no `objectWillChange` storms when one app's `usedSeconds` moves.

**There is no view model per screen, deliberately.** The screens are projections
of one small model; a `HomeViewModel` here would be a pass-through with a
lifecycle to get wrong. Anything derived lives as a computed property on the
model that owns the data:

- On `TrackedApp`: `remainingSeconds`, `remainingFraction`, `bonusFraction`,
  `status`, `longestSession`.
- On `AppState`: `totalRemaining`, `dayFraction`, `appsByUrgency`,
  `claimableQuests`, `claimableMinutes`.

Computed, never stored — a cached total is a total that can be wrong.

### Mutations

Every write goes through a method on `AppState`, and each one guards its own
preconditions:

| Method | Rule it enforces |
|---|---|
| `claim(_:)` | Quest must exist, not be exhausted, and be within the user's tier. Returns `false` rather than silently no-op'ing. |
| `effectiveReward(for:)` | The *only* place a payout is computed. Base × `MembershipPerks.premiumMultiplier`, premium only. |
| `applyMinutes(_:to:)` | Targeted quest tops up one app; untargeted spreads evenly — so a reward can't become a lever to overload the app someone is already losing to. `private`. |
| `recordUsage(minutes:for:)` | The DeviceActivity seam. Appends a session and burns time. |
| `rolloverDay()` | New day: bars refill, bonuses expire, daily quests reset, streak advances or breaks. |

### The integrity rule, as code

This is the product's load-bearing promise, so it is worth stating precisely:

- `Quest.rewardMinutes` is a `let`. The client cannot author a payout.
- `effectiveReward` is the single computation of what a claim pays, and it can
  only multiply the admin's number by one published constant.
- `MembershipPerks.premiumMultiplier` is quoted verbatim on the paywall and in
  the read-only reward table in Settings, so the promise and the logic cannot
  drift apart.
- A claim also writes a `RewardGrant` to `ledger`, newest first — the receipt.

Any change that adds a second path to grant minutes breaks this. Don't.

## Navigation

A single `NavigationStack` inside a custom floating tab bar
([`RootView.swift`](../NoPhone/App/RootView.swift)). The stock `TabView` bar is
translucent system chrome and would sit under this design like a foreign object,
so the shell switches on a `Tab` enum itself and draws its own sticker bar with
a candy lozenge sliding behind the selection.

Detail routing is value-driven: `selectedAppID: UUID?` at the shell level,
resolved through `navigationDestination(item:)`. Views pass IDs, not objects —
the object is always re-read from `AppState`, so a detail screen can never
render a stale copy of an app it doesn't own.

## The app ↔ widget bridge

Deliberately the smallest thing that works: **one JSON blob in App Group
`UserDefaults`**, not a database.

```swift
enum SharedStore {
    static let appGroupID = "group.com.nophone.app"   // must match Config/*.entitlements
    static func write(_ snapshot: LockScreenSnapshot)
    static func read() -> LockScreenSnapshot          // never throws
}
```

Design decisions worth keeping:

- **`read()` cannot fail into nothing.** A missing container, a failed decode, a
  schema change — all fall back to `.placeholder`. An empty accessory looks
  broken on a Lock Screen and there is no room there for an error state, so the
  widget always renders something *shaped like* real data.
- **`LockScreenSnapshot` is a flattened projection**, not the model. Per item:
  name, symbol, tint, `remainingSeconds`, `fraction`. The widget does one decode
  and draws; it never computes budget logic.
- **Written on backgrounding** (`scenePhase != .active`), which is exactly when
  the Lock Screen is about to be looked at, followed by
  `WidgetCenter.reloadAllTimelines()`.
- **The timeline is a safety net, not the mechanism.** One entry now, refresh
  after 15 minutes. The app pushes reloads when numbers change; a tighter
  cadence would burn the widget's refresh budget on numbers that only move while
  the phone is unlocked anyway.

**If `SharedStore.appGroupID` and the entitlements disagree, the widget silently
shows placeholder data.** That is the failure mode to check first when a widget
looks wrong.

### Why the renderers are shared

`Shared/Widgets/LockScreenWidgetViews.swift` draws both the real widget and the
Lock Screen Studio's in-app preview inside `PhoneFrame`. There is no second
implementation to drift. The renderers take a `vibrant: Bool`: accessory widgets
are rendered monochrome by the system, so the non-vibrant variant carries meaning
through **shape and density** instead of hue — the same reason `LockScreenStyle`
offers Blocks (chunky pips) alongside Rainbow Stack (bars).

Each style declares its own `appCapacity` (Rainbow Stack 4, Dials 5, Blocks 3,
Bloop 1), because the honest constraint of an accessory widget is how many rows
fit before it turns to mush.

## Design system

Views name **roles**, never values. Three levels:

```
Palette   raw hex ramp          ── never referenced by a feature
   ▼
Theme     semantic roles        ── surface, textPrimary, outline, danger…
AppTint   per-app identity      ── light / base / deep + gradients
   ▼
Features
```

`Theme` tokens are dynamic `UIColor` closures, so light/dark resolves per trait
collection — widgets, snapshots and previews all pick up the right variant for
free, with no `@Environment(\.colorScheme)` plumbing.

`AppTint` is the one that carries product meaning: **each app owns one tint for
its entire life in the UI** — tile, bar, detail header, lock-screen row. That is
what makes the Lock Screen readable at a glance without reading a label.

Full reference: [DESIGN_TOKENS.md](DESIGN_TOKENS.md).

## The two seams

Usage is sample data tuned to exercise every visual state at once — one app
spent, one critical, one healthy, one topped up. Real integrations land at
**exactly two places**, by design:

1. **`AppState.recordUsage(minutes:for:)`** — the stand-in for a
   `DeviceActivityMonitor` callback. Wiring up `FamilyControls` +
   `DeviceActivity` means requesting authorization, registering a schedule, and
   feeding this method. Nothing else in the app changes.
2. **`SampleData.quests`** — the stand-in for the admin's catalog, delivered by
   a backend. Replace with a fetch that produces `[Quest]`; the integrity rule
   survives because `rewardMinutes` stays a `let` on whatever arrives.

One known wrinkle for seam 1: third-party app icons are only available through
`FamilyControls`' opaque `Label`, which cannot be restyled. `TrackedApp.symbol`
uses our own SF Symbol glyph set instead, so the design holds either way.

## Persistence

Currently none beyond the widget snapshot — `AppState` is in-memory and reseeds
from `SampleData` each launch. The model is `Codable` end to end, so adding a
JSON file (or SwiftData) is a store-layer change that no view sees. Do it in
`Store/`, not in a view's `.task`.
