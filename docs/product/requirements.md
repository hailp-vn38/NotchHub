# Product Requirements Document
## NotchHub — Modular macOS Notch Platform

**Status:** Draft v0.2  
**Owner:** Product / Architecture  
**Last updated:** 2026-09-14
**Related documents:** [README](../../README.md), [Vision](vision.md), [Roadmap](roadmap.md), [Architecture Overview](../architecture/overview.md), [Notch Surface](../architecture/notch-surface.md), [Action Platform](../architecture/action-platform.md), [Performance](../architecture/performance.md), [Threat Model](../security/threat-model.md)

---

## 1. Purpose

This document defines the functional and non-functional requirements for NotchHub, a modular, local-first macOS Notch Platform.

NotchHub provides a reliable interaction surface around a MacBook notch for short-lived status, quick actions, and future desktop productivity modules. The platform is intentionally developed in a **foundation-first** order: the core application must establish windowing, interaction, settings, permissions, shortcuts, actions, module runtime, IPC, diagnostics, security, and performance behavior before real business modules such as Xiaozhi, media, clipboard, files, calendar, or system controls are added.


---

## 2. Scope

### 2.1 In scope: Foundation platform

- Menu-bar-first macOS application shell.
- Notch surface using AppKit `NSPanel` with SwiftUI presentation.
- Defined surface states and interaction behavior.
- Settings UI, typed persistence, schema migration, reset, and sanitized import/export.
- Permission Center and on-demand permission coordination.
- Action Registry shared by UI, menu bar, shortcuts, local IPC, and future AI integrations.
- Keyboard shortcut registration, recording, validation, and availability behavior.
- Compile-time static module runtime and a test-oriented `DemoModule`.
- Versioned external event contract, internal EventBus, and presentation policy.
- Local IPC via Unix domain socket and/or loopback HTTP/WebSocket.
- Authentication, validation, rate limiting, and security boundaries for external input.
- Structured logging, diagnostics, debug tools, resource counters, and sanitized report export.
- Performance and energy policies, bounded data streams, and profiling test plans.
- Automated and manual test infrastructure.

### 2.2 Out of scope: Foundation platform

- Xiaozhi protocol, relay, voice session display, microphone capture, audio encoding/decoding, TTS, or waveform.
- Media playback control.
- Clipboard history.
- File shelf, AirDrop integration, thumbnails, or drag-and-drop workflow.
- Calendar, Reminders, Camera, Screen Recording, OCR, or screen-context features.
- Dynamic loading of third-party executable plugins.
- A LAN-accessible HTTP/WebSocket API.
- Arbitrary shell/script execution through UI, IPC, voice, AI, or external data.
- Complete multi-display placement/interaction support.
- Private macOS APIs as a core dependency.
- Mac App Store release implementation.

### 2.3 Permanently excluded product scope

The following are excluded from NotchHub, not merely postponed:


Any proposal to include a permanently excluded area requires a new product decision outside the current NotchHub scope, not a normal feature request.

### 2.4 Future module scope

After the Foundation Completion Gate, future modules may be added in this tentative sequence:

1. Sample Status Module (M0).
2. Xiaozhi Display Companion (M1).
3. Media or Clipboard (M2).
4. Files or System Controls (M3).
5. Calendar or Reminders (M4).
6. Optional Native Xiaozhi Voice (M5).
7. Other reviewed desktop productivity modules (M6).

Every module remains subject to the same requirements for lifecycle, settings, permission, security, performance, accessibility, diagnostics, and testing.

---

## 3. Definitions

| Term | Definition |
|---|---|
| Notch surface | The `NSPanel` rendered around the MacBook camera housing/notch, including collapsed, compact, and expanded presentation. |
| application scene | A separate user-requested window/scene for long-form module content, history, transcripts, or configuration; it is not a Notch surface state. |
| Base platform / Foundation | The reusable application infrastructure built before real business modules. |
| Module | A compile-time feature unit implementing the `NotchModule` contract and using platform capabilities. |
| Module runtime | The component that registers, starts, stops, enables, disables, isolates, and reports health for modules. |
| Action | A registered typed operation identified by `ActionID`, callable from UI, shortcut, IPC, or future AI. |
| Event | A versioned message representing a state change, progress update, status, or result. |
| Event envelope | External JSON/serialized wrapper containing ID, version, source, type, timestamp, correlation ID, and payload. |
| Presentation policy | Core rules deciding whether an event changes Notch UI state and how intrusive that presentation may be. |
| Permission capability | A system access category such as Accessibility, Microphone, Notifications, Camera, Calendar, or Screen Recording. |
| Local IPC | Unix socket and/or HTTP/WebSocket bound only to loopback for interaction with local scripts/tools. |
| Built-in display | The MacBook’s integrated display, which is the only mandatory target in the initial product scope. |
| Bounded buffer | A collection with explicit maximum count and/or byte size, dropping/rotating/coalescing data rather than growing indefinitely. |

