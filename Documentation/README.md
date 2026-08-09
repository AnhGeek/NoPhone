# NoPhone — Documentation

Reference docs for the codebase. The root [`README.md`](../README.md) is the
product pitch; these are the engineering documents.

| Document | Read it when |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | You need to know how state, the widget bridge, and navigation actually work — and where real data plugs in. |
| [STRUCTURE.md](STRUCTURE.md) | You're adding a file and need to know where it goes and which target sees it. |
| [DESIGN_TOKENS.md](DESIGN_TOKENS.md) | You're writing any UI. The complete token reference — color, type, spacing, radii, strokes, shadows, motion. |

Machine-facing rules (build command, invariants, agents) live in
[`../CLAUDE.md`](../CLAUDE.md) and [`../.claude/agents/`](../.claude/agents/).

## The 60-second version

- **SwiftUI, iOS 17+, no third-party dependencies.** Two targets: the app and a
  widget extension.
- **`Shared/` compiles into both targets.** It is a file-system-synchronized
  group, so files added there need no project edit. Anything a widget renders
  must live there.
- **One state object**: `AppState`, `@Observable`, injected through the
  environment. No view model per screen.
- **The app ↔ widget contract is one JSON blob** in an App Group, written on
  backgrounding.
- **Design goes through tokens.** Views name semantic roles; nothing reaches for
  a raw hex, and nothing draws its own card.

## Build

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project NoPhone.xcodeproj -scheme NoPhone \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.6' build
```

`xcode-select` on this machine points at CommandLineTools, hence the explicit
`DEVELOPER_DIR`. iPhone 15 / iOS 18.6 is the reference destination.
