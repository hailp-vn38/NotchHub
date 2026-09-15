# F7 Module Runtime and DemoModule Evidence

**Status:** Automated implementation gate passed; native Debug QA pending
**Phase:** F7
**Implementation commit:** `53ed6e8`

## Evidence boundary

This record proves the actor/runtime, settings, action, lifetime, and descriptor seams through
automated checks. It does not prove the visible macOS panel or VoiceOver behavior. The pending
F2, F3, and F5 native gates remain independent and are not closed by F7.

## Automated evidence

| Gate | Result |
|---|---|
| Runtime start, disable, health, cleanup, and 100-cycle DemoModule loop | **PASS** — `swift test`, `ModuleRuntimeTests` |
| `demo.ping` registration, manual `demo.tick`, and action revocation on disable | **PASS** — `ModuleRuntimeTests` |
| Schema v2-to-v3 migration and durable DemoModule enablement | **PASS** — `NotchCoreTests` |
| Settings Modules health projection | **PASS** — `NotchUITests` |
| Debug and Release application builds | **PASS** — Xcode 27.0, 2026-09-15 |

`./Scripts/verify.sh` still reports its intentional negative fixtures for malformed links,
secret-pattern matching, and a forbidden Domain import. Those fixtures are repository checks,
not F7 failures.

## Native Debug QA still required

Run and record QA-MOD-001 and QA-MOD-002 from `docs/quality/manual-qa.md` in the real Debug app:
enable → indicator/compact status → disable → restart → simulated failure; then confirm Settings
labels and VoiceOver state/error text. Do not mark this phase native-complete until a maintainer
records those observations.
