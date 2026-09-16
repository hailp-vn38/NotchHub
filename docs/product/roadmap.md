# Product Roadmap
## NotchHub — Foundation-first delivery plan

**Status:** Draft v0.3
**Owner:** Product / Architecture  
**Last updated:** 2026-09-15
**Related documents:** [README](../../README.md), [Vision](vision.md), [Requirements](requirements.md), [Architecture Overview](../architecture/overview.md), [Testing Strategy](../quality/testing-strategy.md), [Performance](../architecture/performance.md)

---

## 1. Roadmap strategy

NotchHub follows a **foundation-first** roadmap.

The project will not begin by integrating Xiaozhi, media control, clipboard, files, calendar, system controls, or other business features. It begins by building a stable macOS base application that owns reusable concerns:

- Menu-bar application lifecycle and recovery path.
- Notch windowing and interaction behavior.
- Settings and configuration migration.
- Permissions and privacy UX.
- Keyboard shortcuts and a shared Action Registry.
- Module lifecycle, isolation, and health reporting.
- Versioned events, local IPC, validation, and security boundaries.
- Diagnostics, observability, performance budgets, and test infrastructure.

A module is added only after the foundation can host it without causing architectural rewrites. Xiaozhi is planned as one future **NX Native Xiaozhi Client** module, not as a shortcut around base-platform work.

## 2. Delivery principles

### Foundation before feature

Do not add a real integration merely to make the app feel “alive.” Use deterministic placeholders and `DemoModule` until settings, permissions, actions, lifecycle, event routing, diagnostics, and tests are ready.

### Vertical slices inside each phase

Each phase should deliver a small end-to-end behavior that can be launched, tested, inspected, and demonstrated. Avoid large branches that implement windowing, settings, and actions independently without integration.

### Contracts before implementations

Define public/internal contracts first:

- State and event model.
- Module lifecycle.
- Action input/output.
- Permission capability declarations.
- Settings namespace/schema.
- IPC request/response model.
- Resource/performance policy.

### Quality gates are hard gates

A later phase must not start if the earlier phase is only visually complete but unstable across macOS lifecycle events or lacks diagnostics/tests.

### Scope is deliberately narrow

The first implementation supports the built-in MacBook display only. Multi-display behavior, native voice/audio, arbitrary scripts, external dynamic plugins, and rich consumer widgets are deferred until core reliability is proven.

---

## 3. Timeline overview

| Phase | Estimated part-time duration | Objective | Primary deliverable |
|---|---:|---|---|
| F0 | 2–3 days | Bootstrap the repository and architectural contracts | Buildable project, docs, ADRs, CI |
| F1 | 3–5 days | Create reliable app shell and lifecycle ownership | Menu-bar-first app with recovery path |
| F2 | 1–2 weeks | Implement the Notch surface and interaction model | Stable `NSPanel` + state machine |
| F3 | 1 week | Establish design system and Settings information architecture | Consistent UI and settings shell |
| F4 | 3–5 days | Build typed settings/persistence/migration | Safe configuration layer |
| F5 | 1 week | Centralize privacy permissions | Permission Center and capability policy |
| F6 | 1 week | Build shared action and shortcut system | Action Registry + shortcut recorder |
| F7 | 3–5 days | Prove module boundaries | Module runtime + `DemoModule` |
| F8 | 1 week | Add event routing and local integration boundary | EventBus + authenticated local IPC + `notchctl` |
| F9 | 3–5 days | Make failures and resource behavior observable | Diagnostics panel and structured logging |
| F10 | 1–2 weeks | Stabilize, test, and profile the foundation | Foundation Completion Gate |
| M0 | 3–5 days | Validate real module contribution contracts | Sample Status Module |
| NX | Variable | Add the complete Native Xiaozhi Client | Direct bootstrap/WebSocket, voice, TTS, and bounded presentation state |
| M2 | 1–2 weeks | Validate a daily-use utility experience | Media or Clipboard module |
| M3 | 1–2 weeks | Add selected desktop utility interactions | Files or System Controls module |
| M4 | 1–2 weeks | Add productivity context | Calendar or Reminders module |
| M6 | Variable | Add future desktop modules after review | Reviewed module expansion |

