# F1 Evidence

**Status:** Passed
**Phase:** F1 — App shell and lifecycle
**Owner:** Platform / Quality
**Recorded:** 2026-09-14

## Scope boundary

F1 proves the menu-bar-first App Shell and its lifecycle only. It does not prove a Notch panel,
surface recovery, persistent Settings, ModuleRuntime, IPC, or operational Diagnostics.

## Automated verification

| Gate | Command/test target | Result | Evidence link or commit |
|---|---|---|---|
| F1 coordinator/menu/lifecycle tests | `swift test` | Passed | 2026-09-14; 8 Swift Testing tests. The coordinator seam covers idempotent start, menu outcomes, independent/failing placeholder scenes, lifecycle delivery/termination, restart/quit, and fakeable launch-at-login status. |
| Composite repository verification | `VERIFY_BASE_REF=HEAD^ ./Scripts/verify.sh` | Passed | 2026-09-14; toolchain, format, domain boundary, verification-check behavior, SwiftPM resolve/build/test, macOS app build, Markdown links, and changed-file secret scan all completed with exit status 0. |

The intentionally failing fixtures printed by `verification-checks.sh` (bad Markdown anchors, a
secret-like fixture, and an invalid `SwiftUI` domain import) were rejected as expected; they are
proof of the checks, not failures of the composite gate.

## Manual macOS verification

Environment: MacBookPro18,3; macOS 26.5.1 (25F80); Xcode 26.0.1 (17A400); 2026-09-14;
tester: Codex interactive macOS QA using the host's accessibility tree. This exercises the built
Debug app bundle on macOS, not a mocked coordinator. The sleep/wake result below was confirmed by
the user after installing and testing the app on 2026-09-14.

| Scenario | Expected result | Result | Notes/evidence |
|---|---|---|---|
| Cold launch | One reachable menu-bar item; no panel or permission prompt | Passed | Launched the Debug `NotchHub.app`; accessibility exposed exactly one `menubar.rectangle` status item, no app windows, and no permission dialog. |
| Open Settings | Independent placeholder scene opens | Passed | Menu action opened `Settings`; Diagnostics remained independently reachable. |
| Open Diagnostics | Independent placeholder scene opens | Passed | Menu action opened `Diagnostics` while `Settings` remained open, proving the two placeholder scenes are independent. |
| Toggle Surface / Show Demo State | Explicit unavailable state; no `NSPanel` is created | Passed | Both menu actions displayed their explicit unavailable message in the menu. Accessibility reported no additional app windows; no permission dialog appeared. F1 source creates no `NSPanel`. |
| Restart App Shell | F1-owned coordination restarts; no ModuleRuntime starts | Passed | Menu reported `App shell restarted.` and remained reachable; no additional app window/process appeared. No ModuleRuntime exists in F1. |
| Quit and relaunch | No hung process; menu bar remains reachable | Passed | `Quit NotchHub` left 0 `NotchHub` processes; relaunch left exactly 1 process and the status item reachable. |
| Sleep then wake | Menu bar remains usable; no panel or permission prompt | Passed | User confirmed the real sleep/wake cycle after installing the app on 2026-09-14. |
| Activate/deactivate | No crash; no unsolicited focus or UI | Passed | Deactivated by activating Finder; the NotchHub status item remained present, the process stayed alive, and no window or permission prompt appeared. |

## F1 gate decision

F1 is **complete**. All applicable automated and manual rows have recorded passing results, and
the implementation/docs match the scoped contract in [`roadmap.md`](../product/roadmap.md).
