# Product Roadmap
## NotchHub — Foundation-first delivery plan

**Status:** Draft v0.3
**Owner:** Product / Architecture  
**Last updated:** 2026-09-14
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

A module is added only after the foundation can host it without causing architectural rewrites. Xiaozhi is planned as a future **M1 Display Companion** module, not as a shortcut around base-platform work.

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
| M1 | 1–2 weeks | Add Xiaozhi display integration only | Voice state and streaming text via relay |
| M2 | 1–2 weeks | Validate a daily-use utility experience | Media or Clipboard module |
| M3 | 1–2 weeks | Add selected desktop utility interactions | Files or System Controls module |
| M4 | 1–2 weeks | Add productivity context | Calendar or Reminders module |
| M5 | Variable | Add optional native Mac voice capability | Native Xiaozhi Voice module |
| M6 | Variable | Add future desktop modules after review | Reviewed module expansion |

**Expected foundation duration:** approximately 8–13 weeks of part-time work.  
**Expected timing of the first real Xiaozhi UI:** after the Foundation Completion Gate, usually not before M1.

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
- Implement menu items: Toggle Notch Surface, Show Demo State, Open Settings, Open Diagnostics, Restart App Shell, Quit.
- Introduce `AppCoordinator` as composition and lifecycle owner.
- Define app lifecycle state and startup/shutdown ordering.
- Rely on the normal macOS app-bundle/LaunchServices path and make `AppCoordinator` startup
  idempotent; do not add a custom process lock or IPC handoff in F1.
- Add a thin launch-at-login abstraction backed by `SMAppService`; defer its preference UI and
  persistence to F3/F4.
- Observe launch, activation, deactivation, termination, sleep/wake, and lock/unlock states as needed.

### Demonstrable slice

The app launches as a menu-bar utility. Settings and Diagnostics open as separate, explicitly
labelled placeholder windows; neither persists settings nor exposes operational diagnostics. Until
F2, Toggle Notch Surface and Show Demo State remain safe, visible recovery intents that report the
surface as unavailable rather than creating an `NSPanel`. Restart App Shell only restarts F1-owned
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

### Goal

Implement the core windowing and interaction behavior that every future module relies on.

### Scope

- Implement `NotchPanelController` as the sole owner of the native `NSPanel`.
- Add a SwiftUI host/root view.
- Add `ScreenTopology`, `NotchGeometry`, and built-in display selection.
- Implement Notch surface states: `hidden`, `collapsed`, `compact`, `expanded`, `suppressed`, `recovering`.
- Add an explicit navigation path from expanded content to a separate detail view/window; `detail` is not a Notch surface state.
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

### Exit criteria

- Settings views use common UI components/tokens rather than feature-specific styles.
- All current controls have labels and keyboard-accessible interaction paths.
- Reduced motion affects panel animation behavior.
- The Notch remains brief and readable.

---

## F4 — Typed settings and persistence

### Goal

Make settings durable, safe to evolve, and independent from UI implementation details.

### Scope

- Implement typed `AppSettings` model with `schemaVersion`.
- Add General, Appearance, Notch Behavior, Shortcut, Diagnostics, and namespaced module settings.
- Add defaults, validation, safe reset, migration, and corrupt-data fallback.
- Persist non-secret configuration with a storage abstraction.
- Add debounced/atomic writes where appropriate.
- Implement sanitized import/export of non-secret settings.
- Keep credentials and tokens out of settings; define Keychain boundary for later use.

### Exit criteria

- Settings persist across restart.
- Older schema migrates successfully in tests.
- Corrupt data falls back safely and writes a diagnostics warning.
- Reset does not silently remove credentials or secrets.
- Settings UI does not read/write raw `UserDefaults` keys directly.

---

## F5 — Permission Center

### Goal

Centralize privacy permission discovery, explanation, request, denial handling, and capability availability.

### Scope

- Define `PermissionKind` and `PermissionStatus` contracts.
- Implement `PermissionCoordinator`.
- Add permission status refresh when app becomes active.
- Add Permission Center UI with capability description, reason, status, pre-permission explanation, system prompt trigger, and System Settings recovery path.
- Support capability declarations from modules.
- Test with Notifications and only request Accessibility when a selected shortcut approach truly requires it.

### Policy

The base app must not ask for Camera, Microphone, Calendar, Reminders, Screen Recording, or Automation access at launch.

### Exit criteria

- No unsolicited permission prompt appears on first launch.
- A denied permission creates a clear usable UI state rather than a retry loop.
- The central coordinator is the only code allowed to request permissions.
- Permission changes after returning from System Settings are reflected in the app.

---

