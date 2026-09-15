# F7 Module Runtime and DemoModule

**Status:** ready-for-human
**Phase:** F7
**Owner:** Architecture / Core / UX / Quality


## Problem Statement

NotchHub has typed settings, capability policy, a Settings shell, Action and
surface contracts, but it does not yet have a safe owner for feature lifecycle.
Without a **Module runtime**, each future feature could choose its own startup,
shutdown, settings access, resource ownership, surface behavior, and failure
handling. A broken feature could retain work after disable, make the App shell
hang, bypass the Notch surface boundary, or make it impossible to distinguish a
user-disabled Module from an enabled Module that failed.

F7 must prove the platform boundary before a real Module exists. It needs one
small, deterministic **DemoModule** that validates settings, actions, event
declaration, two bounded surface contribution descriptors, lifecycle isolation,
and cleanup without pulling EventBus/IPC, automatic recovery, real permissions,
or production diagnostics ahead of their owning phases.

## Solution

Introduce an actor-owned **Module runtime** as the sole lifecycle and health
authority for statically linked Modules. It registers only composition-root
known Modules, persists **Module enablement intent** separately from transient
health, gives every running Module a revocable **Module lifetime**, and exposes
read-only health projections to Settings.

Deliver `NotchDemoModule` as a Debug/test-only static Module. It demonstrates
one user-triggered `demo.ping` action, manually emitted `demo.tick`, deterministic
`indicator` and `compactStatus` **Surface contribution descriptors**, and a
debug-only simulated failure. It requires no Capability. Its lifecycle is
bounded, explicit, testable through the Module runtime seam, and cannot alter
the native Notch surface directly.

## User Stories

1. As a NotchHub user, I want to see whether a Module is enabled and healthy, so that I can distinguish a deliberate choice from a problem.
2. As a user, I want disabling a Module to stop its work, so that an optional feature does not consume resources after I turn it off.
3. As a user, I want an enabled Module that fails to report a clear sanitized error, so that I know restarting it may help.
4. As a user, I want to restart one failed or running Module from Settings, so that I do not need to restart the whole app for one feature.
5. As a user, I want the App shell and Notch surface to remain usable when one Module fails, so that an optional capability cannot take away core controls.
6. As a user, I want my enable/disable choice to survive relaunch, so that Modules do not unexpectedly return after I disabled them.
7. As a user, I want a failed enabled Module to remain visibly enabled but failed, so that the app does not silently change my preference.
8. As a user, I want DemoModule status to be small and deterministic in the Notch surface, so that the foundation can be verified without pretending to be a real product feature.
9. As a user, I want DemoModule absent from release builds, so that a foundation test feature does not become product clutter.
10. As a keyboard or VoiceOver user, I want Module health and Enable, Disable, and Restart controls to have meaningful labels and states, so that module recovery is accessible without relying on color.
11. As a module author, I want one lifecycle owner, so that concurrent UI requests cannot race my Module's start and stop work.
12. As a module author, I want a capability-scoped context instead of raw AppKit or application access, so that I can contribute safely without learning private host internals.
13. As a module author, I want a Module lifetime to own my tasks, observers, subscriptions, actions, and contributions, so that cleanup is explicit and testable.
14. As a module author, I want a start timeout and a bounded stop contract, so that a hung dependency cannot indefinitely block the host.
15. As a module author, I want my settings namespace isolated, so that I cannot accidentally read or overwrite another Module's data.
16. As a module author, I want to declare supported surface slots without owning layout or panel transitions, so that feature presentation remains consistent with Notch policy.
17. As a module author, I want an internal event-publisher seam for F7, so that DemoModule can prove event declaration without prematurely depending on F8 transport.
18. As a module author, I want a reusable authoring guide and template, so that a future Module starts from required product, privacy, security, lifetime, and test questions rather than implementation folklore.
19. As an app maintainer, I want only statically linked Modules registered at the composition root, so that package dependencies, signing, and review remain explicit.
20. As an app maintainer, I want concrete DemoModule logic outside Core, so that the Core boundary remains a platform rather than a feature bucket.
21. As an app maintainer, I want lifecycle contracts in Core and pure identifiers/state in Domain, so that the package graph stays acyclic.
22. As an app maintainer, I want Disable during start to converge to stopped after one cleanup call, so that rapidly changing a toggle cannot leak or double-stop resources.
23. As an app maintainer, I want no automatic retry in F7, so that a failing Module cannot create an invisible crash loop or unexpected background work.
24. As an app maintainer, I want a composition/test-only runtime restart operation, so that all enabled Modules can be rebuilt deterministically without adding a premature user-facing recovery action.
25. As a security reviewer, I want DemoModule to require no Capability and expose no IPC or shortcut entry point, so that F7 does not expand trust or permission scope.
26. As a security reviewer, I want module actions to remain typed and namespaced, so that a Module cannot become an arbitrary command-execution path.
27. As a quality engineer, I want to test lifecycle behavior through the public Module runtime seam, so that tests verify behavior rather than actor internals or SwiftUI implementation details.
28. As a quality engineer, I want a recording module event publisher and resource tracker, so that tests can prove declared events and cleanup deterministically.
29. As a quality engineer, I want a 100-cycle DemoModule enable/disable/restart test, so that resource ownership regressions are caught before real Modules use the platform.
30. As a quality engineer, I want a native macOS Debug check of the two DemoModule surface descriptors, so that actor and snapshot tests are not mistaken for evidence of real panel integration.
31. As a release reviewer, I want pending F2, F3, and F5 native gates to remain explicit, so that F7 evidence is not used to claim unrelated platform behavior is complete.
32. As a future EventBus maintainer, I want F7's local event seam kept separate from external envelopes and routing, so that F8 can introduce validation, backpressure, ordering, and IPC under its own contract.
33. As a future diagnostics maintainer, I want F7 to expose only sanitized health/error projections and a test sink, so that F9 retains ownership of history, export, and resource-metric UI.
34. As a future real Module author, I want DemoModule to validate the template without becoming a copy-paste architecture, so that later modules can evolve only when a real requirement proves it.