---

## 4. User requirements

### UR-001 — Quiet default behavior

The user shall be able to keep NotchHub running without a permanently expanded dashboard or disruptive visual activity.

**Acceptance criteria**

- With no active interaction or high-priority event, the always-on surface is collapsed or minimally indicated; lifecycle policy may suppress or hide it operationally.
- The app does not play sounds, open windows, or request permissions at launch without an explicit user action.
- Low-priority events do not automatically obscure active work.

### UR-002 — Fast access to the surface

The always-on Notch surface shall respond to hover and click interaction when
available; menu bar and shortcuts do not control its visibility.

**Acceptance criteria**

- Hover/click behavior is configurable where technically appropriate.
- A default shortcut is supplied and can be changed or disabled.
- The menu bar can always reveal or hide the surface.
- Escape and click-outside behavior are predictable and documented.

### UR-003 — Clear settings

The user shall be able to configure appearance, Notch behavior, shortcuts, modules, actions, permissions, diagnostics, and reset behavior in a coherent Settings interface.

**Acceptance criteria**

- Settings are organized into named sections.
- Each setting has a default value and validation behavior.
- Settings survive app restart.
- Reset behavior is explicit and does not silently erase secrets.

### UR-004 — Transparent permissions

The user shall understand why a permission is needed, when it will be requested, and what happens if it is denied.

**Acceptance criteria**

- No privacy-sensitive permission appears at first launch merely because a future module might use it.
- Before a system prompt, the app provides a contextual explanation.
- When denied, the app provides a non-blocking recovery path to System Settings.
- The user can inspect permission status in one central location.

### UR-005 — Safe actions

The user shall have confidence that actions invoked through UI, shortcuts, local tooling, or future AI integrations are known, inspectable, and appropriately confirmed.

**Acceptance criteria**

- Every operation has a registered `ActionID`.
- The app rejects unknown actions and invalid inputs.
- Side-effecting/destructive actions use a defined confirmation policy.
- The user can see action title, availability, and recent result/error in appropriate UI or diagnostics.

### UR-006 — Reliable module control

The user shall be able to enable, disable, inspect, and recover modules without destabilizing the base app.

**Acceptance criteria**

- A module can be disabled without restarting the app where technically feasible.
- A module failure does not crash the application core.
- Module health and last error are visible in Diagnostics.
- Disabled modules do not continue background work.

### UR-007 — Privacy-aware local integration

The user shall be able to use local scripts/tools with NotchHub without exposing an unauthenticated control service to the LAN.

**Acceptance criteria**

- Default IPC binding is Unix domain socket and/or `127.0.0.1`.
- Requests require authentication where an HTTP/WebSocket API is enabled.
- Invalid, oversized, or rate-limited requests are rejected.
- The app does not accept arbitrary command strings from IPC.

### UR-008 — Understandable failures

The user shall be able to inspect basic diagnostics when the surface, a module, IPC, an action, or a permission does not work.

**Acceptance criteria**

- Diagnostics show surface state, target display, module health, permission status, recent errors, and IPC status.
- A sanitized diagnostics report can be copied/exported.
- Secrets and authorization material are redacted.

### UR-009 — Efficient all-day operation

The user shall be able to leave NotchHub running through a workday without unreasonable CPU, memory, battery, or thermal impact.

**Acceptance criteria**

- Idle resource targets are defined and measured.
- The application has no unbounded logs, event queues, caches, transcripts, or process outputs.
- Disabled modules release background work.
- High-rate data is throttled/coalesced before it reaches UI presentation.

### UR-010 — Accessible interaction

The user shall be able to interact with core UI through keyboard and accessibility technologies and reduce motion if desired.

**Acceptance criteria**

- Interactive controls have accessibility labels.
- Core commands have keyboard paths through menu/shortcut/focus navigation.
- Important state is not conveyed by color alone.
- Reduced Motion changes continuous/large animation behavior.

---

## 5. Functional requirements

## 5.1 Application shell and lifecycle

