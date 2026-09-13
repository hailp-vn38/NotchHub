# AI Agent Instructions
## NotchHub — Repository Rules for AI-Assisted Development

**Status:** Draft v0.1  
**Owner:** Project Maintainers  
**Last updated:** 2026-09-13  
**Location:** `docs/development/agent-instructions.md`  
**Related documents:** [README](../../README.md), [Documentation Index](../index.md), [Vision](../product/vision.md), [Requirements](../product/requirements.md), [Roadmap](../product/roadmap.md), [Architecture Overview](../architecture/overview.md), [Contributing](contributing.md), [Setup](setup.md), [Threat Model](../security/threat-model.md), [Testing Strategy](../quality/testing-strategy.md)

---

## 1. Purpose

This document instructs AI coding agents working on the NotchHub repository.

An AI agent must treat this repository as a **foundation-first, modular macOS platform**, not as a collection of UI experiments. The agent must understand the product boundary, follow architecture ownership rules, preserve security/performance constraints, update documentation, and verify changes with tests.

These instructions apply to code generation, refactoring, bug fixing, test creation, documentation updates, architecture analysis, and review assistance.

---

## 2. Project identity

### Product

**NotchHub** is a local-first macOS application that turns the area around a MacBook notch into a calm interaction surface for:

- Glanceable status.
- Quick actions.
- Menu-bar recovery/control.
- Settings, permissions, shortcuts, diagnostics, and future modular desktop integrations.

### Development strategy

Build the complete platform foundation before adding real modules.

The foundation includes:

- App shell/lifecycle.
- `NSPanel` Notch surface.
- SwiftUI/AppKit UI architecture.
- Settings/persistence/migration.
- Permission Center.
- Action Registry and shortcuts.
- Module runtime and `DemoModule`.
- Versioned EventBus/event protocol.
- Local IPC and `notchctl`.
- Diagnostics.
- Performance/energy policy.
- Security/privacy boundaries.
- Automated/manual/profile testing.

### Future direction

The first intended AI feature is **Xiaozhi Display Companion**, which will be added only after the Foundation Completion Gate. It should display assistant state and streamed text through a normalized adapter, without coupling the core UI to raw Xiaozhi protocol/audio.

### Permanent product exclusions

Do not add, prepare for, or recommend implementation of:

- ESP-IDF `build`, `flash`, `monitor`, serial-port, or firmware workflows.
- Embedded development tooling.
- ESP32 gateway status, BLE telemetry, device count, OTA, or hardware dashboards.
- IoT/MQTT/smart-home device control.
- LAN device control or hardware command routing.

These are not postponed tasks. They are permanently outside NotchHub scope. If asked to implement them, stop and explain that the request conflicts with the current product boundary; do not add code, namespaces, schemas, actions, events, settings, permissions, or dependencies for those domains.

---

## 3. Required reading before changing code

Before making a non-trivial change, read:

1. `README.md`.
2. `docs/index.md`.
3. `docs/product/vision.md`.
4. `docs/product/requirements.md`.
5. `docs/product/roadmap.md`.
6. `docs/architecture/overview.md`.
7. The relevant component document:
   - `notch-surface.md`
   - `state-management.md`
   - `module-system.md`
   - `event-protocol.md`
   - `action-platform.md`
   - `ipc.md`
   - `data-persistence.md`
   - `performance.md`
8. The relevant platform/security/quality documents:
   - `platform/permissions.md`
   - `platform/macos-lifecycle.md`
   - `security/threat-model.md`
   - `quality/testing-strategy.md`
9. Active ADRs in `docs/architecture/decisions/`.
10. `docs/references/apple-apis.md` and `docs/references/boring-notch.md` when windowing/API/reference behavior is involved.

If the documentation conflicts with code, do not silently choose one. Report the conflict, identify the authoritative document, and propose a focused correction.

---

## 4. Architecture model

### 4.1 Dependency direction

```text
Apps / Tools / Static Modules
            ↓
NotchSurface + NotchUI + NotchActions + NotchIPC
            ↓
        NotchCore
            ↓
       NotchDomain
```

Keep dependencies acyclic and flowing toward `NotchDomain`.

