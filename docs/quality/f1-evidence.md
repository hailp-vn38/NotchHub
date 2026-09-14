# F1 Evidence

**Status:** In progress — ticket 02 automated evidence recorded; remaining F1 work and manual macOS verification are pending
**Phase:** F1 — App shell and lifecycle
**Owner:** Platform / Quality
**Recorded:** —

## Scope boundary

F1 proves the menu-bar-first App Shell and its lifecycle only. It does not prove a Notch panel,
surface recovery, persistent Settings, ModuleRuntime, IPC, or operational Diagnostics.

## Automated verification

| Gate | Command/test target | Result | Evidence link or commit |
|---|---|---|---|
| F1 coordinator/menu tests | `swift test` | Passed | `849d33c`; 6 Swift Testing tests, including independent placeholder scene requests and isolation after a scene-presentation failure |
| Package/app build | `./Scripts/verify.sh` | Passed | `849d33c`; includes format, boundary, package/app build, tests, Markdown links, and changed-file secret checks |

## Manual macOS verification

Record the Mac model, macOS version, Xcode version, date, and tester with each result.

| Scenario | Expected result | Result | Notes/evidence |
|---|---|---|---|
| Cold launch | One reachable menu-bar item; no panel or permission prompt | Pending | — |
| Open Settings | Independent placeholder scene opens | Pending | — |
| Open Diagnostics | Independent placeholder scene opens | Pending | — |
| Toggle Surface / Show Demo State | Explicit unavailable state; no `NSPanel` is created | Pending | — |
| Restart App Shell | F1-owned coordination restarts; no ModuleRuntime starts | Pending | — |
| Quit and relaunch | No hung process; menu bar remains reachable | Pending | — |
| Sleep then wake | Menu bar remains usable; no panel or permission prompt | Pending | — |
| Activate/deactivate | No crash; no unsolicited focus or UI | Pending | — |

## F1 gate decision

Do not mark F1 complete until every applicable row is recorded as passed, any skipped row has a
reason, and the implementation/docs match the scoped contract in
[`roadmap.md`](../product/roadmap.md).