| ID | Requirement | Priority |
|---|---|---|
| FR-APP-001 | The app shall run as a menu-bar-first macOS utility. | Must |
| FR-APP-002 | The app shall provide a menu-bar recovery/control path independent of the Notch surface. | Must |
| FR-APP-003 | The menu shall provide exactly Settings, Restart App Shell, and Quit. Diagnostics and development actions are not exposed in the menu bar. | Must |
| FR-APP-004 | The app shall maintain a defined startup and shutdown sequence. | Must |
| FR-APP-005 | The app shall use normal macOS app-bundle/LaunchServices behavior and idempotent `AppCoordinator` startup to safely handle duplicate launch delivery. A custom lock or IPC handoff is deferred until an owned endpoint exists. | Must |
| FR-APP-006 | The app shall safely respond to sleep/wake and application activation changes without creating a surface or requesting permissions in F1. | Must |
| FR-APP-007 | The app shall provide an `SMAppService`-backed launch-at-login abstraction. Its user-facing preference and persistence are deferred until F3/F4. | Should |
| FR-APP-008 | The app shall retain enough state to recover safely after a temporary display/panel invalidation. | Must |

## 5.2 Notch surface and windowing

| ID | Requirement | Priority |
|---|---|---|
| FR-SUR-001 | The app shall own Notch presentation through a single `NotchPanelController`. | Must |
| FR-SUR-002 | The controller shall be the only component allowed to create, show, hide, frame, order, or destroy the native `NSPanel`. | Must |
| FR-SUR-003 | The surface shall support `hidden`, `collapsed`, `compact`, `expanded`, `suppressed`, and `recovering` states. | Must |
| FR-SUR-004 | The surface shall support a built-in-display-first placement policy. | Must |
| FR-SUR-005 | The app shall provide a safe top-center fallback layout if no physical notch geometry is available. | Must |
| FR-SUR-006 | The surface shall support hover, click, click-outside, Escape, auto-collapse, and menu/shortcut-triggered transitions. | Must |
| FR-SUR-007 | Collapsed interaction regions shall avoid unintentionally blocking unrelated menu-bar/application interaction. | Must |
| FR-SUR-008 | The app shall handle display topology changes, full-screen/Space changes, and sleep/wake without crash. | Must |
| FR-SUR-009 | The app shall expose a development-only debug overlay with state, screen, frame, and window details. | Should |
| FR-SUR-010 | The app shall not claim full multi-display placement support in the foundation release. | Must |

### Surface transition requirements

- Only approved transitions in the state machine are permitted.
- Invalid or duplicate transitions are ignored or logged, not treated as fatal.
- High-priority user interaction overrides auto-collapse.
- Suppression reason must be observable in Diagnostics.
- Recovering state must converge to a stable visible/hidden state without endless retries.

## 5.3 Settings and configuration

| ID | Requirement | Priority |
|---|---|---|
| FR-SET-001 | The app shall provide Settings sections: General, Appearance, Notch Behavior, Shortcuts, Permissions, Actions, Modules, Diagnostics, and About. | Must |
| FR-SET-002 | The app shall use a typed settings model, not direct scattered raw preference keys in UI views. | Must |
| FR-SET-003 | Settings shall include a schema version and migration path. | Must |
| FR-SET-004 | Every setting shall have defaults, validation, and defined reset behavior. | Must |
| FR-SET-005 | The app shall persist non-secret settings across restarts. | Must |
| FR-SET-006 | The app shall recover from corrupt settings by using safe defaults and emitting diagnostics. | Must |
| FR-SET-007 | The app shall provide sanitized import/export of non-secret configuration. | Should |
| FR-SET-008 | Credentials, authentication tokens, and other secrets shall not be stored in ordinary settings. | Must |
| FR-SET-009 | Module settings shall be namespaced by `ModuleID`. | Must |
| FR-SET-010 | Runtime-safe behavior/appearance setting changes shall apply without app restart where feasible. | Should |

## 5.4 Permissions

| ID | Requirement | Priority |
|---|---|---|
| FR-PERM-001 | The app shall centralize permission checks and requests in a `PermissionCoordinator`. | Must |
| FR-PERM-002 | Modules shall declare required capabilities but shall not directly issue permission requests. | Must |
| FR-PERM-003 | Permission status shall support not determined, authorized, denied, restricted, and unavailable states where applicable. | Must |
| FR-PERM-004 | The app shall show a contextual pre-permission explanation before a system prompt. | Must |
| FR-PERM-005 | The app shall not prompt for permissions at first launch unless the user explicitly initiates an associated feature. | Must |
| FR-PERM-006 | The app shall provide an actionable recovery path when a permission is denied. | Must |
| FR-PERM-007 | The app shall refresh relevant permission status after returning from System Settings/app activation. | Must |
| FR-PERM-008 | The app shall document module-to-permission relationships. | Must |