### 4.2 Package responsibilities

| Package/container | Responsibility |
|---|---|
| `NotchDomain` | Pure Swift IDs, models, contracts, events, actions, errors |
| `NotchCore` | Runtime, state policy, EventBus, settings, permissions, lifecycle, diagnostics |
| `NotchSurface` | `NSPanel`, screen geometry, interaction, surface state machine, SwiftUI host |
| `NotchUI` | Design system, reusable components, accessibility helpers |
| `NotchActions` | Action definitions, registry, authorization, confirmation, typed executors |
| `NotchIPC` | Local transport, authentication, validation, rate limiting, routes |
| `Modules` | Feature-specific state/events/actions/settings/UI contribution through contracts |
| `Apps/NotchHubApp` | Composition root, app scenes, registration, startup/shutdown |
| `Tools/notchctl` | Separate client using public local IPC, never internal imports |

### 4.3 Critical resource owners

| Resource | Sole owner |
|---|---|
| Native `NSPanel` | `NotchPanelController` |
| Surface transitions | `SurfaceStateMachine`/`SurfaceCoordinator` |
| Module lifecycle | `ModuleRuntime` |
| Permission requests | `PermissionCoordinator` |
| Settings persistence | `SettingsStore` |
| Action execution | `ActionRegistry`/`ActionExecutor` |
| External event intake | `EventRouter` |
| IPC listener | `IPCServer` |
| Bounded diagnostics | `DiagnosticsStore` |

Never create a second owner for these resources.

---

## 5. Non-negotiable architecture rules

### 5.1 Native window ownership

Only `NotchPanelController` may create, configure, frame, show, hide, order, or destroy the Notch `NSPanel`.

Do not allow:

- Modules calling `NSPanel` methods.
- Views calling `orderFront`, `orderOut`, `setFrame`, or window-level APIs.
- IPC handlers expanding/hiding the panel directly.
- Event subscribers mutating native window state directly.

Use `SurfaceIntent`, `SurfaceStateMachine`, `SurfaceCoordinator`, and presentation snapshots.

### 5.2 UI is a projection

SwiftUI views render focused, immutable or controlled presentation state. They must not:

- Parse raw JSON/WebSocket data.
- Read/write `UserDefaults` directly.
- Read Keychain directly.
- Request macOS permissions directly.
- Run a process.
- Perform blocking file/network/IPC work.
- Own untracked timers/observers/tasks.

### 5.3 Main actor

Use `@MainActor` only for small presentation updates and native UI interaction.

Run off the main actor:

- Network/IPC.
- Event parsing/validation.
- Process/file work.
- Persistence/migrations/import/export.
- Audio/screen processing.
- Thumbnail/cache work.
- Large transcript/log formatting.

Use actors, structured concurrency, bounded streams, and explicit cancellation owners.

### 5.4 Modules

Modules must:

- Implement `NotchModule`.
- Declare ID/version, UI slots, settings, permissions, events, actions, privacy, diagnostics, and resource policy.
- Use the scoped `ModuleContext`.
- Register actions through `ActionRegistrar`.
- Publish/subscribe through typed EventBus handles.
- Use module-scoped settings.
- Release tasks/timers/observers/sockets/subscriptions/caches in `stop()`.

Modules must not:

- Access `NSPanel` directly.
- Request permissions directly.
- Read another module's settings/state.
- Register another module's action namespace.
- Subscribe to every event without a documented reason.
- Create an unrestricted IPC listener.
- Add excluded ESP/IoT/LAN functionality.

### 5.5 Static modules first

Do not introduce dynamic `.dylib`/`.bundle` plugin loading. Static compile-time modules are the current architecture. Dynamic plugins require a new ABI/security/signing/distribution review and ADR.

---

## 6. Product and scope rules

### The Notch is not a dashboard

Use presentation levels correctly:

| Level | Use |
|---|---|
| Passive indicator | Quiet badge/dot |
| Compact | 1–3 lines of transient status |
| Expanded | Short interaction/action grid |
| Detail | Long text, history, logs, settings, transcript |

Do not place full transcripts, terminal-like output, long lists, or dense forms in compact/expanded Notch content.

### Xiaozhi timing