**Expected foundation duration:** approximately 8–13 weeks of part-time work.  
**Expected timing of the first real Xiaozhi UI:** after the Foundation Completion Gate, during NX.

---

## 4. Foundation phases

## F0 — Bootstrap and architecture

### Goal

Create a codebase with explicit boundaries, repeatable builds, baseline documentation, and decisions that prevent early architectural drift.

**Status:** Complete. The local repository checks and green pull-request workflow are recorded in
[F0 evidence](../quality/f0-evidence.md). F1 is ready to implement.

### Scope

- Create Git repository and base branch/PR policy.
- Create macOS application target with minimum deployment target macOS 14.
- Create Swift package boundaries: `NotchDomain`, `NotchCore`, `NotchSurface`, `NotchUI`, `NotchActions`, `NotchIPC`.
- Enable an appropriate Swift 6 concurrency checking level.
- Create documentation tree and docs index.
- Add formatter/linter according to repository policy.
- Add CI workflow for dependency resolution, build, and unit tests.
- Define initial IDs, state types, event envelope, module contract, action contract, and error model.

### Required documentation

- `README.md`
- `docs/product/vision.md`
- `docs/product/roadmap.md`
- `docs/product/requirements.md`
- `docs/architecture/overview.md`
- `docs/architecture/performance.md`
- `docs/security/threat-model.md`
- `docs/development/setup.md`
- `docs/development/agent-instructions.md`
- `docs/references/boring-notch.md`
- Initial architecture ADRs

### Exit criteria

- A clean clone can build and test using documented commands.
- `NotchDomain` builds without importing SwiftUI or AppKit.
- CI runs for a pull request.
- At least one pure-domain test passes.
- Core boundaries and coding rules are documented.

### Explicit non-goals

- No notch panel behavior yet.
- No Xiaozhi or other real integration.
- No permission request.
- No IPC server.

---

## F1 — App shell and lifecycle

**Status:** Complete. F1 passed its automated and manual macOS gate; see [F1 evidence](../quality/f1-evidence.md).

### Goal

Create a reliable application entry point that remains usable even if the notch UI is hidden, suppressed, or temporarily unavailable.

### Scope

- Create menu-bar-first app shell using `MenuBarExtra` or a wrapper around `NSStatusItem`.
- Introduce `AppCoordinator` as composition and lifecycle owner.
- Define app lifecycle state and startup/shutdown ordering.
- Rely on the normal macOS app-bundle/LaunchServices path and make `AppCoordinator` startup
  idempotent; do not add a custom process lock or IPC handoff in F1.
- Add a thin launch-at-login abstraction backed by `SMAppService`; defer its preference UI and
  persistence to F3/F4.
- Observe launch, activation, deactivation, termination, sleep/wake, and lock/unlock states as needed.

### Demonstrable slice

The app launches as a menu-bar utility. Settings remains a separate, explicitly labelled
placeholder application scene and does not persist settings. Restart App Shell only restarts F1-owned
in-memory coordination; it is not the F7 `ModuleRuntime` restart.

### Exit criteria

- The app can quit cleanly without retained helper tasks or hanging services.
- Relaunch does not create duplicate state/instances.
- Sleep/wake does not crash the application.
- Settings and Diagnostics remain reachable independently of the Notch UI.

### Explicit non-goals

- No `NSPanel`, `NotchPanelController`, surface state machine, or display geometry (F2).
- No full Settings information architecture, typed persistence, or preference UI (F3/F4).
- No operational diagnostics store, export, or module/runtime inspection (F7/F9).
- No custom interprocess single-instance lock, local IPC listener, or second-launch handoff (F8).

---

## F2 — Notch surface shell

**Status:** Complete — see [F2 evidence](../quality/f2-evidence.md).

### Goal

Implement the core windowing and interaction behavior that every future module relies on.

### Scope