## 5.5 Actions and shortcuts

| ID | Requirement | Priority |
|---|---|---|
| FR-ACT-001 | Every executable operation shall be represented by a registered typed `ActionID`. | Must |
| FR-ACT-002 | Action definitions shall declare title, category, icon, availability, input schema, confirmation policy, and executor type. | Must |
| FR-ACT-003 | The same action shall be invocable through menu bar, Notch UI, shortcut, and local IPC where allowed. | Must |
| FR-ACT-004 | The Action Registry shall validate action input before execution. | Must |
| FR-ACT-005 | The Action Registry shall reject unknown actions. | Must |
| FR-ACT-006 | Action execution shall support result, error, cancellation, and timeout outcomes. | Must |
| FR-ACT-007 | Side-effecting/destructive actions shall require confirmation according to policy. | Must |
| FR-ACT-008 | The app shall record sanitized action audit events for Diagnostics. | Must |
| FR-ACT-009 | The app shall provide shortcut recording, persistence, enable/disable, and conflict validation. | Must |
| FR-ACT-010 | Default shortcuts shall be conservative and configurable. | Must |
| FR-ACT-011 | A shortcut shall become unavailable/disabled when required capability/permission is unavailable. | Should |
| FR-ACT-012 | Foundation actions shall not expose arbitrary shell/script execution. | Must |

### Minimum foundation actions

```text
app.openSettings
app.openDiagnostics
app.restartRuntime
surface.showDemoStatus
surface.toggleDebugOverlay
settings.reset
demo.ping
```

## 5.6 Module runtime

| ID | Requirement | Priority |
|---|---|---|
| FR-MOD-001 | The app shall support compile-time static module registration. | Must |
| FR-MOD-002 | Each module shall implement the `NotchModule` contract. | Must |
| FR-MOD-003 | The runtime shall manage registered, starting, running, suspended, stopping, stopped, and failed states. | Must |
| FR-MOD-004 | The runtime shall allow enabling/disabling a module through settings where supported. | Must |
| FR-MOD-005 | A failed module shall not crash the core app or unrelated modules. | Must |
| FR-MOD-006 | The runtime shall report module version, state, last start time, last error, and enabled status. | Must |
| FR-MOD-007 | Modules shall declare UI slots, required permissions, actions, settings namespace, and resource policy through metadata/contracts. | Must |
| FR-MOD-008 | Modules shall not directly manipulate the native Notch panel. | Must |
| FR-MOD-009 | Module stop/disable shall cancel/release owned tasks, timers, observers, sockets, subscriptions, and caches. | Must |
| FR-MOD-010 | The foundation shall include a `DemoModule` to validate contracts and failure isolation. | Must |
| FR-MOD-011 | Dynamic executable plugin loading shall not be included before module contracts are proven stable. | Must |

## 5.7 Event system and presentation policy

| ID | Requirement | Priority |
|---|---|---|
| FR-EVT-001 | The app shall provide a typed internal event model and EventBus. | Must |
| FR-EVT-002 | External events shall use a versioned `EventEnvelope`. | Must |
| FR-EVT-003 | External events shall include ID, version, source, type, timestamp, optional correlation ID, and payload. | Must |
| FR-EVT-004 | The event router shall validate schemas before publishing events internally. | Must |
| FR-EVT-005 | The system shall support event source/type filtering and diagnostics. | Should |
| FR-EVT-006 | The EventBus shall apply bounded buffering/backpressure behavior. | Must |
| FR-EVT-007 | High-rate events shall support coalescing/throttling before presentation state updates. | Must |
| FR-EVT-008 | A core Presentation Policy shall determine whether events alter Notch surface presentation. | Must |
| FR-EVT-009 | Modules shall not directly force surface expansion merely by receiving/emitting an event. | Must |
| FR-EVT-010 | The app shall collect counters for rejected, dropped, and coalesced events. | Must |

## 5.8 Local IPC

| ID | Requirement | Priority |
|---|---|---|
| FR-IPC-001 | The app shall provide a local integration boundary before any LAN API is considered. | Must |
| FR-IPC-002 | IPC shall use a Unix domain socket and/or a loopback-only HTTP/WebSocket listener. | Must |
| FR-IPC-003 | Network listener binding shall default to `127.0.0.1`, not `0.0.0.0`. | Must |
| FR-IPC-004 | The app shall expose health/status endpoints or equivalent commands. | Must |
| FR-IPC-005 | The app shall accept validated external events. | Must |
| FR-IPC-006 | The app shall optionally accept registered actions through IPC when authorization/policy permits. | Must |
| FR-IPC-007 | IPC requests shall be authenticated with a non-hardcoded secret/token where HTTP/WebSocket is used. | Must |
| FR-IPC-008 | IPC shall enforce request size limits, schema validation, timeout behavior, and rate limiting. | Must |
| FR-IPC-009 | IPC requests shall not carry arbitrary shell commands, executable paths, or executor configuration. | Must |
| FR-IPC-010 | The project shall provide a local `notchctl` CLI for health, status, test events, and registered actions. | Should |