## F6 — Shared Actions and keyboard shortcuts

### Goal

Create one safe, typed action system for every entry point before introducing module actions or AI/voice interactions.

### Scope

- Define `ActionID`, `ActionDefinition`, input schema, result schema, availability rule, and confirmation policy.
- Implement `ActionRegistry`, Action Authorizer, and confirmation flow.
- Implement basic executors for internal actions and safe URL/app-opening actions.
- Add timeout, cancellation, result, and audit events.
- Add shortcut binding persistence and recorder UI.
- Add shortcut conflict checks and disabled capability state.
- Register base actions:

```text
app.toggleSurface
app.openSettings
app.openDiagnostics
app.restartRuntime
surface.showDemoStatus
surface.toggleDebugOverlay
settings.reset
```

### Exit criteria

- The same action can be invoked from menu bar, Notch button, shortcut, and internal test command.
- Entry points do not duplicate action business logic.
- Side-effecting actions use confirmation policy.
- Unknown/invalid Action IDs are rejected safely.
- No arbitrary shell command execution exists in the foundation.

---

## F7 — Module runtime and DemoModule

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
- Implement local Unix socket and/or loopback HTTP server.
- Add authenticated local endpoints:

```text
GET  /v1/health
GET  /v1/status
POST /v1/events
POST /v1/actions/{actionID}
WS   /v1/stream
```

- Bind listeners to `127.0.0.1` only; do not expose LAN endpoints.
- Implement random token handling and secret storage boundary.
- Create `notchctl` developer CLI.

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

- Contribute indicator, compact status, expanded content, and optional detail view through declared slots.
- Use settings namespace, action registration, event subscriptions, module diagnostics, and runtime resource policy.
- Verify UI placement conflict rules between multiple module contributions.

### Exit criteria

- Module UI contribution does not require changing surface/windowing code.
- Module can be enabled/disabled while the app runs.
- Its actions/events/settings/diagnostics obey all platform contracts.

---

## M1 — Xiaozhi Display Companion

### Goal

Show Xiaozhi voice/AI session state and streamed text without adding native Mac microphone, raw audio, or direct coupling to Xiaozhi protocol into the Notch surface.

### Scope

- Create a relay or adapter that transforms Xiaozhi protocol/events into `EventEnvelope v1`.
- Display states: disconnected, idle, listening, thinking, speaking, error.
- Display partial/final user and assistant transcript in compact/expanded contexts, with full content in a separately opened detail window.
- Add transcript assembler with sequence/correlation/session handling.
- Coalesce UI text updates to approximately 20–30 flushes per second.
- Add registered actions where backend support exists: reconnect, stop, mute.
- Use detail window for full transcript; keep Notch view short.

### Explicit non-goals

- No Mac microphone input.
- No direct raw WebSocket/audio/Opus decoding inside `NotchSurface`.
- No unbounded transcript persistence.
- No arbitrary tool execution from voice/AI.

### Exit criteria

- Disconnect/reconnect behavior is observable and safe.
- Streamed text remains smooth with Vietnamese Unicode content.
- Long transcripts are bounded and move to detail UI.
- Module respects CPU/RAM/event-rate budgets.

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
- Contextual action to open the relevant macOS app or detail view.

### Gate

Calendar/Reminders permissions must remain optional, requested contextually, and recoverable after denial.

---

## M5 — Native Xiaozhi Voice

### Goal

Optionally make the Mac app an active voice endpoint after the display companion integration is stable and justified.

### Scope, if approved

- Mac microphone permission flow.
- Audio input/output device selection.
- Audio session lifecycle.
- Level meter/waveform with bounded update rate.
- Streaming protocol adapter.
- Echo cancellation/device switching/error recovery considerations.
- Explicit transcript/privacy retention settings.

### Gate

Begin only after M1 proves that user value requires native Mac audio. This phase has materially higher permission, performance, audio, and compatibility complexity.

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

### Must have before M1

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
| AI/IPC becomes arbitrary command-execution path | Critical | Action allow-list, typed input, confirmation, loopback authentication | F6/F8/M1 |
| Streaming text/audio causes high CPU/RAM | High | Coalescing, bounded buffers, per-module performance policy, Instruments tests | F8/M1/M5 |
| Module resource leaks in background | High | Runtime ownership and stop cleanup tests | F7/F10 |
| Multi-display adds disproportionate complexity | Medium | Built-in display first; delay full support | F2 onward |
| Private APIs compromise future stability/distribution | Medium/High | Public API-first; isolated helper only after ADR/review | Any future phase |
| Xiaozhi protocol/backend changes | Medium | Adapter/relay normalizes into stable EventEnvelope | M1 |

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