Do not add Xiaozhi before the Foundation Completion Gate. When eventually adding it:

- Start with display-only relay/events.
- No Microphone permission for display-only mode.
- Normalize raw protocol into `EventEnvelope v1`.
- Keep protocol parsing outside `NotchSurface`.
- Coalesce transcript UI updates to about 20–30 snapshots/s.
- Bound transcript memory/retention.
- Map tool behavior to registered safe actions only.

### Reference projects

Use Boring Notch as a technical reference for windowing and edge-case hypotheses, not as a codebase to copy/fork. Inspect its current license/dependencies before any reuse. Implement NotchHub behavior independently through its own contracts.

---

## 7. Security rules

Treat all external input as untrusted until validated:

- IPC.
- `notchctl`.
- Local scripts.
- Imported settings.
- Future Xiaozhi relay.
- AI/voice action requests.
- Module-provided external data.

### Actions

```text
External request = ActionID + validated structured input
External request ≠ shell/script/executable command
```

Never add:

- `shell.executeRaw`.
- `command`/`script`/`executablePath` escape hatches.
- Arbitrary executor kinds from IPC.
- Unvalidated URLs/hosts.
- Hardware/LAN targets.

Use `ActionRegistry` → source policy → schema validation → availability → confirmation → typed executor → result event.

### IPC

- Unix socket or `127.0.0.1` only.
- Authenticate HTTP/WebSocket clients.
- Use source/client allow-list.
- Validate protocol/event/action schemas.
- Enforce payload size, nesting, rate, and queue limits.
- Sanitize errors/logs.
- Do not expose LAN controls.

### Secrets

- Keychain only for IPC tokens/credentials.
- Never store secrets in settings exports, logs, diagnostics, source, command arguments, screenshots, or fixtures.
- Diagnostics reports presence/absence, never values.

### Permissions

- Only `PermissionCoordinator` requests system permission.
- Request only after explicit user action.
- Explain what/why/when/data flow/denial result.
- Handle denied/restricted/unavailable without retry loops.
- Refresh after app activation/System Settings return.

### Privacy

Do not persist or log raw:

- Transcript.
- Clipboard.
- File contents.
- Calendar/reminder content.
- Microphone audio.
- Camera frames.
- Screen capture.
- Authorization headers/tokens.

If a future module needs user-content persistence, document classification, retention, deletion, export, redaction, and tests first.

---

## 8. Performance rules

Target budgets:

| Scenario | Target |
|---|---:|
| Idle/collapsed CPU | < 0.3% average |
| Idle memory | 40–80 MB |
| Expanded/no stream CPU | < 1–2% average |
| Expand latency | < 150 ms under normal load |
| Local event-to-UI | < 100 ms under normal load |
| Future text UI updates | 20–30/s maximum |

Required behavior:

- No continuous idle animation.
- No fast polling while hidden/collapsed.
- Disabled modules have no active background work.
- High-rate event/text/audio streams are assembled/coalesced off main actor.
- Logs, event history, transcript, caches, and output have explicit count/byte caps.
- Retry/backoff is bounded.
- Timers/observers/tasks/sockets have owners and cleanup.
- Performance-sensitive changes require Instruments scenario planning.

Required profile scenarios include idle soak, 1,000 panel cycles, event flood, text stream simulation, operation-output flood, module toggle loop, lifecycle/display stress, and persistence stress.

---

## 9. State and event rules

### State

Use focused domain stores:

```text
SurfaceStore
SettingsStore
RuntimeStore
PermissionStore
ActionStore
DiagnosticsStore
ModulePresentationStore(s)
```

Avoid one global observable object observed by every view.

### Events

All external events use a versioned envelope:

```json
{
  "id": "uuid",
  "version": 1,
  "source": "source.id",
  "type": "domain.entity.verb",
  "timestamp": "RFC-3339",
  "correlationID": "uuid-or-null",
  "sequence": 1,
  "priority": "normal",
  "payload": {}
}
```

Event flow:

```text
transport → auth/source policy → decode/validate → EventRouter
→ EventBus → domain/module projection → PresentationPolicy → UI snapshot
```

Events do not directly call `NSPanel` or SwiftUI view methods.