### Suggested IPC v1 surface

```text
GET  /v1/health
GET  /v1/status
POST /v1/events
POST /v1/actions/{actionID}
WS   /v1/stream
```

Exact transport and endpoint formats may evolve, but the local-only, authenticated, validated boundary is mandatory. IPC is for desktop app integrations and future assistant relays.

## 5.9 Diagnostics and logging

| ID | Requirement | Priority |
|---|---|---|
| FR-DIAG-001 | The app shall use structured logging categories for lifecycle, surface, settings, permissions, modules, events, actions, IPC, performance, and diagnostics. | Must |
| FR-DIAG-002 | The app shall provide a Diagnostics UI. | Must |
| FR-DIAG-003 | Diagnostics shall show application version/build/uptime and core initialization status. | Must |
| FR-DIAG-004 | Diagnostics shall show surface state, selected display, calculated frame, window level, and suppression reason. | Must |
| FR-DIAG-005 | Diagnostics shall show module state/health/errors. | Must |
| FR-DIAG-006 | Diagnostics shall show permission status. | Must |
| FR-DIAG-007 | Diagnostics shall show IPC status and rejected request counters. | Must |
| FR-DIAG-008 | Diagnostics shall show recent sanitized events/actions and resource metrics. | Must |
| FR-DIAG-009 | The app shall support sanitized diagnostic report copy/export. | Must |
| FR-DIAG-010 | Logs and reports shall redact secrets, tokens, authorization headers, and sensitive raw payloads. | Must |
| FR-DIAG-011 | Development builds shall support a debug overlay and test event injection. | Should |

---

## 6. Non-functional requirements

## 6.1 Compatibility

| ID | Requirement | Priority |
|---|---|---|
| NFR-COMP-001 | The minimum supported operating system shall be macOS 14 Sonoma. | Must |
| NFR-COMP-002 | The implementation shall use Swift 6 and Swift Concurrency-compatible design. | Must |
| NFR-COMP-003 | SwiftUI shall be used for UI, with AppKit used where native window/input behavior requires it. | Must |
| NFR-COMP-004 | The foundation must support the built-in MacBook display. | Must |
| NFR-COMP-005 | A no-physical-notch fallback layout shall be supported. | Must |
| NFR-COMP-006 | Full external multi-display feature parity is deferred. | Must |
| NFR-COMP-007 | The core architecture shall use public macOS APIs first. | Must |

## 6.2 Reliability and recovery

| ID | Requirement | Priority |
|---|---|---|
| NFR-REL-001 | The app shall not crash due to a single module start/stop/handler failure. | Must |
| NFR-REL-002 | The app shall recover from a display configuration change or invalidated panel to a stable state. | Must |
| NFR-REL-003 | The app shall tolerate malformed/unknown external input without crash. | Must |
| NFR-REL-004 | The app shall tolerate denied/unavailable permission without retry loops. | Must |
| NFR-REL-005 | The app shall cancel owned background tasks on shutdown/module disable. | Must |
| NFR-REL-006 | Settings corruption shall not prevent application startup. | Must |
| NFR-REL-007 | IPC failures shall not prevent the local UI/app from working. | Must |

## 6.3 Performance and responsiveness

### Performance budgets

| Scenario | CPU target | Memory target | Responsiveness target |
|---|---:|---:|---|
| Idle, Notch collapsed | < 0.3% average | 40–80 MB | No continuous visual work or fast polling |
| Expanded, no high-rate stream | < 1–2% | 60–120 MB | Open/expand under 150 ms under normal load |
| Local compact event | Brief spike < 5% | No unbounded growth | Event-to-UI under 100 ms under normal load |
| Future streamed text | 1–5% average | < 150 MB | Delta-to-UI under 100–150 ms after coalescing |
| Future audio meter | 1–3% additional | Minimal added footprint | 15–30 FPS while active only |

