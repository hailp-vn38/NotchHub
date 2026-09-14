# NotchHub

> A modular macOS Notch Platform for glanceable status, quick actions, and extensible desktop integrations.

NotchHub turns the area around a MacBook notch into a focused interaction surface. It is designed as a **foundation-first, modular platform** rather than a clone of any single notch utility: the base app provides windowing, UI, settings, permissions, shortcuts, actions, IPC, diagnostics, performance controls, and testing infrastructure before feature modules are introduced.

The first intended AI integration is Xiaozhi, but Xiaozhi is deliberately **not part of the base app core**. Future modules may add voice/AI status, media controls, clipboard history, files, system metrics, calendar/reminders, and other macOS productivity utilities.

## Status

**Project phase:** F2 — Notch surface shell. F0 and F1 are complete; their passing gates are
recorded in [F0 evidence](docs/quality/f0-evidence.md) and [F1 evidence](docs/quality/f1-evidence.md).

F0 and F1 delivered:

- Six Swift package targets and pure `NotchDomain` contracts
- A menu-bar-first macOS application shell with independent placeholder Settings and Diagnostics windows
- A pinned Xcode toolchain, formatter, import-boundary check, Markdown-link check, secret scan,
  and pull-request verification workflow

F2 adds the native Notch `NSPanel`, geometry, interaction state machine, and safe recovery.
Typed settings, shortcuts, the shared Action Registry, modules, IPC, and real integrations remain
later-phase work.

## Goals

- Build a reliable, low-overhead interaction surface around the MacBook notch.
- Keep core windowing and UI independent from any particular backend or integration.
- Support modules that can be enabled, disabled, started, stopped, and failed without crashing the core application.
- Provide one typed action model shared by Notch UI, menu bar, keyboard shortcuts, local IPC, and future AI agents.
- Use a secure local-first integration model: validated events, authenticated loopback IPC, Keychain-managed secrets, and no arbitrary shell execution from external input.
- Make performance a first-class requirement: low idle CPU use, bounded buffers, controlled event rates, and observable diagnostics.
- Keep the project friendly to long-term development through docs-as-code, contracts, ADRs, tests, and explicit boundaries.

## Non-goals

- Reproduce all features of Boring Notch or any other notch application.
- Turn the notch into a full desktop dashboard or a long-form conversation window.
- Support dynamic third-party `.dylib` or `.bundle` plugins in the initial architecture.
- Run arbitrary shell commands sent by AI, WebSocket, HTTP, or IPC clients.
- Expose a LAN-accessible control API by default.
- Use private macOS APIs as a dependency of the core platform.
- Fully support all external displays and multi-display layouts in the first release.
- Request every privacy permission at launch.

## Product model

NotchHub has three presentation layers:

| Layer | Purpose | Example |
|---|---|---|
| Passive indicator | Quiet information visible at a glance | Connection badge, media-playing indicator, action result badge |
| Compact Notch | Brief status that can disappear automatically | “Assistant is thinking…” |
| Expanded panel | Quick actions and short interactions | Action grid, media controls, recent status |
| Application scene | Configuration and diagnostics outside the Surface | Settings, diagnostics, history |

The design rule is simple: **the Notch is for glanceable information and short actions**. Long text, logs, configuration, and history belong in application scenes.

## Reference: Boring Notch

