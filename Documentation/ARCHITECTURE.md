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
        ┌────────────▼───────────────┐                  │
        │  App Group UserDefaults    │                  │
        │  group.site.lya3hc.nophone │                  │
        │  key: lockScreenSnapshot   │                  │
        │  one JSON blob             │                  │
        └────────────┬───────────────┘                  │
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
| `foldMonitorUsage(now:)` | Pulls real usage from the monitor extension via `UsageBridge`. Assigns absolute totals, so running it twice is harmless. |
| `track(name:tokenData:category:budgetMinutes:)` | Registers a picked app and assigns its permanent `AppTint`. |
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
    static let appGroupID = "group.site.lya3hc.nophone"   // must match Config/*.entitlements
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

## Real usage: the Screen Time pipeline

Usage is measured by Apple's Screen Time frameworks. There is no sample-usage
path in the running app — `AppState()` starts with **no apps at all** until the
person picks some.

```
FamilyActivityPicker  ──tokens──▶  AppPickerFlow  ──▶  AppState.track(...)
                                                            │
                                              ScreenTimeService.startMonitoring
                                                            │
                                                   DeviceActivity thresholds
                                                            │
                                            ┌───────────────▼────────────────┐
                                            │ DeviceActivityMonitorExtension │  separate process
                                            └───────────────┬────────────────┘
                                       UsageBridge.setUsage │ ManagedSettings shield
                                                            ▼
                              app foreground ──▶ AppState.foldMonitorUsage()
```

### The three frameworks

| Framework | Job |
|---|---|
| `FamilyControls` | Authorization, and the picker that yields `ApplicationToken`s. |
| `DeviceActivity` | Wakes our monitor extension at pre-registered usage thresholds. |
| `ManagedSettings` | Blocks a spent app; the shield lifts when a quest refills time. |

### Four constraints that shaped the design

1. **Apps are opaque.** A token carries no name, icon, or bundle ID. So the
   person names each app during picking, and we assign our own glyph and tint —
   which is what keeps the whole design system applicable to real data. Apple's
   `Label(token)` appears *only* in the picker, where it is the only way to
   confirm what was selected.
2. **Usage arrives in steps, not continuously.** DeviceActivity only calls back
   at thresholds registered in advance. `UsageBridge.tickMinutes` (5) is
   therefore the true resolution of every number in the app. Sessions are
   *derived* from a growing total, not observed — the system never reports a
   pickup.
3. **The monitor is a separate process.** It cannot see `AppState`. The two
   sides share the App Group and each owns disjoint keys: the app writes
   `roster`, the monitor writes `usage`, neither writes the other's. That rule
   is what makes the bridge correct without locking.
4. **`DeviceActivityReport` is a one-way box.** The extension that can read
   precise historical totals renders SwiftUI in a sandbox and cannot pass data
   back. Any chart sourced from it must be drawn inside it — which is why live
   budgets come from monitor thresholds instead.

### Thresholds are a prediction, so re-register often

`startMonitoring` runs whenever the roster changes — apps added or removed, a
budget edited, quest minutes granted. A threshold set is a guess about where
callbacks should land, and a refill moves them. Skipping this is the most likely
way to make budgets silently stop draining.

### Developing without a device

The Simulator has no Screen Time stack, so `SimulatorUsageDriver` stands in for
Apple's callback — and only for that. It writes to `UsageBridge` exactly as the
monitor extension does, and the app folds it in through the same
`foldMonitorUsage()`, so what runs in the Simulator is the real pipeline with
one end substituted rather than a parallel fake that can drift.

It is wrapped in `#if targetEnvironment(simulator)` and is absent from every
device build. Its fixture apps carry no `ApplicationToken`, so
`ScreenTimeService` skips them when registering events and cannot confuse a demo
app for a real one. Shields are the one thing it cannot reproduce.

## The remaining seam

**`SampleData.quests`** — still the stand-in for the admin's catalog, delivered
by a backend. Replace with a fetch producing `[Quest]`; the integrity rule
survives because `rewardMinutes` stays a `let` on whatever arrives.

`SampleData.apps` and `.ledger` are now **preview fixtures only**, reachable
through `AppState.preview`. Previews and the Simulator have no Screen Time
stack, so components still need populated state to render all four budget
statuses. Never wire them to the default initializer.

## Persistence

Beyond the widget snapshot, the tracked-app roster persists in the App Group
(`UsageBridge`), because the monitor extension must read it in a process that
never runs `AppState`. Everything else is still in-memory per session. The model is `Codable` end to end, so adding a
JSON file (or SwiftData) is a store-layer change that no view sees. Do it in
`Store/`, not in a view's `.task`.