| ID | Requirement | Priority |
|---|---|---|
| NFR-PERF-001 | Heavy I/O, parsing, process work, file scanning, audio processing, and persistence shall not run on the main actor. | Must |
| NFR-PERF-002 | The UI shall receive snapshots/DTOs rather than raw high-rate data streams. | Must |
| NFR-PERF-003 | High-rate presentation updates shall be coalesced/throttled. | Must |
| NFR-PERF-004 | The app shall not have a continuous render loop when surface/module state does not require it. | Must |
| NFR-PERF-005 | Timers shall be suspended, slowed, or given tolerance while hidden/idle as applicable. | Must |
| NFR-PERF-006 | Modules shall declare idle/hidden/visible refresh policy, max event rate, memory budget, and cleanup ownership. | Must |
| NFR-PERF-007 | Bounded buffers shall be used for events, logs, process output, future transcript data, and caches. | Must |
| NFR-PERF-008 | Disabled modules shall release owned resource usage. | Must |
| NFR-PERF-009 | The app shall expose relevant performance counters in Diagnostics. | Must |
| NFR-PERF-010 | Foundation release shall include performance stress/profiling scenarios. | Must |

### Buffer and data limits

Every stream must have a documented cap. Initial planning guidance:

| Data type | Planning cap |
|---|---|
| Sanitized event history | 500–2,000 events |
| Future general operation log | 2,000–10,000 lines or 2–8 MB, whichever comes first |
| Future transcript in memory | 50–200 messages or 1–5 MB |
| Future thumbnail cache | LRU cache with explicit byte budget |
| External text payloads | Bounded chunks/lines; no global infinite string accumulation |

## 6.4 Energy efficiency

| ID | Requirement | Priority |
|---|---|---|
| NFR-ENG-001 | The app shall minimize background wakeups during idle/collapsed state. | Must |
| NFR-ENG-002 | The app shall prefer event-driven updates over frequent polling. | Must |
| NFR-ENG-003 | Network reconnect behavior shall use bounded exponential backoff. | Must |
| NFR-ENG-004 | Continuous animation/visualizer behavior shall run only while visible and useful. | Must |
| NFR-ENG-005 | The app shall batch/debounce non-urgent settings/log writes. | Must |
| NFR-ENG-006 | The app shall support reduced activity under thermal pressure or low-power policy where feasible. | Should |
| NFR-ENG-007 | Energy impact shall be measured during Foundation Completion Gate profiling. | Must |

## 6.5 Security and privacy

| ID | Requirement | Priority |
|---|---|---|
| NFR-SEC-001 | External input shall be considered untrusted until validated. | Must |
| NFR-SEC-002 | The app shall not execute arbitrary shell commands supplied by external input. | Must |
| NFR-SEC-003 | IPC services shall bind to local-only interfaces by default. | Must |
| NFR-SEC-004 | IPC authentication secrets shall not be hardcoded. | Must |
| NFR-SEC-005 | Secrets shall be stored in Keychain or equivalent secure storage, not ordinary settings/logs. | Must |
| NFR-SEC-006 | Sensitive logs/diagnostic output shall be redacted. | Must |
| NFR-SEC-007 | Side-effecting actions shall require defined authorization/confirmation policy. | Must |
| NFR-SEC-008 | A threat model shall be maintained as integrations are added. | Must |
| NFR-SEC-009 | Any future LAN API requires a dedicated security design review and ADR. | Must |
| NFR-SEC-010 | Any future private/privileged system API/helper requires a dedicated architectural/security review. | Must |

## 6.6 Accessibility and usability

| ID | Requirement | Priority |
|---|---|---|
| NFR-A11Y-001 | All interactive UI elements shall provide accessibility labels. | Must |
| NFR-A11Y-002 | Core actions shall be accessible via menu, keyboard, or focus navigation. | Must |
| NFR-A11Y-003 | Important states shall not depend on color alone. | Must |
| NFR-A11Y-004 | UI shall provide sufficient contrast in supported appearance modes. | Must |
| NFR-A11Y-005 | The app shall provide a Reduced Motion setting. | Must |
| NFR-A11Y-006 | Error/permission/disabled states shall contain explanatory text, not only disabled controls. | Must |
| NFR-A11Y-007 | Compact content shall remain readable and avoid dense multi-column controls. | Must |

## 6.7 Maintainability and developer experience