[Boring Notch](https://github.com/TheBoredTeam/boring.notch) is an important open-source reference project for this work. It is useful for studying macOS notch interaction patterns, `NSPanel` window management, AppKit/SwiftUI composition, animation, full-screen behavior, feature organization, and macOS-specific edge cases.

NotchHub is not intended to be a direct fork or wholesale rewrite of Boring Notch. The project uses Boring Notch as a **reference implementation** while defining its own modular contracts, local IPC boundary, action security model, permission architecture, performance policy, and productivity-oriented roadmap.

Any code reuse or adaptation must be preceded by a review of the upstream license, dependencies, and attribution obligations.

## Architecture

```text
Apps / Tools / Future Modules
            ↓
NotchSurface + NotchUI + NotchActions + NotchIPC
            ↓
        NotchCore
            ↓
       NotchDomain
```

### Architecture rules

- `NotchDomain` contains pure Swift models, contracts, identifiers, events, actions, and errors. It does not import SwiftUI or AppKit.
- `NotchCore` owns module runtime, event routing, persistence, permission coordination, presentation policy, lifecycle management, and diagnostics.
- `NotchSurface` contains `NotchPanelController`, the sole Notch `NSPanel` owner, and the Surface lifecycle/state machinery. Settings and diagnostics are application scenes outside the Surface.
- `NotchUI` contains design tokens and reusable UI components.
- `NotchActions` owns action registration, typed execution, confirmation policy, cancellation, timeouts, and result events.
- `NotchIPC` owns local socket/loopback HTTP/WebSocket communication, request authentication, schema validation, rate limiting, and external event routing.
- A feature module never creates, resizes, shows, or hides an `NSPanel` directly.
- The app composition root is the only place where modules are registered.

## Planned repository layout

```text
NotchHub/
├── README.md
├── LICENSE
├── CONTRIBUTING.md
├── SECURITY.md
├── Package.swift
├── NotchHub.xcodeproj/
├── Apps/NotchHubApp/
├── Packages/
│   ├── NotchDomain/
│   ├── NotchCore/
│   ├── NotchSurface/
│   ├── NotchUI/
│   ├── NotchActions/
│   └── NotchIPC/
├── Modules/
│   └── DemoModule/
├── Tools/
│   └── notchctl/
├── Tests/
└── docs/
```

## Foundation-first roadmap

1. **F0 — Bootstrap and architecture:** repository, packages, CI, documentation, ADRs, base contracts.
2. **F1 — App shell and lifecycle:** menu bar, Settings, Diagnostics, safe lifecycle.
3. **F2 — Notch surface:** `NSPanel`, layout, state machine, hover/click/Escape/timeout, and separate detail-window navigation.
4. **F3 — Design system and Settings UI:** common visual system and configuration layout.
5. **F4 — Typed settings:** schema migration, persistence, reset, safe import/export.
6. **F5 — Permission Center:** contextual, on-demand permission policy.
7. **F6 — Actions and shortcuts:** one Action Registry for UI, hotkeys, and IPC.
8. **F7 — Module runtime:** lifecycle, isolation, DemoModule.
9. **F8 — EventBus and local IPC:** validated local event/action path and `notchctl`.
10. **F9 — Diagnostics:** logs, health, state inspection, resource counters.
11. **F10 — Quality gate:** lifecycle, security, performance, and stress validation.

## Future module order

| Phase | Module | Initial scope |
|---|---|---|
| M0 | Sample Status Module | Prove real UI-slot, event, setting, and action contracts |
| M1 | Xiaozhi Display Companion | Voice state and text transcript through a normalized relay; no native microphone/audio initially |
| M2 | Media or Clipboard | A daily-use macOS productivity module |
| M3 | Files or System Controls | Selected file/system interactions with explicit permission review |
| M4 | Calendar or Reminders | Contextual productivity information and actions |
| M5 | Native Xiaozhi Voice | Mac microphone/audio only if M1 proves the need |
| M6 | Other desktop modules | Only after ADR, threat-model, permission, and performance review |

## Permissions

NotchHub uses an on-demand permission model. The base app must not ask for Camera, Microphone, Calendar, Screen Recording, or Automation access merely because a future module might need it.

| Permission | Potential module | Request timing |
|---|---|---|
| Accessibility | Global shortcut or specific automation features | When the user enables the relevant capability |
| Notifications | Alerts and background status | When the user opts in |
| Microphone | Native voice module | When the user enables “Use Mac microphone” |
| Calendar/Reminders | Calendar module | When that module is enabled/opened |
| Camera | Camera module | When preview is enabled |
| Screen Recording | Screenshot/OCR/context module | Immediately before that feature is used |
| Automation | AppleScript or app-control actions | Immediately before the relevant action |

## Performance requirements

NotchHub is intended to run throughout a workday. Performance and battery impact are architecture requirements, not late-stage polish.

| Scenario | CPU target | Memory target | UX target |
|---|---:|---:|---|
| Idle, Notch collapsed | < 0.3% average | 40–80 MB | No continuous animation or fast polling |
| Expanded, no stream | < 1–2% | 60–120 MB | Open in < 150 ms |
| Local compact event | Brief spike < 5% | No unbounded growth | Event-to-UI < 100 ms |
| Future text streaming | 1–5% average | < 150 MB | Delta-to-UI < 100–150 ms |

- Main actor is reserved for presentation.
- Every event stream, log, transcript, cache, and process-output buffer has a defined upper bound.
- Modules declare idle/hidden/visible refresh policies, maximum event rate, memory budget, and cleanup ownership.
- Disabled modules release timers, observers, sockets, tasks, and caches.
- High-rate UI updates are coalesced.

## Local IPC and `notchctl`

The platform provides a local integration boundary before any network service.

```text
GET  /v1/health
GET  /v1/status
POST /v1/events
POST /v1/actions/{actionID}
WS   /v1/stream
```

Security defaults:

- Bind only to `127.0.0.1` or a Unix domain socket.
- Authenticate requests with a random token managed securely.
- Validate payload schemas and enforce maximum request sizes.
- Rate-limit clients and record sanitized audit events.
- Never accept raw shell command strings or arbitrary executor configuration through IPC.

## Documentation

Documentation is part of the repository and must evolve with code. High-priority documents include:

- `docs/product/vision.md`
- `docs/product/roadmap.md`
- `docs/product/requirements.md`
- `docs/architecture/overview.md`
- `docs/architecture/notch-surface.md`
- `docs/architecture/module-system.md`
- `docs/architecture/event-protocol.md`
- `docs/architecture/action-platform.md`
- `docs/architecture/ipc.md`
- `docs/architecture/performance.md`
- `docs/platform/permissions.md`
- `docs/security/threat-model.md`
- `docs/quality/testing-strategy.md`
- `docs/references/boring-notch.md`

## Initial ADRs

| ADR | Decision |
|---|---|
| 0001 | Support macOS 14+ |
| 0002 | Use SwiftUI for UI and AppKit for native panel/window/input behavior |
| 0003 | Use static modules before dynamic plugins |
| 0004 | Use the menu bar as an independent recovery/control surface |
| 0005 | Use local IPC before any LAN API |
| 0006 | Use versioned event envelopes for external inputs |
| 0007 | Use typed action allow-lists and confirmation policies |
| 0008 | Centralize permissions in a Permission Coordinator |
| 0009 | Enforce performance budgets and bounded streams |
| 0010 | Support the built-in display first |
| 0011 | Use public macOS APIs first; isolate any future privileged helper |
| 0012 | Keep documentation as code in the repository |
| 0013 | Admit the fixed expanded surface and own native shaped hit-testing |

## Security principles

- Treat IPC, future AI integrations, scripts, and relays as untrusted input sources until validated.
- Accept commands by registered `ActionID`, not arbitrary executable strings.
- Require explicit confirmation for destructive or side-effecting actions.
- Store credentials/tokens in Keychain; never in `UserDefaults`, source code, or ordinary logs.
- Bind services to loopback/local socket by default.
- Redact tokens, authorization headers, secrets, and sensitive payloads from diagnostics exports.

## Project direction

The foundation is the product enabler. Once the platform passes its quality gate, adding Xiaozhi becomes an ordinary integration task: a relay/adapter emits normalized events, a module renders status and text through declared UI slots, and registered actions handle controlled interactions. The same foundation can then support macOS productivity utilities without rewriting the core architecture.