## Implementation Decisions

- The **Module runtime** is an actor and the only authority that registers Modules, applies enablement intent, changes lifecycle state, creates/revokes a Module lifetime, and publishes health projections. Views dispatch typed enable, disable, and per-Module restart intents; they never call a Module lifecycle method directly.
- The Domain boundary owns pure Module identifiers, metadata, lifecycle states, and health data transfer objects. Core owns the executable Module contract, its context, Module lifetime, runtime, and internal Module event publisher. A separate static DemoModule target depends on Core and Domain. The composition root is the sole registration point.
- F7 uses only statically linked Modules. Dynamic plugin discovery or loading remains excluded under the accepted static-module architecture decision.
- Module metadata is deliberately minimal: display name, version, supported surface slots, required capabilities, optional capabilities, and declared runtime policy. Icon, settings-route, priority, and multi-Module arbitration metadata are deferred until a real Module needs them.
- DemoModule declares no required or optional Capability. It has no Module-owned settings page and no secret or permission request behavior.
- Settings migrate to schema v3 with `modules[demo].isEnabled` defaulting to true. This durable value is **Module enablement intent**, not health. An enabled Module can be failed; only an explicit disable changes the intent to false.
- Runtime transitions are serialized per Module. Start is limited to five seconds; stop is limited to two seconds; complete runtime shutdown is limited to five seconds. A timeout cancels known work, records a sanitized timeout failure, and never blocks App shell termination while pretending uncooperative work was fully cleaned up.
- Disable received while starting cancels startup, invokes stop exactly once, and ends stopped. Per-Module restart is permitted from running, suspended, or failed and follows stop then start. F7 performs no automatic retry; a failure remains failed until an explicit restart.
- A Module lifetime is supplied through Module context and owns registered tasks, observers, subscriptions, actions, surface contributions, sockets, and caches. Runtime revokes those registrations on stop or failure. Module code must not create untracked detached work.
- `restartRuntime()` is composition/test-only in F7. It stops enabled Modules in reverse registration order, creates fresh lifetimes, then starts enabled Modules in registration order. It is not a menu item, ActionID, or F7 user-facing recovery path; Settings exposes only per-Module restart.
- F7 adds a narrow internal **Module event publisher** and recording test implementation. It records declared lifecycle events and manual `demo.tick`; it is not EventBus, external EventEnvelope routing, transport, IPC, inter-Module delivery, buffering, ordering, or presentation policy.
- DemoModule registers typed descriptors only for `indicator` and `compactStatus`. NotchUI renders the two deterministic descriptors in the real Notch surface. Descriptor updates never force a surface transition. Expanded Module content, module-owned application scenes, and multi-Module slot arbitration are deferred.
- DemoModule offers `demo.ping` without confirmation in Debug/test builds and a Debug/test-only simulated-failure action. Neither has shortcut or IPC entry points. Release builds do not register DemoModule, do not expose its actions, and do not render it in Settings.
- Settings → Modules renders a read-only runtime health projection with display name, durable enablement intent, lifecycle state, last-start time, and sanitized last error. Its only F7 controls are Enable, Disable, and Restart. F7 adds no permission rows for DemoModule and no diagnostic history, export, or resource-metric interface.
- Produce and maintain a module-authoring guide plus a fillable module document template. They require purpose/non-goals, metadata, settings/secrets, slots, actions/events, permissions/privacy/security, failure/accessibility, lifetime ownership, diagnostics, and test evidence. They are validated against DemoModule but do not start M0 or prescribe copying DemoModule implementation.
- ADR-0016 governs supervision, bounded lifecycle, and durable enablement intent. ADR-0017 governs the Core/Domain contract boundary and Debug/test-only DemoModule packaging. Existing decisions on static modules, AppKit ownership, centralized permissions, performance bounds, and menu-bar recovery continue to apply.