Use bounded buffers, ordering/sequence rules, deduplication where appropriate, rate limiting, coalescing, and sanitized diagnostics.

---

## 10. Data persistence rules

- Typed `AppSettings` with schema version/migrations.
- Last-known-good state after corruption/write failure.
- Atomic/debounced writes.
- Keychain for secrets.
- Bounded diagnostics ring buffer.
- LRU/count/byte limits for future caches.
- No automatic secret deletion during normal reset.
- Sanitized import/export only.
- Module-owned data namespace and retention policy.

Do not add a database/cache/history just because it is convenient. First classify the data, define retention/deletion/privacy, then implement.

---

## 11. Documentation rules

Update docs in the same change as behavior:

| Change | Update |
|---|---|
| Product scope | `vision.md`, `requirements.md`, `roadmap.md`, likely ADR |
| Surface/window | `notch-surface.md`, design/lifecycle/tests |
| State/store | `state-management.md`, performance/tests |
| Module | `module-system.md`, `docs/modules/<id>.md`, permissions/data/security/tests |
| Event | `event-protocol.md`, fixtures, state/presentation/tests |
| Action | `action-platform.md`, requirements/security/tests |
| IPC | `ipc.md`, threat model, setup/tests |
| Persistence | `data-persistence.md`, privacy/threat/tests |
| Permission/API | `platform/permissions.md`, `references/apple-apis.md`, threat/tests |
| Performance | `performance.md`, test plan, diagnostics |
| Durable architecture decision | New/updated ADR |

Mark planned/not implemented behavior honestly. Do not write future features as if they already exist.

---

## 12. Required workflow for an AI agent

### Phase A — Understand

1. Identify the task type: bug, feature, refactor, docs, test, architecture.
2. Read the relevant docs from `docs/index.md`.
3. Inspect existing code/tests before proposing changes.
4. Identify owner boundaries and affected contracts.
5. Check whether the request is within product scope.
6. Identify security/privacy/permission/performance implications.

### Phase B — Plan

Create a concise plan containing:

```text
Goal:
Files likely affected:
Contracts affected:
Owner boundaries:
Security/privacy impact:
Permission impact:
Performance/resource impact:
Tests to add/run:
Docs/ADR to update:
Out of scope:
```

If the task changes a durable architecture decision, propose an ADR before implementation.

### Phase C — Implement

1. Make the smallest coherent change.
2. Preserve dependency direction.
3. Use existing contracts before inventing new ones.
4. Add test doubles rather than making core tests depend on real OS state.
5. Keep I/O/background work outside main actor.
6. Give every task/observer/timer/socket/cache an owner.
7. Validate all external/user input.
8. Keep logs sanitized and bounded.
9. Do not broaden product scope.

### Phase D — Verify

Run the narrowest useful checks first, then broader checks:

```text
focused unit tests
→ package/integration tests
→ build
→ UI/manual test if macOS behavior changed
→ security/privacy checks
→ Instruments profile if performance-sensitive
```

### Phase E — Report

Final response must state:

- What changed.
- Files changed.
- Tests/build commands run and results.
- Tests not run and why.
- Security/privacy/permission impact.
- Performance/resource impact.
- Documentation/ADR changes.
- Known limitations/follow-up.

---

## 13. Task decision rules

### If asked to add a new module

Before coding, require:

- User value/purpose/non-goals.
- Module ID/version.
- UI slots/content limits.
- Settings schema/migration/reset.
- Permissions/request timing.
- Events/actions and schemas.
- Resource/performance policy.
- Privacy/retention/delete policy.
- Failure/degraded behavior.
- Diagnostics/test plan.

If the foundation gate is not passed, implement only a design/contract/mock if explicitly requested; do not add real integration prematurely.

### If asked to add a new permission

Require:

- Feature that actively needs it.
- User-facing explanation.
- On-demand request trigger.
- Denied/revoked fallback.
- API/entitlement/Info.plist review.
- Privacy/threat-model update.
- Manual signed-build test.

### If asked to add a new action

Require:

- Stable namespaced ActionID.
- Typed input schema.
- Availability rule.
- Source policy.
- Confirmation policy.
- Timeout/cancellation.
- Result/error events.
- Security tests.

