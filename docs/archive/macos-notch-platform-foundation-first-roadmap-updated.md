# macOS Notch Platform Modular
## Foundation-first roadmap: complete base app before modules

> **Deprecated — historical draft only.** This intermediate roadmap has been superseded. Do not use it as an implementation source. The authoritative roadmap is [`docs/product/roadmap.md`](../product/roadmap.md), and the authoritative Notch state model is [`docs/architecture/notch-surface.md`](../architecture/notch-surface.md).

**Archived:** 2026-09-13  
**Superseded by:** `docs/product/roadmap.md`

**Status:** Updated architecture and roadmap.  
**Decision:** Build a complete base app—UI, windowing, settings, permissions, shortcuts, action platform, IPC, diagnostics, performance, and testing—before adding Xiaozhi or any other real module.  
**Scope decision:** ESP-IDF workflows, ESP32 gateway telemetry, IoT integration, and LAN device control are permanently out of scope for NotchHub.

---

## 1. Product direction

NotchHub is a **macOS Notch Platform** for status, quick actions, and modular desktop productivity integrations.

It is not:

- An ESP-IDF development tool.
- An ESP32 or BLE gateway console.
- An IoT/smart-home dashboard.
- A LAN device-control surface.
- A generic arbitrary scripting host.

Xiaozhi is a future optional **Display Companion** module: it can show assistant state and streamed text in the Notch, but only after the base platform is stable.

---

## 2. Boring Notch reference