- Implement `NotchPanelController` as the sole owner of the native `NSPanel`.
- Add a SwiftUI host/root view.
- Add `ScreenTopology`, `NotchGeometry`, and built-in display selection.
- Implement Notch surface states: `hidden`, `collapsed`, `compact`, `expanded`, `suppressed`, `recovering`.
- Add an explicit navigation path from expanded content to a separate application scene/window; `detail` is not a Notch surface state.
- Implement hover zone, click, click-outside, Escape, auto-collapse, and configurable timeouts.
- Implement first-pass Spaces/full-screen/sleep-wake/display-change handling.
- Add click-through/hit-test policy when collapsed.
- Add debug overlay for state, target screen, computed frame, interaction flags, and window level.
- Use deterministic placeholder content only.

### Demonstrable slice

The notch surface opens and closes smoothly around the built-in display notch, responds to hover and Escape, and correctly returns to collapsed state after timeout/click-outside.

### Exit criteria

- Only `NotchPanelController` creates, orders, frames, or destroys `NSPanel`.
- Collapsed state does not unexpectedly block menu-bar interaction outside the panel region.
- Full-screen, Space switches, sleep/wake, and external display attach/detach do not crash the app.
- User can inspect panel geometry/state via debug overlay.
- State-machine unit tests cover all permitted transitions and major rejection cases.

---

## F3 — Design system and Settings UI shell

**Status:** Complete — see [F3 evidence](../quality/f3-evidence.md).

### Goal

Create a consistent visual language and Settings information architecture before feature modules introduce inconsistent views and preferences.

### Scope

- Add design tokens: theme mode, color/contrast, typography, spacing, corner radius, shadows/material policy, animation and reduced-motion policy.
- Add reusable components: action button, status pill, setting row, permission row, module row, shortcut recorder shell, empty/error/loading states.
- Build Settings navigation:

```text
General
Appearance
Notch Behavior
Shortcuts
Permissions
Actions
Modules
Diagnostics
About
```

- Add placeholder/dummy content where underlying capability is planned but not implemented.
- Implement keyboard navigation, accessible labels, focus behavior, and reduced-motion switch.

### Phase boundary

F3 implements the Settings shell and reusable presentation boundary only. A page whose domain
owner has not started shows an honest unavailable/placeholder state and must not create a
look-alike implementation. In particular, F3 does not persist preferences or run migrations
(F4), request permissions (F5), record/capture shortcuts or execute Actions (F6), start modules
(F7), or collect/export operational diagnostics (F9). A session-only preview is permitted only
when it is visibly described as resetting on relaunch.

### Exit criteria

- Settings views use common UI components/tokens rather than feature-specific styles.
- All current controls have labels and keyboard-accessible interaction paths.
- Reduced motion affects panel animation behavior.
- The Notch remains brief and readable.
- Opening a future-phase Settings route does not perform a future-phase side effect.

---

## F4 — Typed settings and persistence

### Goal

Make settings durable, safe to evolve, and independent from UI implementation details.

### Scope

- Implement typed `AppSettings` model with `schemaVersion`.
- Add only the F4 v1 Appearance and Notch Behavior settings: theme, Reduced Motion override,
  hover delay (`150`/`300`/`500` ms), and auto-collapse timeout (`2`/`3`/`5` seconds), plus the
  empty namespaced-module envelope owned by the platform. Full-screen suppression remains an
  invariant, not a setting, until another policy has native QA.
- Reserve no concrete Shortcut, Diagnostics, or module setting values: F6, F9, and F7 introduce
  those values with their owning behavior and versioned schema changes.
- Add defaults, validation, safe reset, migration, and corrupt-data fallback.
- Persist non-secret configuration with a storage abstraction.
- Use one versioned Application Support settings file behind the storage abstraction; write it by
  atomic replacement and debounce only high-frequency controls.
- Implement sanitized import/export of non-secret settings.
- Validate a complete F4-owned import, then atomically replace its Appearance and Notch Behavior
  settings; preserve newer unknown schemas in read-only recovery.
- Keep credentials and tokens out of settings; define Keychain boundary for later use.
- Implement the Settings-spec durable rows: validated toggle/preset updates, applying/rollback
  feedback, separate destructive reset scopes, and sanitized import/export summary.

### Exit criteria