## Testing Decisions

- The primary and highest test seam is the public **Module runtime** actor with injected fake Modules, clock/timeout control, Settings backend, Module lifetime/resource tracker, action registrar, surface-contribution registrar, diagnostics sink, and recording Module event publisher. Tests observe commands, health projections, registered resources, and externally visible descriptors—not private actor storage or SwiftUI bodies.
- Prefer the existing injectable-store and coordinator testing style: Settings persistence uses an injectable backend, Permission Coordinator uses an adapter/projection seam, and surface behavior uses fake controller/input seams. F7 adds no lower-level test hooks when an existing high-level boundary can express the behavior.
- Unit tests cover pure metadata and lifecycle state validation; registration; successful start; throw; start timeout; duplicate start/stop handling; explicit restart; suspension/resume; enablement intent; failure isolation; sanitized health; and no automatic retry.
- Lifecycle race tests cover Disable while starting, asserting cancellation, exactly one stop, stopped terminal state, no duplicate resource release, and unchanged health of unrelated Modules.
- Settings tests cover schema v2-to-v3 migration, default DemoModule enablement, persistence across relaunch, explicit disable persistence, a failed enabled Module retaining enabled intent, namespace isolation, corrupt/future snapshot behavior, and last-known-good preservation on failed write.
- Lifetime tests use a resource tracker/spy to prove tasks, timers, observers, subscriptions, action registrations, surface contributions, sockets, and caches are inactive after stop or failure. They must not infer cleanup only from process memory heuristics.
- Module-event tests use the recording publisher to assert manual `demo.tick` and declared lifecycle records. They must assert that F7 has no EventBus/IPC/external-envelope behavior.
- Action tests assert namespace ownership, Debug/test availability, no confirmation for `demo.ping`, no shortcut/IPC entry point, removal or unavailability after stop, and cancellation of running Module work on disable.
- Integration tests register DemoModule through the composition root, validate the indicator and compact-status descriptor path, disable/restart/fail it, and confirm Settings projection, core surface, and an unrelated test Module remain functional.
- Run a 100-cycle enable/disable/restart loop. Assert no growth in active resources, action registrations, event registrations, contributions, or bounded cache ownership. This is a behavioral cleanup test; a memory profile can complement but not replace it.
- UI tests observe Settings-facing health projection and controls for enabled, stopped, failed, and restartable states, including accessible labels and non-color-only status. They do not call Module methods from views.
- Native Debug QA on macOS records enable → indicator/compact status → disable → restart → simulated failure in the real Notch surface and Settings. It is separate from automated tests and does not close pending F2, F3, or F5 native evidence.
- Repository verification includes the established documentation/link checks, formatting/secret checks, package tests, and macOS build. The F7 evidence records which automated and native scenarios actually ran; no mock or build result substitutes for native evidence.

## Out of Scope

- Implementation of F7 itself; this ticket is the implementation-ready specification.
- Dynamic plugins, module discovery, independent module distribution, ABI stability, or runtime code loading.
- F8 EventBus, validated external EventEnvelope routing, inter-Module general subscriptions, ordering, deduplication, bounded event buffers, transport, local IPC, or `notchctl`.
- Automatic restart/backoff/reconnect policy for failed Modules.
- Real Module functionality, M0 Sample Status Module, Xiaozhi, Media, Clipboard, Files, Calendar, or System Controls.
- DemoModule capabilities, privacy prompts, secret storage, network connections, IPC endpoint, shortcut, global hotkey, or release-build UI.
- Multi-Module slot arbitration, priorities, indicator competition, expanded Module content, module-owned application scenes, and settings routes beyond the F7 Modules health/detail UI.
- A user-facing `app.restartRuntime` action, a menu-bar runtime restart control, F9 diagnostic history/export, or resource-metric UI.
- Closing or inferring the unresolved native manual gates for F2, F3, or F5.

## Further Notes

- The canonical vocabulary is **Module**, **Module runtime**, **Module lifetime**, **Module enablement intent**, **Module event publisher**, and **Surface contribution descriptor**.
- The specification is intentionally narrow: DemoModule proves the platform seam, not a product experience. Any future widening of metadata, retry, slot arbitration, permission policy, event routing, or diagnostics ownership requires an owning phase and, where cross-cutting, an ADR review.
- Existing working-tree changes are preserved. This spec and the adjacent F7 design documentation are planning artifacts; implementation work must preserve unrelated modifications and record actual evidence separately.