[Boring Notch](https://github.com/TheBoredTeam/boring.notch) is a valuable open-source reference for:

- `NSPanel` window ownership and layout around the notch.
- AppKit/SwiftUI hybrid UI.
- Hover/expand/collapse animations.
- Full-screen, Spaces, display-change, and lifecycle edge cases.
- Settings and feature organization.

Do not fork it as the platform base. Use it to study specific implementation problems, document the lesson in `docs/references/boring-notch.md`, and check license/dependency obligations before adapting code.

---

## 3. Base architecture

```text
Apps / Tools / Future Modules
            ↓
NotchSurface + NotchUI + NotchActions + NotchIPC
            ↓
        NotchCore
            ↓
       NotchDomain
```

- `NotchDomain`: pure Swift types, contracts, events, actions, errors.
- `NotchCore`: module runtime, EventBus, settings, permissions, lifecycle, diagnostics, presentation policy.
- `NotchSurface`: AppKit `NSPanel`, screen/notch geometry, input, state machine, SwiftUI host.
- `NotchUI`: design system and shared components.
- `NotchActions`: typed Action Registry, availability, confirmation, timeout/cancellation.
- `NotchIPC`: local Unix socket/loopback HTTP/WebSocket, authentication, validation, rate limits.
- `Modules`: compile-time modules; no direct panel control.

## 4. Foundation sequence

| Phase | Result |
|---|---|
| F0 | Repo, Swift packages, docs, ADRs, CI, domain contracts |
| F1 | Menu bar app shell, lifecycle, Settings/Diagnostics recovery path |
| F2 | Notch `NSPanel`, built-in display layout, state machine, interaction |
| F3 | Design system, accessibility, Settings information architecture |
| F4 | Typed settings, migration, persistence, reset/import/export |
| F5 | Permission Center and contextual on-demand permission flow |
| F6 | Action Registry, typed actions, shortcut recorder and routing |
| F7 | Module runtime, lifecycle, failure isolation, DemoModule |
| F8 | EventBus, Presentation Policy, local IPC, `notchctl` |
| F9 | Diagnostics, structured logs, debug overlay, resource counters |
| F10 | Lifecycle, stress, security, performance and quality gate |

## 5. Core requirements

### Notch surface

States:

```text
hidden → collapsed → compact → expanded → detail → collapsed
visible → suppressed → recovering → stable state
```

Rules:

- `NotchPanelController` is the only owner of native `NSPanel`.
- Modules never call `show`, `hide`, `setFrame`, or native window APIs directly.
- Built-in MacBook display is the initial target; no-notch fallback is top-center.
- Collapse must not block unrelated menu bar interactions.
- Hover, click, click-outside, Escape, timeout, full-screen, Spaces, sleep/wake, and display changes must have testable policy.

### Settings

Top-level pages:

```text
General · Appearance · Notch Behavior · Shortcuts · Permissions
Actions · Modules · Diagnostics · About
```

Settings requirements:

- Typed `AppSettings` with schema version and migration.
- Default values and validation.
- Module settings namespace keyed by `ModuleID`.
- Non-secret persistence; Keychain for secrets.
- Safe reset and sanitized import/export.
- Runtime behavior updates where safe.

### Permissions

- Central `PermissionCoordinator` only.
- No permission prompts at first launch without explicit user action.
- Contextual explanation before system prompt.
- Clear denied/restricted/unavailable states and System Settings recovery.
- Future capabilities: Accessibility, Notifications, Microphone, Calendar, Reminders, Camera, Screen Recording, Automation.

### Actions and shortcuts

Every operation is a typed `ActionID`:

```text
Menu / Notch / Shortcut / IPC / Future AI
              ↓
       ActionRegistry
              ↓
Authorization + Confirmation + Availability
              ↓
          Typed Executor
              ↓
        Result + EventBus
```

- No arbitrary shell commands from external input.
- Side-effecting actions use confirmation policy.
- Shortcut recorder, persistence, conflict checks, and disabled-capability handling.
- Foundation action examples: toggle surface, open settings, open diagnostics, restart runtime, demo status, debug overlay, reset settings.

### Event and IPC platform

- Versioned external event envelope.
- Typed internal EventBus.
- Event validation, max payload size, filtering, bounded buffers, backpressure/coalescing metrics.
- Local IPC only: Unix domain socket and/or `127.0.0.1` HTTP/WebSocket.
- Auth token managed securely; never hard-coded.
- `notchctl` for status, test event, and registered action.
- No LAN device control, no MQTT/BLE/IoT transport, no hardware action route.

### Module runtime

- Static compile-time modules before dynamic plugins.
- States: registered, starting, running, suspended, stopping, stopped, failed.
- Enable/disable, health report, error isolation, resource cleanup.
- Module declares UI slots, settings, permissions, actions, events, resource policy, privacy, diagnostics, and test plan.
- `DemoModule` proves contracts before business modules.

---

## 6. Performance and energy

### Budgets

| Scenario | CPU target | Memory target | UX target |
|---|---:|---:|---|
| Idle/collapsed | < 0.3% average | 40–80 MB | No fast polling or continuous animation |
| Expanded/no stream | < 1–2% | 60–120 MB | Open < 150 ms |
| Local compact event | Brief spike < 5% | No unbounded growth | Event → UI < 100 ms |
| Future text stream | 1–5% average | < 150 MB | Delta → UI < 100–150 ms |

### Mandatory policy

- Main actor is only for presentation.
- I/O, parsing, storage, networking, audio, and heavy formatting run in actors/background tasks.
- UI gets coalesced snapshots, not raw high-frequency streams.
- Every stream, log, transcript, cache, and output buffer has explicit count/byte caps.
- Disabled modules stop tasks, timers, observers, sockets, subscriptions, and caches.
- Modules declare idle/hidden/visible refresh rate, max event rate, memory budget, and cleanup ownership.
- Diagnostics expose event rate, coalescing/drop counts, buffer use, active tasks, and resource snapshots.

### Profile before modules

Use Instruments and Activity Monitor for:

- Idle run of 8 hours.
- Notch open/close 1,000 times.
- Event flood.
- Text stream simulation at 20–100 deltas/s.
- Log/output flood.
- Module enable/disable loop.
- Sleep/wake, Space, full-screen, and display-change stress.

---

## 7. Quality gate

Do not add Xiaozhi or any module until:

- Surface/window lifecycle is stable and tested.
- Settings, permissions, shortcuts, actions, IPC, diagnostics, and DemoModule work end to end.
- Local IPC is authenticated, validated, loopback-only, and rate-limited.
- No arbitrary external shell/script execution exists.
- Bounded buffers and resource cleanup are tested.
- CPU/RAM/energy profiling meets the project budgets.
- CI, unit tests, integration tests, manual QA, and documentation are complete.

---

## 8. Future module sequence

| Module phase | Module | Scope |
|---|---|---|
| M0 | Sample Status Module | Real slot/settings/event/action contract validation |
| M1 | Xiaozhi Display Companion | State + streamed transcript through normalized relay; no native mic/audio |
| M2 | Media or Clipboard | Daily utility and consumer UX validation |
| M3 | Files or System Controls | Carefully reviewed desktop interactions |
| M4 | Calendar or Reminders | Contextual productivity data and actions |
| M5 | Native Xiaozhi Voice | Optional Mac voice capability if M1 proves need |
| M6 | Reviewed desktop modules | Only with module proposal, ADR if needed, and full platform review |

NotchHub will not add ESP-IDF, ESP32 gateway, IoT telemetry, or LAN device-control modules.

---

## 9. Foundation completion checklist

- Menu-bar recovery/control path works even when Notch surface is hidden.
- `NotchPanelController` is the only native panel owner.
- State transitions and geometry are test-covered.
- Typed settings migrate and recover from corrupt data.
- Permission requests are contextual and centralized.
- UI/menu/shortcut/IPC share one Action Registry.
- DemoModule proves module isolation and cleanup.
- Event/IPC inputs are validated and bounded.
- Diagnostics are actionable and redacted.
- Performance budgets are verified under stress.
- Architecture docs and ADRs match source code.

Only after this checklist is complete should the project add the Xiaozhi display integration.