- Settings persist across restart.
- Older schema migrates successfully in tests.
- Corrupt data falls back safely and exposes a typed recovery outcome without requiring F9 diagnostics persistence.
- Reset does not silently remove credentials or secrets.
- Settings UI does not read/write raw `UserDefaults` keys directly.

---

## F5 — Permission Center

**Status:** Complete — see [F5 evidence](../quality/f5-evidence.md).

### Goal

Centralize privacy permission discovery, explanation, request, denial handling, and capability availability.

### Scope

- Define `PermissionKind` and `PermissionStatus` contracts.
- Implement `PermissionCoordinator`.
- Add permission status refresh when app becomes active.
- Add Permission Center UI with capability description, reason, status, pre-permission explanation, system prompt trigger, and System Settings recovery path.
- Define a platform-level capability requirement and validate request context; F7 later connects it
  to live module metadata and lifecycle.
- Validate only Notifications, through an explicit Permission Center recovery-notification opt-in.
  Do not add a general background-notification policy or request Accessibility; Accessibility stays
  deferred to F6 if the selected shortcut approach actually requires it.
- Implement the Settings-spec permission groups and rows: friendly capability/status/reason,
  decline effect, and System Settings recovery without an open-page prompt.

### Policy

The base app must not ask for Camera, Microphone, Calendar, Reminders, Screen Recording, or Automation access at launch.

### Exit criteria

- No unsolicited permission prompt appears on first launch.
- A denied permission creates a clear usable UI state rather than a retry loop.
- The central coordinator is the only code allowed to request permissions.
- Permission changes after returning from System Settings are reflected in the app.
- Opening Settings, onboarding, app activation, and a Permissions-page refresh never prompt; only
  the explicit Notifications recovery opt-in may reach the system prompt in F5.

---

## F6 — Shared Actions and keyboard shortcuts

**Status:** Complete — see [F6 evidence](../quality/f6-evidence.md).

### Goal

Create one safe, typed action system for every entry point before introducing module actions or AI/voice interactions.

### Scope

- Define `ActionID`, `ActionDefinition`, input schema, result schema, availability rule, and confirmation policy.
- Implement `ActionRegistry`, Action Authorizer, and confirmation flow.
- Implement basic executors for internal actions and safe URL/app-opening actions.
- Add timeout, cancellation, result, and audit events.
- Add shortcut binding persistence and recorder UI.
- Add shortcut conflict checks and disabled capability state.
- Implement the Settings-spec Action and Shortcut rows, including availability reason, result,
  confirmation route, clear-binding behavior, and conflict feedback.
- Define the planned base-action ownership catalogue; do not register an Action until its owner
  can provide a complete executor, availability, confirmation, and audit contract:

```text
app.openSettings
app.openDiagnostics
app.restartRuntime
surface.showDemoStatus
surface.toggleDebugOverlay
settings.reset
```

Only `app.openSettings` is represented by the current menu item; Diagnostics
and development actions are registered for their owning application scenes or
development hooks, not exposed in `MenuBarExtra`.

### Exit criteria

- A registered action can be invoked from its permitted entry points through the same registry path.
- Before an action is registered, the shortcut framework shows no assignable action and retains
  any persisted unknown binding as unavailable.
- Entry points do not duplicate action business logic.
- Side-effecting actions use confirmation policy.
- Unknown/invalid Action IDs are rejected safely.
- No arbitrary shell command execution exists in the foundation.

---

## F7 — Module runtime and DemoModule

**Status:** Complete — see [F7 evidence](../quality/f7-evidence.md).

### Goal

Prove that the application is modular before any business module creates architectural pressure.

### Scope

- Implement compile-time static module registration at composition root.
- Implement lifecycle states: registered, starting, running, suspended, stopping, stopped, failed.
- Implement module enable/disable state and health reporting.
- Implement start/stop ordering and failure isolation.
- Add module settings namespace.
- Add module resource ownership: tasks, timers, observers, sockets, subscriptions, and caches must be disposed during `stop()`.
- Implement `DemoModule` with compact status, `demo.ping`, settings toggle, test event, and debug-only simulated failure.
- Implement the Settings-spec Modules list/detail from `ModuleRuntime` projections; opening a
  module page must not start a disabled module.