Reject arbitrary command/executor requests.

### If asked to add a new event

Require:

- Event type/version.
- Producer/consumer.
- Payload schema and limits.
- Ordering/sequence/correlation.
- Privacy classification.
- Presentation/coalescing policy.
- Fixtures and validation tests.

### If asked to alter windowing

Require:

- `NotchPanelController` ownership preserved.
- State machine/geometry impact analysis.
- Sleep/wake/Space/full-screen/display tests.
- Hit-test/click-through review.
- Performance/hitch check.
- Boring Notch/Apple API reference review if relevant.

### If asked to alter IPC

Require:

- Transport/binding decision.
- Authentication/source policy.
- Schema/version/size/rate limits.
- Threat-model update.
- Negative/security tests.
- No LAN/hardware/device-control expansion.

### If asked to persist data

Require:

- Data classification.
- Owner/storage backend.
- Schema/migration.
- Retention/delete/export.
- Secret/redaction review.
- Memory/disk budget.
- Corruption/failure tests.

---

## 14. AI-agent forbidden behaviors

An AI agent must not:

- Implement excluded ESP-IDF/ESP32/IoT/LAN functionality.
- Add arbitrary shell/script execution.
- Add private macOS APIs without an ADR/security/release review.
- Bypass `ActionRegistry`, `PermissionCoordinator`, `EventRouter`, `SettingsStore`, or `ModuleRuntime`.
- Let modules control `NSPanel` directly.
- Add global mutable state as a shortcut.
- Put heavy work in SwiftUI `body`/main actor.
- Add unbounded arrays, logs, caches, transcript/history, or event streams.
- Add permissions at launch for future features.
- Store secrets in source/settings/logs/fixtures.
- Copy Boring Notch source/assets/branding without license review.
- Claim an unimplemented feature is complete.
- Delete tests or weaken validation to make a change pass.
- Run destructive commands or modify external services without explicit user request/confirmation where applicable.

---

## 15. Definition of done for AI-generated changes

A change is done only when:

```text
[ ] Product scope verified
[ ] Existing docs/code/tests inspected
[ ] Architecture boundaries preserved
[ ] Implementation complete
[ ] Invalid/error/recovery behavior handled
[ ] Unit/integration/UI tests added or updated
[ ] Security/privacy/permission impact reviewed
[ ] Performance/resource impact reviewed
[ ] Documentation updated
[ ] ADR updated/created if needed
[ ] Build/tests run and results recorded
[ ] No secrets or personal data added
[ ] No excluded ESP/IoT/LAN scope introduced
```

A code snippet that compiles is not necessarily a completed change.

---

## 16. Quick reference

### Core flow

```text
User/IPC/module input
        ↓
Typed command/event
        ↓
Validation + source/permission/action policy
        ↓
Core state/module runtime
        ↓
Presentation snapshot
        ↓
SwiftUI/AppKit
```

### Safe action flow

```text
ActionID + typed input
        ↓
Registry lookup
        ↓
Source + availability + schema validation
        ↓
Confirmation if needed
        ↓
Typed executor with timeout/cancellation
        ↓
Sanitized result event
```

### Module flow

```text
Register
  ↓
Start with scoped context
  ↓
Publish/subscribe typed events
  ↓
Contribute UI slots
  ↓
Register typed actions
  ↓
Stop and release every resource
```

### Product scope sentence

> NotchHub is a foundation-first, local-first macOS Notch Platform for glanceable status, quick actions, Xiaozhi/AI display integration, and macOS productivity modules; it is not an ESP-IDF, ESP32, IoT, or LAN device-control application.

---

## 17. Summary for the agent

Work conservatively and transparently:

1. Understand the product and read the relevant documents.
2. Preserve ownership boundaries and typed contracts.
3. Build foundation before real integrations.
4. Treat all external input as untrusted.
5. Keep permissions on demand and secrets secure.
6. Keep UI focused and background work bounded.
7. Test failure, recovery, lifecycle, security, and performance—not only the happy path.
8. Update documentation and ADRs with code.
9. Refuse excluded ESP/IoT/LAN scope.
10. Report exactly what was changed and verified.