| ID | Requirement | Priority |
|---|---|---|
| NFR-MNT-001 | Documentation shall live in the repository and be updated with behavior changes. | Must |
| NFR-MNT-002 | Architectural decisions shall be recorded as numbered ADRs. | Must |
| NFR-MNT-003 | Package dependency direction shall remain one-way toward `NotchDomain`. | Must |
| NFR-MNT-004 | Feature modules shall not depend directly on `NSPanel` implementation. | Must |
| NFR-MNT-005 | Code shall use explicit ownership/cancellation for tasks, observers, timers, sockets, and subscriptions. | Must |
| NFR-MNT-006 | All new modules shall document settings, permissions, actions, event inputs/outputs, performance policy, privacy, and tests. | Must |
| NFR-MNT-007 | CI shall build and run automated tests on pull requests. | Must |
| NFR-MNT-008 | Developer setup/build/test/profile steps shall be documented. | Must |

---

## 7. User interface requirements

## 7.1 Settings information architecture

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

### General

- Launch-at-login setting when implemented.
- Reset application configuration.
- Non-sensitive import/export.
- Update-policy placeholder/configuration if applicable.

### Appearance

- Theme mode.
- Opacity/material options within supported design system.
- Compact/expanded sizing preferences where safe.
- Reduced Motion.

### Notch Behavior

- Surface visibility preference.
- Hover delay.
- Auto-collapse timeout.
- Full-screen/screen-sharing suppression policy.
- Built-in display-first policy explanation.

### Shortcuts

- List registered shortcut-capable actions.
- Record/change/clear shortcut.
- Conflict and unavailable capability indicators.

### Permissions

- Capability matrix and current status.
- Explanation and recovery controls.
- No misleading “enable” button if a permission is not yet needed by any enabled module.

### Actions

- Registered actions by category.
- Availability state.
- Confirmation behavior where user-configurable.
- Recent action summary or link to Diagnostics.

### Modules

- Enabled/disabled state.
- Version, health, required capabilities, last error.
- DemoModule support in foundation.

### Diagnostics

- Runtime health.
- Log/event/action/resource views.
- Debug overlay toggle in development mode.
- Sanitized copy/export.

### About

- App version/build.
- License.
- Credits/reference information.
- Privacy statement link/content.

## 7.2 Notch content constraints

| Surface | Content constraint |
|---|---|
| Collapsed | Minimal/no content; must not become a persistent wide banner |
| Compact | One to three short lines; status/action feedback only |
| Expanded | Quick controls and short summaries; interaction should normally finish within seconds |
| Detail | Long text, advanced settings, history, diagnostics |

The Notch surface shall not be used as an unrestricted terminal/log/transcript renderer.

---

## 8. Data requirements

### 8.1 Settings data

- Must be typed and versioned.
- Must contain only non-secret preferences and references.
- Must support safe defaults and migration.
- Must be inspectable/exportable only in sanitized form.

### 8.2 Secrets

- IPC tokens, future API credentials, and authentication secrets must use Keychain or equivalent secure storage.
- Secrets must not be displayed in standard diagnostics.
- Reset/export/import flows must clearly differentiate secrets from normal configuration.

### 8.3 Operational data

- Event history, action history, module status, and diagnostics logs must be bounded.
- The app must define retention policy before adding transcript, clipboard, file, or calendar data.
- Future sensitive module data must be opt-in where appropriate.

### 8.4 Future transcript data

When a voice/AI module is added:

- In-memory transcript data must have a count/byte limit.
- Persistent transcript retention must be explicit and configurable.
- The Notch surface only displays a short recent window of text.
- Full content belongs in a application scene and must respect privacy settings.

---

## 9. Module requirements template

Every future module must provide a document and implementation evidence for the following fields before merge:

| Field | Requirement |
|---|---|
| Purpose | Clear user value and problem solved |
| Non-goals | Explicit scope limits |
| Module ID/version | Stable identifier and version metadata |
| Dependencies | Platform packages, system APIs, external services |
| UI contributions | Declared slots: indicator, compact, expanded, menu bar, plus explicitly opened separate detail-window content |
| Settings | Namespaced schema, defaults, migration/reset behavior |
| Permissions | Required/optional capabilities and request timing |
| Events | Input/output types, schema, rate, ordering, error handling |
| Actions | Registered IDs, input validation, confirmation policy, timeout/cancel |
| Resource policy | Idle/hidden/visible work, refresh rates, event rate, memory/cache cap |
| Privacy | Data read, stored, transmitted, retention/opt-in behavior |
| Security | Trust boundaries, validation, authorization, threat considerations |
| Failure behavior | Offline, denied permission, reconnect, degraded mode |
| Accessibility | Labels, keyboard path, status/error communication |
| Tests | Unit/integration/manual/performance scenarios |
| Diagnostics | Health fields, logs, counters, sanitized report content |

A module that does not provide this information is not ready to be accepted into the platform.

---

## 10. Test requirements

## 10.1 Automated tests