### Exit criteria

- A module can fail without crashing the core app.
- Disabled modules do not retain active timers, tasks, observers, sockets, or registered actions.
- Module state, version, last error, and last-start time appear in Diagnostics/Settings.
- Adding DemoModule does not require direct `NSPanel` access.

---

## F8 — EventBus, Presentation Policy, local IPC, and `notchctl`

### Goal

Create the validated data path used by future relays, scripts, tools, and modules.

### Scope

- Implement typed internal `AppEvent` model and EventBus actor.
- Implement versioned external `EventEnvelope v1` decoder.
- Add correlation IDs, source IDs, event type naming, validation, size limits, filtering, and event diagnostics.
- Add bounded buffers, coalescing, and backpressure metrics.
- Implement `PresentationPolicy` for informational, compact, progress, warning/error, user-triggered, and suppressed presentation.
- Implement authenticated HTTP server bound only to `127.0.0.1`; defer Unix socket and WebSocket until a concrete consumer justifies their separate lifecycle contracts.
- Add authenticated local endpoints:

```text
GET  /v1/health
GET  /v1/status
POST /v1/events
POST /v1/actions/{actionID}
```

- Authenticate every endpoint with a random Keychain-backed token and authorize only fixed F8 IPC sources (`notchctl` and the development-only injector).
- Accept only `system.testMessage` as F8 external event input; its sender cannot request a surface state or presentation level.
- Permit only `app.openSettings` through release IPC; development overlay control remains DEBUG-only.
- Implement random token handling and secret storage boundary.
- Create `notchctl` developer CLI.
- Project only bounded local IPC health/status/recovery information into Settings; no raw request,
  token, header, or payload is rendered there.

### Exit criteria

- Invalid token, schema, payload, event, and action are rejected safely.
- Event flood does not hang/crash the app; counters report coalesced/dropped events.
- Health endpoint reports surface, runtime, and IPC status.
- No IPC route accepts raw shell commands, raw scripts, arbitrary executable paths, or arbitrary executor configuration.

---

## F9 — Diagnostics and developer experience

### Goal

Make windowing, lifecycle, module, IPC, and performance failures understandable before real integrations make bugs harder to isolate.

### Scope

- Implement structured logging categories: lifecycle, windowing, interaction, settings, permissions, modules, events, actions, IPC, performance, diagnostics.
- Add Diagnostics panel with application, surface, module, permission, IPC, event/action, settings, logging, and performance sections.
- Add debug overlay and development feature flags.
- Add clear redaction rules.
- Implement the Settings-spec Diagnostics health, surface, module, permission, action, IPC,
  performance, and bounded sanitized export/recovery sections.

### Exit criteria

- A hidden/misplaced Notch surface can be diagnosed through display/frame/state output.
- Diagnostic export does not contain authorization headers, API keys, secret tokens, or unredacted sensitive payloads.
- Developers can identify high event rate, buffer pressure, and orphan resource indicators.

---

## F10 — Quality, profiling, and Foundation Completion Gate

### Goal

Stabilize the base platform and prove it can support modules without invisible lifecycle, performance, or security debt.

### Required tests

- Surface state machine, geometry, settings migration, permissions, actions, shortcuts, module runtime, EventBus, IPC, presentation policy, bounded buffers, and resource cleanup.
- Lifecycle QA: launch/relaunch, sleep/wake, lock/unlock, Space transitions, full-screen apps, menu-bar auto-hide, external display attach/detach, scale/resolution changes, lid close/open.
- Performance profiling: 8-hour idle run, 1,000 panel open/close cycles, event flood, text stream simulation, log flood, module toggle loop, and display/lifecycle stress.

### Foundation Completion Gate

All conditions must be satisfied before adding a real module:

