# Project structure

Where files go, and why. The organising principle is the one most modern iOS
apps land on: **feature folders for screens, a shared design system beside
them, and a shared layer that a second target can also compile.**

```
NoPhone/
├── NoPhone.xcodeproj/
├── Config/                     Build-adjacent config, not code
│   ├── NoPhone.entitlements
│   ├── NoPhoneWidgets.entitlements
│   └── NoPhoneWidgets-Info.plist
│
├── NoPhone/                    ── App target ──
│   ├── App/
│   │   ├── NoPhoneApp.swift        @main, state ownership, snapshot publishing
│   │   └── RootView.swift          Shell: custom floating tab bar + NavigationStack
│   ├── Features/                   One folder per screen
│   │   ├── Home/                   HomeView, AppBudgetCard
│   │   ├── AppDetail/              AppDetailView
│   │   ├── Quests/                 QuestsView, QuestCard
│   │   ├── LockScreen/             LockScreenStudio, PhoneFrame
│   │   ├── Rewards/                PremiumView (paywall)
│   │   └── Settings/               SettingsView (+ the public reward table)
│   └── Resources/
│       └── Assets.xcassets         AccentColor, AppIcon
│
├── Shared/                     ── Both targets ──
│   ├── DesignSystem/
│   │   ├── Tokens/                 Palette, Theme, Typography, Metrics, AppTint
│   │   ├── Components/             StickerStyle, TimeBudgetBar, BudgetRing, Controls
│   │   └── Effects/                BlobBackground, Mascot (Bloop), Confetti
│   ├── Models/                     TrackedApp, Quest, LockScreenStyle (+ snapshot)
│   ├── Store/                      AppState, UsageBridge, SampleData, Formatters, SharedStore
│   └── Widgets/                    LockScreenWidgetViews — the renderers
│
├── NoPhoneWidgets/             ── Widget extension target ──
│   └── NoPhoneWidgetBundle.swift   WidgetBundle, TimelineProvider, both widgets
│
├── Documentation/              You are here
├── CLAUDE.md                   Agent-facing rules
└── .claude/                    Agent definitions + shared permissions
```

## The one rule that decides placement

**Target membership follows the folder.**

| Folder | App | Widget ext |
|---|:--:|:--:|
| `NoPhone/` | ✅ | ❌ |
| `Shared/` | ✅ | ✅ |
| `NoPhoneWidgets/` | ❌ | ✅ |

So: **if a widget renders it, it lives in `Shared/`.** The extension is a
separate process with a separate binary — it cannot see `NoPhone/`. This is why
`Widgets/` (the renderers) sits in `Shared/` while the widget *configuration*
(`WidgetBundle`, `TimelineProvider`) sits in `NoPhoneWidgets/`: the same view
code draws the Lock Screen Studio preview inside the app and the real widget on
the Lock Screen, so **preview == reality** by construction rather than by
discipline.

`Shared/` is a **file-system-synchronized group** (Xcode 16+). Adding a file
there is a plain file write — no `.pbxproj` edit, no target-membership
checkbox, no merge conflict. Prefer it.

## Layer rules

Dependencies point one way. Nothing below reaches up.

```
Features  ──▶  Components / Effects  ──▶  Tokens
    └─────────▶  Store  ──▶  Models  ──▶  Tokens (AppTint only)
```

- **Features** compose components and read `AppState`. They never define a card
  background, never open `Palette`, never format a duration by hand (`Fmt` owns
  that).
- **Components** are stateless and tint-parameterised — they take an `AppTint`
  or a `ShapeStyle`, never look up which app they're drawing.
- **Tokens** import nothing but SwiftUI. They are the bottom of the stack.
- **Models** are `Codable` value types with derived properties (`remainingFraction`,
  `status`). Business rules that need more than one model live in `AppState`.
- **Store** is the only mutable layer.

## Naming

- Screens end in `View` (`HomeView`), reusable cards end in `Card`
  (`AppBudgetCard`), modifiers end in the thing they do (`StickerSurface`,
  `JellyPress`).
- Token namespaces are short and read as prose at the call site: `Space.md`,
  `Radius.pill`, `Stroke.chunky`, `Motion.jelly`, `Typo.headline`, `Theme.surface`.
- One type per file, file named after it — except tightly-coupled satellites
  (`BudgetStatus`, `AppCategory`, `UsageSession` all live with `TrackedApp`,
  because they exist only to describe it).

## Every view ships a `#Preview`

Non-negotiable, and it is why the design work happens in the canvas rather than
the simulator. A new component without a preview is incomplete.

## Known gaps vs. a fully modern setup

Honest list, for whoever picks this up next:

1. **No test target.** `xcodebuild test` has nothing to run. `AppState`'s reward
   math (`claim`, `effectiveReward`, `applyMinutes`, `rolloverDay`) is pure and
   deterministic — it is unit-testable today, it just isn't tested.
2. **No SPM module split.** `Shared/` is a folder in both targets rather than a
   local Swift package. That is fine at this size; a package would buy enforced
   layer boundaries and a faster test loop if the app grows.
3. **No build configuration files.** Settings live in the `.pbxproj`. `.xcconfig`
   files would make bundle IDs and team settings diffable — relevant as soon as
   there is more than one developer or a CI signing identity.
4. **Sample data is preview-only.** `SampleData.apps`/`.ledger` reach the UI
   solely through `AppState.preview`; the running app starts empty and fills
   from Screen Time. `SampleData.quests` remains the backend stand-in. See
   [ARCHITECTURE.md](ARCHITECTURE.md#real-usage-the-screen-time-pipeline).
5. **Screen Time code never goes in `Shared/`.** The widget would have to link
   the frameworks and carry the `family-controls` entitlement for data it never
   reads. App-side code lives in `NoPhone/ScreenTime/`, monitor code in
   `NoPhoneMonitor/`, and only plain `Data`/`String` crosses into `Shared/`.

None of these block work today. Items 1 and 3 are the ones worth doing first.
