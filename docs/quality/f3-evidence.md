# F3 Automated Evidence

**Status:** Automated checks passed; native manual gate is unrun
**Date:** 2026-09-15
**Scope:** F3 Settings shell, `NotchUI` presentation boundary, accessibility/reduced-motion policy

## Implemented scope

- The menu-bar Settings route opens a standard macOS Settings application scene with the fixed
  routes General, Appearance, Notch Behavior, Shortcuts, Permissions, Actions, Modules,
  Diagnostics, and About.
- `SettingsShellModel` is the public `NotchUI` seam for route selection, route availability, and
  session-only motion preview.
- General, Appearance, Notch Behavior, and About provide F3-owned explanation/preview content.
  F5–F9 routes visibly state their owning phase and expose no active capability.
- The Appearance motion preview is never persisted and resets to the system policy when the
  Settings shell is recreated.

## Automated evidence

| Check | Result |
|---|---|
| `swift test --filter SettingsShellTests` | PASS — 3 Settings-shell seam tests |
| `swift test` | PASS — 46 tests |
| `xcodebuild -project NotchHub.xcodeproj -scheme NotchHub -configuration Debug -derivedDataPath /tmp/notchhub-f3-derived build` | PASS |
| `./Scripts/lint-format.sh` | PASS for F3 files |
| `git diff --check` | PASS |

Repository-wide validation scripts currently report pre-existing unrelated fixtures/changes:
`README.md` intentionally invalid-link/secret fixtures and
`Packages/NotchDomain/Sources/InvalidDomain.swift` importing SwiftUI. They are not F3 failures.

## Remaining manual gate

The following must be exercised on a physical macOS desktop before F3 is closed:

1. Open Settings from the menu bar while the Notch surface is suppressed or unavailable.
2. Traverse all nine routes with keyboard and VoiceOver; confirm route names, unavailable reasons,
   and focus order are understandable.
3. Confirm the session-only Reduced Motion preview avoids nonessential Settings transition motion
   and that the system Reduced Motion preference remains respected.
4. Inspect Light, Dark, Increased Contrast, and Reduced Transparency readability.

F2 native surface manual QA also remains a prerequisite to advancing the execution phase.