- A new module can be added without editing `NotchPanelController`.
- A module can be disabled or fail without crashing/restarting the core app.
- UI has no direct dependency on integration protocols or business features.
- Settings are typed, versioned, migration-safe, and corrupt-data-safe.
- Permission prompts are centralized and on demand.
- Menu bar, Notch UI, shortcuts, and IPC invoke the same Action Registry.
- External IPC input is authenticated, validated, local-only by default, and rate-limited.
- There is no arbitrary shell execution path from IPC or future AI boundaries.
- Surface behavior survives required lifecycle/display tests.
- Diagnostics provide actionable evidence for state, windowing, module, IPC, and performance failures.
- Buffers, caches, event streams, and logs are bounded.
- Disabled modules clean up owned resources.
- Performance budgets are measured with no unbounded memory growth.
- CI, unit tests, integration tests, and manual QA pass.

---

## 5. Module delivery phases

## M0 — Sample Status Module

### Goal

Validate the module contribution API with a module that is more representative than `DemoModule` but still has no risky external dependency.

### Scope

- Contribute indicator, compact status, expanded content, and optional application scene through declared slots.
- Use settings namespace, action registration, event subscriptions, module diagnostics, and runtime resource policy.
- Verify UI placement conflict rules between multiple module contributions.

### Exit criteria

- Module UI contribution does not require changing surface/windowing code.
- Module can be enabled/disabled while the app runs.
- Its actions/events/settings/diagnostics obey all platform contracts.

---

## NX — Native Xiaozhi Client

### Goal

Deliver the complete direct Native Xiaozhi Client described in the module specification, without a preceding relay/display phase or a later native-voice phase.

### Scope

- Use direct bootstrap and authenticated WebSocket transport to the default Xiaozhi Cloud backend.
- Implement activation, session/hello lifecycle, microphone capture, bounded Opus pipelines, TTS playback, Auto and Push-to-Talk, abort, reconnect, sleep/wake recovery, and normalized presentation state.
- Keep raw protocol and high-rate audio outside NotchSurface and the shared EventBus; keep transcript in session memory only.
- Expose immediate conversation controls on the expanded Notch surface; use Settings and Diagnostics application scenes for durable configuration and detail.
- Use the central Permission Coordinator for contextual microphone access and the shared Settings store for namespaced non-secret Module settings.

### Explicit non-goals

- No relay dependency.
- No MCP, arbitrary remote execution, persistent transcript history, MQTT/UDP, wake word, realtime full duplex, or production AEC in the initial scope.
- No arbitrary tool execution from voice/AI.

### Exit criteria

- The MVP Definition of Done in the Native Xiaozhi Client specification passes, including real-backend acceptance, permission, sleep/wake, reconnect, bounded audio, and native macOS QA gates.
- Module respects CPU/RAM/event-rate budgets and can be disabled without retained resources.

---

## M2 — Media or Clipboard module

### Goal

Validate a daily-use general utility module and ensure the platform remains pleasant for non-developer workflows.

### Candidate A: Media

- Now-playing status.
- Play/pause/next/previous actions.
- Compact playback state.
- Optional artwork cache with strict resource cap.

### Candidate B: Clipboard

- Change observation.
- Bounded history.
- Copy/pin/delete actions.
- Privacy controls and sensitive-data handling policy.

### Selection criteria

Choose the module that provides the highest daily value with the least permission, compatibility, and API risk.

---

## M3 — Files or System Controls

### Goal

Add richer macOS interaction only after permission, lifecycle, resource management, and action boundaries have been proven through earlier modules.

### Candidate scope

- File drop shelf with bounded thumbnails/cache.
- System controls such as volume/brightness/output selection where supported through allowed APIs.
- Optional selected accessibility/automation integrations with contextual permission flow.

### Gate

Each capability must have a clear permission path, data retention policy, energy impact review, and failure/disabled state before implementation begins.

---

## M4 — Calendar or Reminders

### Goal

Add time-sensitive productivity context after the platform has proven its permission and privacy architecture.

### Candidate scope

- Upcoming calendar event summary.
- Reminder/task summary.
- Timer and focus-session state.
- Contextual action to open the relevant macOS app or application scene.

### Gate

Calendar/Reminders permissions must remain optional, requested contextually, and recoverable after denial.

---

## M6 — Future desktop modules

### Goal

Add further modules only after a documented review confirms user value, platform fit, privacy, performance, and compatibility.

### Required proposal

Every proposed module must include:

