# F6 Shortcut Framework Evidence

**Status:** Automated gate passed; native manual QA pending
**Phase:** F6
**Scope:** App-active shortcut binding framework only

## Evidence boundary

F6 supplies a persisted, typed input route to a future registered Action. It does not register an
Action, install a global event monitor, capture a key event, request Accessibility, execute a
callback, or expose IPC. Automated tests therefore prove persistence, migration, conflict safety,
and Settings projection; they do not prove a future Action executor or global macOS shortcut.

## Required automated evidence

| Gate | Evidence |
|---|---|
| Binding policy | Unknown Action stays unavailable; conflicts keep the existing binding; bindings persist across relaunch; disabled bindings do not retain their chord | **PASS** — `NotchActionsTests` |
| Settings migration | F4 v1 snapshot migrates to v2 with empty shortcut bindings | **PASS** — `NotchCoreTests` |
| Settings UI seam | Empty and unavailable-binding projections are explicit; Shortcuts is interactive only when its F6 model is composed | **PASS** — `NotchUITests` |
| Repository gate | `./Scripts/verify.sh`, including Swift tests, Debug macOS build, static checks, links, and secret scan | **PASS** — Xcode 27.0, 2026-09-15 |

## Native manual QA

Before this phase is called complete, open Settings → Shortcuts in a Debug app and confirm the
empty-state wording and keyboard/VoiceOver order. A future Action owner must separately verify
recorder capture and action dispatch; global shortcut work must separately verify permission/API
behavior.