| Area | Mandatory test coverage |
|---|---|
| Domain | IDs, models, serialization, validation, errors |
| Surface state machine | All permitted transitions, timeout, Escape, click-outside, suppression, recovery |
| Geometry | Built-in display, no-notch fallback, resolution/scale changes |
| Settings | Defaults, validation, migration, corrupt recovery, reset/import/export |
| Permissions | Status mapping, request orchestration, denied/recovery behavior |
| Actions | Registry, availability, invalid input, confirmation, cancel, timeout, result events |
| Shortcuts | Persist/restore, conflict logic, disabled/unavailable state |
| Module runtime | Register, start, stop, fail, restart, disable, resource cleanup |
| Events | Envelope decoding, unknown version/type, bounded buffer, coalescing, deduplication where used |
| IPC | Auth, schema validation, malformed request, oversized request, rate limit, unknown action |
| Diagnostics | Redaction and health snapshot generation |
| Performance policy | Timer/task suspension, memory cap enforcement, module cleanup |

## 10.2 Manual QA

Before foundation completion, manual QA must cover:

- First launch and relaunch.
- App quit and clean shutdown.
- Sleep/wake.
- Lock/unlock.
- Space changes.
- Full-screen apps.
- Menu-bar auto-hide.
- External display attach/detach.
- Resolution/scale change.
- MacBook lid close/open.
- Permission denied then granted through System Settings.
- Invalid IPC clients and event flood.
- Module enable/disable/restart/failure.
- Settings reset/import/export and corrupt-data recovery.

## 10.3 Performance profiling

| Scenario | Requirement |
|---|---|
| Idle long run | Measure CPU, memory growth, wakeups, energy impact for at least 8 hours where practical |
| Open/close stress | Open/collapse/expand surface 1,000 times; inspect allocation/window leaks/hitches |
| Event flood | Simulate high event rate; verify rate limit/coalescing/responsiveness |
| Text stream simulation | Simulate 20–100 deltas per second; verify bounded UI flush and memory behavior |
| General-operation output flood | Simulate 10,000+ entries; verify ring buffer and responsive UI |
| Module toggle loop | Enable/disable module repeatedly; verify task/timer/socket/observer cleanup |
| Lifecycle/display stress | Repeat sleep/wake/Space/full-screen/display changes; verify recovery |

Profile using appropriate Xcode Instruments tools: SwiftUI Instrument, Time Profiler, Allocations, Leaks, Energy Log, Hangs and Hitches, plus Activity Monitor for broad validation.

---

## 11. Acceptance: Foundation Completion Gate

The foundation is considered complete enough to begin real modules only when all requirements below are met:

1. The app launches as a stable menu-bar utility and retains a usable recovery path independent of the Notch surface.
2. `NotchPanelController` is the sole native panel owner and the surface state machine has automated tests.
3. The surface behaves safely across required lifecycle/display scenarios within initial built-in-display scope.
4. Settings are typed, persistent, versioned, migration-safe, and corrupt-data-safe.
5. Permissions are centralized, contextual, on-demand, and recoverable after denial.
6. Menu bar, Notch UI, keyboard shortcuts, and local IPC invoke the same typed Action Registry.
7. No untrusted source can trigger arbitrary shell/script execution.
8. Module runtime supports registration, enable/disable, health reporting, error isolation, and resource cleanup.
9. DemoModule demonstrates module lifecycle/settings/actions/events without direct panel access.
10. External events use validated versioned envelopes and bounded EventBus processing.
11. Local IPC is loopback/local-only, authenticated where applicable, validated, size-limited, and rate-limited.
12. Diagnostics expose actionable surface, module, permission, event, action, IPC, and performance data with redaction.
13. CPU/RAM/energy targets have been measured; no unbounded memory/data growth remains in stress tests.
14. CI, automated tests, manual QA, and profiling scenarios pass according to documented release criteria.
15. Documentation and ADRs reflect the implementation actually present in the codebase.

Only after all conditions are met may the project start M0/M1 real-module work.

---

## 12. Change control

A change that affects any of the following requires an update to this document, a related architecture document, and potentially an ADR:

- Supported macOS version.
- Module loading model.
- Permission policy.
- IPC binding/authentication/security model.
- Action execution policy.
- Data retention or privacy behavior.
- Surface/window ownership/state model.
- Performance budgets or bounded-buffer policy.
- Addition of a privileged helper or private API dependency.
- Foundation Completion Gate criteria.

Requirements changes should be reviewed before implementation when they introduce new trust boundaries, permissions, persistent data, high-frequency streams, hardware actions, or external network exposure.