- Purpose and non-goals.
- Permission matrix.
- Settings schema.
- Event/action contract.
- Trust boundaries and threat-model update.
- Resource/performance policy.
- Retention/privacy policy.
- Test and diagnostics plan.
- ADR if it changes a durable architectural decision.


---

## 6. Cross-cutting milestones

### Documentation milestone

For every phase, update associated docs and ADRs in the same pull request as behavior changes. `docs/index.md` must remain the active documentation map.

### Security milestone

Before any integration accepts data from a non-local source, update the threat model and integration-specific security document. Do not expose a LAN listener without a reviewed authentication model.

### Performance milestone

Before enabling a high-frequency producer—audio meter, text stream, metrics sampler, clipboard watcher, file observer, or network feed—define maximum input rate, UI coalescing rate, memory cap, hidden/idle policy, cleanup behavior, and Instruments scenario.

### Accessibility milestone

Every new action/widget must add accessible label, keyboard path, disabled/error state, and reduced-motion behavior where animation is used.

---

## 7. Backlog rules

### Must have before NX

- All F0–F10 Foundation Completion Gate conditions.
- No unresolved critical windowing/lifecycle crash.
- Settings/permissions/actions/IPC diagnostics are functioning.
- Performance baseline recorded.

### Should have before beta

- Sanitized settings import/export.
- Launch-at-login implementation.
- Diagnostics export.
- Basic updater/signing/notarization plan.
- A stable second real module beyond Xiaozhi.

### Could have later

- Configurable multi-display placement.
- Advanced themes.
- Event replay tooling.
- External plugin bundles.
- Rich onboarding.
- Module marketplace.

### Will not be added without design review

- Private API dependency in core.
- Arbitrary scripting from an external request.
- Network listener exposed beyond loopback.
- Global event monitoring without a clear user benefit and privacy explanation.
- Unbounded logs, transcripts, cache, or event streams.

---

## 8. Risk register

| Risk | Impact | Mitigation | Decision point |
|---|---|---|---|
| `NSPanel` behavior differs across Spaces/full-screen/display changes | High | Surface state machine, debug overlay, manual QA matrix, reference Boring Notch behavior | F2/F10 |
| Scope creep from adding attractive widgets too early | High | Hard Foundation Completion Gate and explicit non-goals | Every phase |
| Settings become fragile as modules grow | Medium | Typed schema, versioned migrations, module namespaces | F4 |
| Permission prompts reduce trust | High | Permission Coordinator, on-demand prompts, clear denial recovery | F5 |
| Hotkey implementation requires unexpected permission/API behavior | Medium | Abstract shortcut service, capability availability UI, test early | F6 |
| AI/IPC becomes arbitrary command-execution path | Critical | Action allow-list, typed input, confirmation, loopback authentication | F6/F8/NX |
| Streaming text/audio causes high CPU/RAM | High | Coalescing, bounded buffers, per-module performance policy, Instruments tests | F8/NX |
| Module resource leaks in background | High | Runtime ownership and stop cleanup tests | F7/F10 |
| Multi-display adds disproportionate complexity | Medium | Built-in display first; delay full support | F2 onward |
| Private APIs compromise future stability/distribution | Medium/High | Public API-first; isolated helper only after ADR/review | Any future phase |
| Xiaozhi protocol/backend changes | Medium | Native transport/session boundary normalizes state before presentation | NX |

---

## 9. Definition of done

A roadmap item is done only when all relevant conditions are met:

- Implementation is merged.
- Acceptance criteria are demonstrably satisfied.
- Unit/integration/UI/manual tests appropriate to risk pass.
- Documentation is updated.
- Diagnostics/logging cover meaningful failures.
- Permission, security, privacy, accessibility, and performance implications are reviewed.
- No new unbounded task, timer, event stream, cache, or log has been introduced.
- Any durable architectural choice is captured in an ADR.

A feature is not done merely because it appears visually correct in one happy-path screen recording.

---

## 10. Next execution step

The immediate next step is **F2 — Notch surface shell**. Start from the closed F1 App shell and
introduce `NotchPanelController` as the sole native `NSPanel` owner, with its state machine and
F2-specific manual macOS verification.
