# NoPhone

iOS screen-time app in SwiftUI. Per-app time budgets that are **full at midnight
and drain with use** (inverse progress bar), surfaced on the Lock Screen via a
widget extension. Quests pay back fixed, admin-set minutes.

## Documentation

Read these before non-trivial work; they are the long-form version of this file.

- `Documentation/ARCHITECTURE.md` — state, the app↔widget bridge, navigation,
  the two data seams.
- `Documentation/STRUCTURE.md` — where files go and which target sees them.
- `Documentation/DESIGN_TOKENS.md` — the full token reference. **Consult it
  before writing any UI.**

Keep them current: a change to the token set, the layer rules, or the widget
bridge should update the matching doc in the same change.

## Build & run — the only supported command

`xcode-select` on this machine points at CommandLineTools, so bare `xcodebuild`
fails. Always pass `DEVELOPER_DIR`, and always build against **iPhone 15 /
iOS 18.6**:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project NoPhone.xcodeproj -scheme NoPhone \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.6' build
```

Rules:
- **Every code change must end with a green build using exactly that command.**
  Do not report work as done on an unbuilt change.
- Filter output with `| grep -E "error:|BUILD"` — full logs are noise.
- Schemes: `NoPhone` (app; embeds the widget extension) and
  `NoPhoneWidgetsExtension`. Building `NoPhone` compiles both, so it is the
  default target for verification.
- There is **no test target** in the project. "Verified" currently means: clean
  build + the relevant `#Preview` or a simulator run. Don't claim `xcodebuild
  test` passed — it has nothing to run.

## Layout

```
NoPhone/            App target
  App/              Entry point + custom floating tab bar shell
  Features/         Home, AppDetail, Quests, LockScreen, Rewards, Settings
  Resources/        Assets.xcassets
Shared/             Compiled into BOTH app and widget extension
  DesignSystem/     Tokens, Components, Effects
  Models/           TrackedApp, Quest, LockScreenStyle (+ widget snapshot)
  Store/            AppState, SampleData, Formatters, SharedStore
  Widgets/          Widget renderers — shared so preview == reality
NoPhoneWidgets/     Widget extension bundle
Config/             Entitlements + extension Info.plist
```

`Shared/` is a file-system-synchronized group in both targets — **adding a file
there needs no project edit**. Anything a widget touches must live in `Shared/`;
the extension cannot see `NoPhone/`.

## Invariants — do not break these

- **Reward values are admin-set.** `Quest.rewardMinutes` is a `let`; the client
  displays and records completions, never authors payouts. Premium scales it by
  the single published constant `MembershipPerks.premiumMultiplier` (1.5), and
  the paywall quotes that same constant so promise and code can't drift.
- **Features never touch `Palette` directly.** Name semantic roles from
  `Theme` (`surface`, `textPrimary`, `outline`) so the product re-skins from one
  file.
- **Nothing draws its own card.** The `StickerSurface` modifier owns the
  rounded fill + deep-indigo outline + opaque offset shadow.
- **Ink is never black** — deep indigo `#241B4A`.
- **One `AppTint` per app for its whole life in the UI** (tile, bar, detail
  header, lock-screen row). That identity is what makes the Lock Screen readable
  without labels.
- **Type is SF Rounded, `.bold`/`.heavy`**; anything that ticks uses tabular
  numerals.
- **Motion**: springs with overshoot for taps/rewards, damped spring for
  progress (an overshooting budget bar reads as a bug). All motion respects
  Reduce Motion.
- `SharedStore.appGroupID` must match the App Group in `Config/*.entitlements`,
  or the widget silently renders placeholder data.
- Every component and screen ships a `#Preview`. New ones should too.

## Data seams

Usage is sample data tuned to show every state at once (one spent, one critical,
one healthy, one topped up). Real integrations land at exactly two places:

- `AppState.recordUsage(minutes:for:)` — stand-in for a **DeviceActivity**
  callback. Wiring `FamilyControls` + `DeviceActivityMonitor` means feeding this
  method and nothing else.
- `SampleData.quests` — stand-in for the admin's backend catalog.

`SharedStore` writes the snapshot to the App Group on backgrounding and asks
WidgetKit to reload.

## Conventions

- Requires Xcode 16+, iOS 17+ (`@Observable`, `navigationDestination(item:)`,
  `containerBackground`, `symbolEffect`).
- `AppState` is `@Observable`, in-memory, single source of truth for the session.
- Comments in this codebase explain *why* a constraint exists, not what the line
  does. Match that.

## Agents

`.claude/agents/` defines three roles: `dev` (implement), `test` (verify),
`po` (scope/product decisions). Use them when the work fits.
