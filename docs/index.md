# NotchHub Documentation Index
## Documentation map and phase ownership

**Status:** Draft v0.2
**Owner:** Project / Architecture  
**Last updated:** 2026-09-15
**Location:** `docs/index.md`  
**Related documents:** [README](../README.md), [Vision](product/vision.md), [Roadmap](product/roadmap.md), [Requirements](product/requirements.md)

**Current execution phase:** F2 — Notch surface shell. F0 and F1 are complete; [F0 evidence](quality/f0-evidence.md)
and [F1 evidence](quality/f1-evidence.md) record their passing gates. [F2 evidence](quality/f2-evidence.md)
records passed automated verification and the remaining native manual gate.

---

## 1. Purpose

This file is the entry point for all NotchHub documentation. It explains:

- Where each type of information belongs.
- Which documents are required in each development phase.
- Which documents must be updated when code behavior changes.
- Which documents are mandatory before adding a real module.
- How the documentation set supports human developers, reviewers, and AI coding agents.

Documentation is maintained as code:

- Markdown files live in the repository.
- Documentation changes are reviewed in pull requests.
- Architecture decisions are recorded as numbered ADRs.
- Contracts, requirements, tests, and implementation must remain consistent.
- A feature is not complete if the code changes but its relevant documentation remains stale.

---

## 2. Documentation principles

### One source of truth per topic

Do not duplicate the same rule in many documents. Link to the authoritative document instead.

| Topic | Authoritative location |
|---|---|
| Product intent | `docs/product/vision.md` |
| Functional/non-functional requirements | `docs/product/requirements.md` |
| Delivery order and gates | `docs/product/roadmap.md` |
| High-level architecture | `docs/architecture/overview.md` |
| External actors/systems | `docs/architecture/c4-context.md` |
| Runtime/package boundaries | `docs/architecture/c4-container.md` |
| Notch panel/window behavior | `docs/architecture/notch-surface.md` |
| State ownership/observation | `docs/architecture/state-management.md` |
| Module contract/lifecycle | `docs/architecture/module-system.md` |
| Event schemas/versioning | `docs/architecture/event-protocol.md` |
| Typed actions/shortcuts/execution | `docs/architecture/action-platform.md` |
| Local transport/auth/routing | `docs/architecture/ipc.md` |
| Settings/secrets/cache/retention | `docs/architecture/data-persistence.md` |
| CPU/RAM/energy/profile budgets | `docs/architecture/performance.md` |
| macOS permissions | `docs/platform/permissions.md` |
| macOS lifecycle | `docs/platform/macos-lifecycle.md` |
| Security threats/mitigations | `docs/security/threat-model.md` |
| Test strategy | `docs/quality/testing-strategy.md` |
| Boring Notch study | `docs/references/boring-notch.md` |
| Apple API study | `docs/references/apple-apis.md` |

### Documentation update rule

Update the authoritative document in the same pull request as the behavior change. Add an ADR when the change is durable, cross-cutting, security-sensitive, or changes a product/architecture constraint.

---

## 3. Repository documentation tree

```text
docs/
├── index.md
│
├── product/
│   ├── vision.md
│   ├── requirements.md
│   ├── roadmap.md
│   └── glossary.md                         # optional, add when terminology grows
│
├── architecture/
│   ├── overview.md
│   ├── c4-context.md
│   ├── c4-container.md
│   ├── notch-surface.md
│   ├── state-management.md
│   ├── module-system.md
│   ├── event-protocol.md
│   ├── action-platform.md
│   ├── ipc.md
│   ├── data-persistence.md
│   ├── performance.md
│   └── decisions/
│       ├── 0001-use-macos-14-minimum.md
│       ├── 0002-use-swiftui-appkit-hybrid.md
│       ├── 0003-static-modules-before-dynamic-plugins.md
│       ├── 0004-menu-bar-as-recovery-surface.md
│       ├── 0005-local-ipc-before-lan-api.md
│       ├── 0006-versioned-event-envelopes.md
│       ├── 0007-typed-actions-and-confirmation.md
│       ├── 0008-central-permission-coordinator.md
│       ├── 0009-performance-budgets-and-bounded-streams.md
│       ├── 0010-built-in-display-first.md
│       ├── 0011-public-apis-first.md
│       ├── 0012-docs-as-code.md
│       └── 0013-fixed-expanded-admission-and-native-shaped-hit-testing.md
│       ├── 0014-always-on-surface-and-minimal-menu.md
│       └── 0015-versioned-settings-file-and-forward-schema-recovery.md
│
├── design/
│   ├── design-system.md                  # F3
│   ├── notch-interaction.md               # F2/F3
│   ├── settings-information-architecture.md # F3
│   ├── notchhub-settings-ui-spec.md       # F3–F9 UI ownership
│   └── accessibility.md                   # F3
│
├── platform/
│   ├── permissions.md
│   ├── macos-lifecycle.md
│   └── windowing.md                      # optional extraction from notch-surface.md
│
├── security/
│   ├── threat-model.md
│   └── ipc-security.md                   # optional extraction from ipc.md
│
├── quality/
│   ├── testing-strategy.md
│   ├── f1-evidence.md                 # F1 evidence
│   ├── f2-evidence.md                 # F2 automated and manual evidence
│   ├── f3-evidence.md                 # F3 automated evidence; native manual gate pending
│   ├── f4-evidence.md                 # F4 persistence and recovery evidence template
│   ├── manual-qa.md                      # F2/F10
│   └── performance-test-plan.md          # F10; may link performance.md
│
├── operations/
│   ├── logging-diagnostics.md             # F9
│   ├── privacy.md                         # F4/beta
│   └── release.md                         # pre-beta/release
│
├── development/
│   ├── setup.md
│   ├── contributing.md
│   ├── agent-instructions.md              # F0
│   ├── module-authoring.md                # F7/M0
│   └── tooling/
│       └── mattpocock-skills.md           # optional agent-tooling reference
│
├── references/
│   ├── boring-notch.md
│   └── apple-apis.md
│
└── modules/
    ├── _template.md
    ├── xiaozhi-display.md                 # M1
    ├── media.md                           # M2
    ├── clipboard.md                       # M2
    ├── files.md                           # M3
    ├── system-controls.md                 # M3
    ├── calendar.md                        # M4
    └── native-xiaozhi-voice.md             # M5
```

Some documents already exist. Documents marked optional can be extracted into their own file when the section becomes large enough to deserve an independent contract.

---

## 4. Document status legend

| Status | Meaning |
|---|---|
| Required | Must exist and be usable for the phase gate |
| Update | Exists but must be updated for this phase |
| Optional | Useful if scope/complexity requires it |
| Future | Create when the related module/feature begins |
| Gate | Must pass before a later phase starts |
| Deprecated | Retained for history but no longer authoritative |

---

## 5. Phase documentation matrix

## F0 — Bootstrap and architecture

### Goal

Create a buildable repository with a shared vocabulary, product boundary, architecture map, quality rules, and security/performance baseline.

### Required documents before F0 exit

| Document | Status | Purpose/update |
|---|---|---|
| `README.md` | Required | Project introduction, scope, setup overview, current status |
| `docs/index.md` | Required | Documentation map and phase matrix |
| `docs/product/vision.md` | Required | Product vision, users, value, non-goals |
| `docs/product/requirements.md` | Required | Functional/non-functional requirements and acceptance criteria |
| `docs/product/roadmap.md` | Required | Foundation-first phases and gates |
| `docs/architecture/overview.md` | Required | Layers, dependency direction, ownership principles |
| `docs/architecture/c4-context.md` | Required | User/external system context |
| `docs/architecture/c4-container.md` | Required | App/package/container boundaries |
| `docs/architecture/performance.md` | Required | Initial CPU/RAM/energy/event/buffer budgets |
| `docs/security/threat-model.md` | Required | Assets, actors, trust boundaries, baseline threats |
| `docs/quality/testing-strategy.md` | Required | Test pyramid, test doubles, lifecycle/security/performance tests |
| `docs/quality/f0-evidence.md` | Required | Recorded F0 composite verification evidence and its limits |
| `docs/development/setup.md` | Required | Clone/build/test prerequisites and commands |
| `docs/development/contributing.md` | Required | Branch/PR/code/review rules |
| `docs/development/agent-instructions.md` | Required | AI coding-agent boundaries and verification rules |
| `docs/references/boring-notch.md` | Required | Reference study/license/reuse policy |
| `docs/references/apple-apis.md` | Required | Public API map and adoption rules |
| `docs/architecture/decisions/` | Required | Initial architecture ADRs |

### F0 gate

- All required files exist.
- Links between core documents resolve.
- Product scope is consistent everywhere.
- ADRs record minimum OS, SwiftUI/AppKit, static modules, local IPC, event/action contracts, permission coordinator, performance budgets, public API policy, and docs-as-code.
- The composite verification seam and a green CI invocation are recorded in
  [F0 evidence](quality/f0-evidence.md) before F0 is closed.

---

## F1 — App shell and lifecycle

### Goal

Create a reliable menu-bar-first application and recovery path.

### Documents to create/update

| Document | Status | Required content |
|---|---|---|
| `docs/platform/macos-lifecycle.md` | Update | Startup/shutdown ordering, single instance, activation, sleep/wake, lock/unlock, termination |
| `docs/architecture/overview.md` | Update | App Shell/AppCoordinator ownership and lifecycle dependency |
| `docs/architecture/c4-container.md` | Update | App Shell container responsibilities and runtime sequence |
| `docs/product/requirements.md` | Update | FR-APP requirements and acceptance criteria |
| `docs/quality/testing-strategy.md` | Update | Launch/relaunch/quit/manual lifecycle tests |
| `docs/quality/f1-evidence.md` | Required | Automated and manual F1-gate evidence, including the macOS environment |
| `docs/operations/logging-diagnostics.md` | Optional | Create if startup/shutdown logging becomes a distinct operational contract |
| Relevant ADR | Update/Create | Startup model, single-instance, launch-at-login if architectural |

### F1 gate

- Startup/shutdown sequence documented and tested.
- Menu bar remains available when the surface fails.
- Sleep/wake and relaunch behavior has manual test evidence.
- F1 evidence records the automated result, the physical macOS manual result, and any unrun scenario.

---

## F2 — Notch surface shell

### Goal

Implement the native panel, geometry, interaction state machine, and safe recovery.

### Documents to create/update

| Document | Status | Required content |
|---|---|---|
| `docs/architecture/notch-surface.md` | Update | State machine, panel ownership, geometry, hit-testing, recovery |
| `docs/design/notch-interaction.md` | Required | Hover/click/Escape/timeout/progressive disclosure UX |
| `docs/platform/macos-lifecycle.md` | Update | Display, Space, full-screen, sleep/wake surface behavior |
| `docs/architecture/c4-container.md` | Update | NotchSurface container/component responsibilities |
| `docs/references/apple-apis.md` | Update | `NSPanel`, `NSScreen`, `NSEvent` adoption records |
| `docs/product/requirements.md` | Update | FR-SUR requirements and surface acceptance criteria |
| `docs/quality/testing-strategy.md` | Update | Geometry, state, lifecycle, manual display tests |
| `docs/quality/manual-qa.md` | Required | Real MacBook display/Space/full-screen/display matrix |
| Relevant ADR | Update/Create | Built-in-display-first, window policy, public API decision |

### F2 gate

- State machine/geometry tests pass.
- Real macOS panel manual tests pass for supported initial scope.
- No module or view directly owns the `NSPanel`.
- Collapsed hit-test region is safe.

---

## F3 — Design system and Settings UI

### Goal

Create consistent UI components and a complete Settings information architecture before adding real modules.

### Documents to create/update

| Document | Status | Required content |
|---|---|---|
| `docs/design/design-system.md` | Required | Color, typography, spacing, components, animation, material/contrast |
| `docs/design/notch-interaction.md` | Update | Visual behavior, progressive disclosure, compact content limits |
| `docs/design/settings-information-architecture.md` | Required | Settings sections and navigation |
| `docs/design/accessibility.md` | Required | VoiceOver labels, keyboard, contrast, reduced motion, focus |
| `docs/architecture/state-management.md` | Update | Focused UI stores, Observation, presentation snapshots |
| `docs/references/apple-apis.md` | Update | SwiftUI, Observation, MenuBarExtra usage records |
| `docs/product/requirements.md` | Update | Settings/UI/accessibility requirements |
| `docs/quality/testing-strategy.md` | Update | UI/accessibility/visual testing |
| `docs/quality/f3-evidence.md` | Required | Automated F3 evidence and explicit native manual-gate status |

F3 is a Settings shell, not an acceleration of later platform work. It may expose the nine
application-scene routes and their reusable presentation components, but a capability without
its owning phase is an explicit unavailable/placeholder state. Typed persistence and migration
remain F4; permission requests F5; Action Registry and shortcuts F6; module runtime F7; and
operational diagnostics F9.

### F3 gate

- Settings information architecture is complete.
- All reusable controls have accessibility behavior.
- Design tokens are used by placeholder and app shell UI.
- Reduced Motion is documented and testable.
- A future-phase route does not simulate persistence, request permission, capture a shortcut,
  execute an Action, start a Module, or poll Diagnostics.

---

## F4 — Typed settings and persistence

### Goal

Make settings durable, versioned, migratable, safe to reset, and separate from secrets.

### Documents to create/update

| Document | Status | Required content |
|---|---|---|
| `docs/architecture/data-persistence.md` | Update | Typed settings model, migration, atomic writes, Keychain, cache/retention |
| `docs/operations/privacy.md` | Required | Data classification, retention, export/delete commitments |
| `docs/architecture/state-management.md` | Update | SettingsStore/state projection/write flow |
| `docs/product/requirements.md` | Update | FR-SET requirements and data requirements |
| `docs/quality/testing-strategy.md` | Update | Migration/corruption/import/export tests |
| `docs/security/threat-model.md` | Update | Settings tampering, secret storage, data leakage threats |
| `docs/design/notchhub-settings-ui-spec.md` | Update | Durable setting rows, apply/rollback, reset, import, and export UX |
| Relevant ADR | Create/Update | Settings backend, schema strategy, Keychain boundary |

F4 persists only the v1 Appearance and Notch Behavior settings: theme, Reduced Motion override,
hover delay, and auto-collapse timeout. Full-screen suppression remains an invariant. F4
establishes an empty module namespace but does not create General, Shortcut, Diagnostics, or
module setting values; those remain owned by their later capability phases.

### F4 gate

- Migration fixtures exist for each schema version.
- Corrupt settings recover safely.
- Export excludes secrets.
- Reset behavior is explicit and tested.
- Privacy/retention rules are documented.

---

## F5 — Permission Center

### Goal

Centralize permission status and on-demand permission UX.

### Documents to create/update

| Document | Status | Required content |
|---|---|---|
| `docs/platform/permissions.md` | Update | Capability model, coordinator, request/recovery UX |
| `docs/references/apple-apis.md` | Update | Permission/API/entitlement adoption records |
| `docs/design/accessibility.md` | Update | Permission status/recovery accessibility |
| `docs/architecture/module-system.md` | Update | Module permission declarations |
| `docs/architecture/state-management.md` | Update | PermissionStore and availability projections |
| `docs/product/requirements.md` | Update | FR-PERM requirements |
| `docs/quality/testing-strategy.md` | Update | Permission adapter and manual permission matrix |
| `docs/security/threat-model.md` | Update | Permission overreach/revocation threats |
| `docs/design/notchhub-settings-ui-spec.md` | Update | Permission page groups, status/reason copy, and recovery row UX |
| Relevant ADR | Create/Update | Central PermissionCoordinator/on-demand policy |

### F5 gate

- No first-launch permission storm.
- Request context requires user initiation/reason.
- Denied/revoked/unavailable flows are tested.
- Modules cannot request permissions directly.

---

## F6 — Actions and shortcuts

### Goal

Create one typed, safe action model used by menu, Notch, shortcut, IPC, and future AI.

### Documents to create/update

| Document | Status | Required content |
|---|---|---|
| `docs/architecture/action-platform.md` | Update | IDs, schemas, authorization, confirmation, executors, timeout/cancel |
| `docs/architecture/ipc.md` | Update | Action route, source policy, request schema |
| `docs/architecture/state-management.md` | Update | ActionStore/running/result projection |
| `docs/design/settings-information-architecture.md` | Update | Action/shortcut Settings pages |
| `docs/references/apple-apis.md` | Update | `NSEvent`/shortcut API adoption record |
| `docs/product/requirements.md` | Update | FR-ACT requirements |
| `docs/quality/testing-strategy.md` | Update | Action/security/shortcut tests |
| `docs/security/threat-model.md` | Update | Arbitrary execution, replay, privilege bypass threats |
| `docs/design/notchhub-settings-ui-spec.md` | Update | Action/shortcut rows, availability, confirmation, and conflict UX |
| Relevant ADR | Create/Update | Typed actions/confirmation/source policy |

### F6 gate

- No arbitrary command path exists.
- Same ActionID works across entry points.
- Confirmation cannot be bypassed via IPC/future AI source.
- Shortcut permission/fallback behavior is documented.

---

## F7 — Module runtime and DemoModule

### Goal

Prove module lifecycle, isolation, settings, events, actions, UI slots, and cleanup before a real module exists.

### Documents to create/update

| Document | Status | Required content |
|---|---|---|
| `docs/architecture/module-system.md` | Update | Lifecycle, context, slots, health, static modules, cleanup |
| `docs/architecture/state-management.md` | Update | RuntimeStore/module presentation stores |
| `docs/architecture/event-protocol.md` | Update | Module lifecycle/demo event registry entries |
| `docs/architecture/action-platform.md` | Update | Module action registration/unregistration |
| `docs/architecture/performance.md` | Update | Module runtime policy and cleanup metrics |
| `docs/development/module-authoring.md` | Required | How to create/validate a module |
| `docs/modules/_template.md` | Required | Standard module documentation template |
| `docs/product/requirements.md` | Update | FR-MOD requirements |
| `docs/quality/testing-strategy.md` | Update | Module lifecycle/failure/resource tests |
| `docs/security/threat-model.md` | Update | Module privilege/failure/UI threat coverage |
| `docs/design/notchhub-settings-ui-spec.md` | Update | Module list/detail, enablement, health, and unavailable-state UX |

### F7 gate

- DemoModule can start/stop/disable/fail/restart safely.
- No resource leak after repeated enable/disable.
- Actions/events/settings/UI contribution are isolated and documented.
- Module authoring template is usable.

---

## F8 — EventBus and local IPC

### Goal

Implement the validated local event/action boundary and `notchctl`.

### Documents to create/update

| Document | Status | Required content |
|---|---|---|
| `docs/architecture/event-protocol.md` | Update | Envelope v1, event registry, validation, ordering, coalescing |
| `docs/architecture/ipc.md` | Update | Transport, auth, routes, framing, limits, shutdown |
| `docs/architecture/action-platform.md` | Update | IPC source/action policy |
| `docs/architecture/state-management.md` | Update | Event → store/presentation flow |
| `docs/architecture/c4-context.md` | Update | `notchctl`/local relay relationship if needed |
| `docs/architecture/c4-container.md` | Update | NotchIPC and CLI container details |
| `docs/security/ipc-security.md` | Required | Extracted detailed IPC threat/control document if scope warrants |
| `docs/security/threat-model.md` | Update | Unauthorized IPC, replay, flood, stale socket threats |
| `docs/quality/testing-strategy.md` | Update | IPC/auth/flood/backpressure tests |
| `docs/development/setup.md` | Update | Local IPC token/CLI setup |
| `docs/references/apple-apis.md` | Update | Network API adoption record if used |
| Relevant ADR | Update | Unix socket/loopback transport choice |
| `docs/design/notchhub-settings-ui-spec.md` | Update | Local IPC health/status presentation and safe recovery route |

### F8 gate

- Local IPC is loopback/socket only.
- Auth/source/schema/size/rate rules pass tests.
- `notchctl` can health/status/send a test event/invoke allowed foundation action.
- Raw commands/executor configuration are rejected.
- Flood/slow-client/shutdown behavior is bounded.

---

## F9 — Diagnostics and developer experience

### Goal

Make surface, runtime, settings, permissions, IPC, event, action, and performance behavior observable.

### Documents to create/update

| Document | Status | Required content |
|---|---|---|
| `docs/operations/logging-diagnostics.md` | Required | Log categories, levels, redaction, bounded diagnostics, export |
| `docs/architecture/data-persistence.md` | Update | Diagnostics retention/storage |
| `docs/architecture/performance.md` | Update | Metrics exposed through diagnostics |
| `docs/architecture/event-protocol.md` | Update | Diagnostic/performance event policy |
| `docs/platform/macos-lifecycle.md` | Update | Lifecycle diagnostic fields |
| `docs/quality/testing-strategy.md` | Update | Diagnostics/redaction tests |
| `docs/security/threat-model.md` | Update | Information-disclosure and audit controls |
| `docs/development/setup.md` | Update | Debug overlay/diagnostic troubleshooting |
| `docs/design/notchhub-settings-ui-spec.md` | Update | Diagnostics health, bounded sanitized records, export, and recovery UX |

### F9 gate

- A hidden/misplaced panel can be diagnosed.
- Module and IPC failure can be traced through sanitized records.
- Resource pressure is visible.
- Diagnostic export passes redaction tests.

---

## F10 — Quality, profiling, and Foundation Completion Gate

### Goal

Prove the base app is stable, secure, efficient, documented, and ready for a real module.

### Documents to create/update

| Document | Status | Required content |
|---|---|---|
| `docs/quality/testing-strategy.md` | Gate | Full unit/integration/UI/lifecycle/security/performance plan and results |
| `docs/quality/manual-qa.md` | Gate | Completed macOS lifecycle/display/permission matrix |
| `docs/quality/performance-test-plan.md` | Required | Scenario definitions, budgets, measurements, regression policy |
| `docs/architecture/performance.md` | Gate | Final measured budgets or ADR-approved changes |
| `docs/security/threat-model.md` | Gate | Threat review and mitigation status |
| `docs/platform/permissions.md` | Gate | Permission matrix/manual results |
| `docs/platform/macos-lifecycle.md` | Gate | Lifecycle recovery evidence |
| `docs/operations/privacy.md` | Gate | Data retention/export/delete review |
| `docs/operations/release.md` | Required before beta | Signing, notarization, versioning, release checklist |
| All ADRs | Gate | Status accurate: Accepted/Superseded/Rejected |
| `docs/index.md` | Update | Mark completed phase and link evidence |

### F10 gate

- All requirements/architecture/test/security/performance gates pass.
- No critical/high unresolved issue affecting foundation.
- DemoModule isolation/resource cleanup passes.
- Foundation evidence is linked from roadmap/index.
- Only after this gate may M0/M1 real module work begin.

---

## 6. Future module documentation phases

## M0 — Sample Status Module

### Required module documents

| Document | Purpose |
|---|---|
| `docs/modules/sample-status.md` | Purpose, slots, settings, events/actions, runtime policy, privacy, tests |
| `docs/architecture/module-system.md` | Update if real contribution behavior reveals contract gaps |
| `docs/architecture/event-protocol.md` | Add sample event schemas/fixtures |
| `docs/architecture/action-platform.md` | Add sample action definitions |
| `docs/quality/testing-strategy.md` | Add module test results |
| `docs/architecture/performance.md` | Add measured module resource policy |

### M0 gate

- Real module contribution works without changing `NotchPanelController`.
- Multiple slot/priority behavior is tested.
- Module document is complete.

---

## M1 — Xiaozhi Display Companion

### Required module/integration documents

| Document | Purpose |
|---|---|
| `docs/modules/xiaozhi-display.md` | Module purpose, states, UI slots, permissions, transcript/privacy, actions, tests |
| `docs/integrations/xiaozhi-relay.md` | Relay boundary, normalized event mapping, reconnect/session behavior |
| `docs/architecture/event-protocol.md` | `assistant.*` event schemas/versions/fixtures |
| `docs/architecture/ipc.md` | Relay client authentication/source policy/stream route |
| `docs/architecture/action-platform.md` | `xiaozhi.*` action allow-list and confirmation |
| `docs/architecture/data-persistence.md` | Transcript retention/memory/cache policy |
| `docs/architecture/performance.md` | Text coalescing/20–30 Hz snapshot/audio policy if applicable |
| `docs/platform/permissions.md` | Confirm display-only mode requires no Microphone permission |
| `docs/security/threat-model.md` | Relay trust/privacy/credential/data-flow threats |
| `docs/quality/testing-strategy.md` | Transcript sequence/Unicode/reconnect/redaction tests |

### M1 gate

- Display-only mode works without Microphone permission.
- Raw Xiaozhi protocol/audio does not enter `NotchSurface`.
- Transcript data is bounded and privacy policy is explicit.
- Assistant actions cannot become arbitrary command paths.

---

## M2 — Media or Clipboard

### Required documents

| Document | Purpose |
|---|---|
| `docs/modules/media.md` or `docs/modules/clipboard.md` | Module contract and user value |
| `docs/platform/permissions.md` | Capability/permission decision if needed |
| `docs/architecture/data-persistence.md` | Artwork/history/clipboard retention and clear behavior |
| `docs/architecture/performance.md` | Observer/polling/cache budgets |
| `docs/security/threat-model.md` | User-content/privacy threats |
| `docs/quality/testing-strategy.md` | Module-specific tests |
| `docs/design/notch-interaction.md` | Compact/expanded interaction updates |

### M2 gate

- Data retention is opt-in/clear where sensitive.
- Module does not cause idle polling/resource regression.
- Existing modules remain isolated.

---

## M3 — Files or System Controls

### Required documents

- `docs/modules/files.md` or `docs/modules/system-controls.md`.
- Permission/API adoption record in `docs/references/apple-apis.md`.
- Data/cache/retention update.
- Threat-model update.
- Action confirmation/security update.
- Performance/profile plan.
- Manual QA for external displays, file drops, settings, and accessibility.

### M3 gate

- File/system access is user initiated and permissioned.
- No arbitrary file execution or system-control injection.
- Cache and file metadata are bounded and deletable.

---

## M4 — Calendar or Reminders

### Required documents

- `docs/modules/calendar.md` or `docs/modules/reminders.md`.
- `docs/platform/permissions.md` update.
- `docs/references/apple-apis.md` EventKit adoption record.
- `docs/architecture/data-persistence.md` retention/TTL update.
- Threat model/privacy copy/manual permission tests.
- Performance refresh/activation policy.

### M4 gate

- Permission requested only on feature use.
- Event/reminder data not written to generic diagnostics.
- Denied access does not affect core app.

---

## M5 — Native Xiaozhi Voice

### Required documents

- `docs/modules/native-xiaozhi-voice.md`.
- `docs/references/apple-apis.md` AVFoundation record.
- `docs/platform/permissions.md` Microphone/audio behavior.
- `docs/architecture/event-protocol.md` audio/assistant event policy.
- `docs/architecture/data-persistence.md` transcript/audio retention.
- `docs/architecture/performance.md` audio/energy/thermal profile.
- `docs/security/threat-model.md` microphone/audio/backend data flow.
- `docs/quality/testing-strategy.md` audio lifecycle/permission/performance tests.
- ADR if native audio changes architecture or distribution.

### M5 gate

- M1 has demonstrated user value for native Mac audio.
- Active capture state is visible.
- Raw audio is not persisted by default.
- Permission/revocation/device-switch/thermal behavior is tested.

---

## 7. Documents by change type

Use this routing table when implementing a change.

| Change | Must update | Usually also update |
|---|---|---|
| New app lifecycle state | `platform/macos-lifecycle.md`, requirements | overview, testing, ADR |
| New Notch state/transition | `architecture/notch-surface.md` | design, state-management, testing |
| New SwiftUI observation/store | `architecture/state-management.md` | performance, testing |
| New setting | requirements, data-persistence | settings IA, privacy, testing |
| New settings schema | data-persistence | ADR, testing, privacy |
| New permission | platform/permissions | Apple APIs, threat model, privacy, testing |
| New ActionID | action-platform | requirements, IPC if exposed, threat model, tests |
| New action executor | action-platform | threat model, ADR, performance, testing |
| New event type | event-protocol | state-management, presentation/design, fixtures, testing |
| New IPC operation/route | ipc | event/action docs, threat model, setup, tests |
| New module | module-system + `docs/modules/<id>.md` | settings, permissions, events, actions, data, performance, security, testing |
| New cache/history/persistence | data-persistence | privacy, threat model, performance, testing |
| New Apple framework/API | references/apple-apis | owner component, permission/release docs, ADR if needed |
| New timer/observer/background task | performance | lifecycle, module, testing |
| New external process/relay | C4 context/container | IPC, threat model, release, ADR |
| New distribution/entitlement | Apple APIs, permissions, release | threat model, ADR, setup |
| UI visual behavior | design-system/notch-interaction | requirements, accessibility, testing |
| Security boundary | threat-model | IPC/action/permission/data docs, ADR, tests |

---

## 8. Document templates

## 8.1 ADR template

```markdown
# ADR-NNNN: <Decision title>

## Status

Proposed | Accepted | Superseded | Rejected

## Context

## Decision

## Alternatives considered

## Consequences

## Security/privacy/performance impact

## Testing/documentation impact

## Links
```

## 8.2 Module document template

```markdown
# <Module Name>

## Purpose
## User value
## Non-goals
## Module ID/version
## Dependencies
## UI slots/content limits
## Settings schema/migration/reset
## Required/optional permissions
## Events in/out
## Actions and confirmation
## Runtime/performance policy
## Persistence/retention/delete
## Privacy and security
## Failure/degraded/reconnect behavior
## Accessibility
## Diagnostics
## Test plan
## Manual QA
## Open questions
```

## 8.3 API adoption template

```markdown
# <API/framework>

## Purpose
## Minimum macOS availability
## Owner container/package
## Required permissions/entitlements
## Data accessed
## Fallback/unavailable behavior
## Lifecycle/cleanup
## Performance/energy impact
## Security/privacy impact
## Tests
## Distribution impact
## ADR/link
```

## 8.4 Event registry template

```markdown
# <event.type>

## Status
## Version
## Producers
## Consumers
## Payload schema
## Required/optional fields
## Maximum size/rate
## Ordering/sequence/correlation
## Privacy classification
## Presentation policy
## Coalescing policy
## Error behavior
## Fixtures/tests
```

---

## 9. Documentation review checklist

Before merging documentation/code changes:

```text
[ ] Correct authoritative document identified
[ ] Links/anchors work
[ ] Status/date/owner updated when appropriate
[ ] Product scope remains consistent
[ ] Requirements and acceptance criteria updated
[ ] Architecture/ADR updated when durable decision changed
[ ] Permission/security/privacy impact documented
[ ] Performance/resource impact documented
[ ] Tests/fixtures/manual QA documented
[ ] No secrets or personal data included
[ ] AI-agent instructions remain consistent
```

### Documentation quality rules

- Prefer precise language over marketing language.
- State non-goals and failure behavior, not only happy-path features.
- Use tables for ownership, phase gates, and requirements.
- Use Mermaid for diagrams that should diff in Git.
- Include examples that are synthetic and sanitized.
- Keep links relative inside the repository.
- Do not claim an implementation exists when it is only planned; label it `Future`, `Planned`, or `Not implemented`.
- Review license/reference claims when source projects change.

---

## 10. Foundation documentation gate

The documentation set is ready for real module work only when:

- Product vision, requirements, roadmap, architecture context/container, and ADRs agree.
- `NotchSurface`, `State Management`, `Module System`, `Event Protocol`, `Action Platform`, `IPC`, `Data Persistence`, and `Performance` documents describe actual contracts.
- Permissions and lifecycle behavior are documented and testable.
- Threat model and testing strategy cover all foundation boundaries.
- Setup/contributing/agent instructions are sufficient for a clean clone and safe change.
- Boring Notch and Apple API references have license/public-API boundaries.
- F10 evidence is linked from the roadmap and index.

---

## 11. Documentation completion checklist by phase

```text
F0  [x] product docs       [x] architecture docs       [x] ADRs
    [x] security baseline  [x] quality baseline        [x] setup/contributing
    [x] recorded green pull-request verification run

F1  [x] scoped lifecycle   [x] app shell requirements  [x] test plan/evidence template
    [ ] implementation     [ ] startup/quit tests       [ ] manual macOS evidence

F2  [ ] notch surface      [ ] interaction design     [ ] Apple API records
    [ ] geometry/manual QA [ ] lifecycle updates       [ ] state tests

F3  [ ] design system      [ ] settings IA            [ ] accessibility
    [ ] focused state docs [ ] UI tests

F4  [ ] persistence        [ ] migrations             [ ] privacy/retention
    [ ] Keychain policy    [ ] corruption/import tests

F5  [ ] permissions        [ ] user copy              [ ] API/entitlement record
    [ ] threat update      [ ] permission matrix/tests

F6  [ ] action platform    [ ] shortcut UI             [ ] IPC action schema
    [ ] security tests     [ ] confirmation tests

F7  [ ] module system      [ ] module template         [ ] DemoModule docs/tests
    [ ] resource policy    [ ] failure isolation

F8  [ ] event protocol     [ ] IPC contract             [ ] `notchctl` setup
    [ ] auth/threat update [ ] flood/backpressure tests

F9  [ ] diagnostics        [ ] logging/redaction        [ ] performance metrics
    [ ] privacy export     [ ] troubleshooting

F10 [ ] manual QA results  [ ] profile results           [ ] threat review
    [ ] release plan       [ ] ADR status                [ ] foundation gate

M0  [ ] module document    [ ] slot/event/action tests  [ ] performance policy
M1  [ ] Xiaozhi module     [ ] relay contract            [ ] privacy/security
    [ ] transcript tests   [ ] no-mic display test       [ ] performance profile
M2+ [ ] module document    [ ] permission/data review   [ ] tests/diagnostics
```

---

## 12. Suggested implementation order for documentation

If the repository is being created from an empty scaffold, write documents in this order:

1. `README.md`.
2. `docs/index.md`.
3. `docs/product/vision.md`.
4. `docs/product/requirements.md`.
5. `docs/product/roadmap.md`.
6. `docs/architecture/overview.md`.
7. `docs/architecture/c4-context.md`.
8. `docs/architecture/c4-container.md`.
9. Initial ADRs.
10. `docs/security/threat-model.md`.
11. `docs/quality/testing-strategy.md`.
12. `docs/development/setup.md` and `contributing.md`.
13. `docs/references/boring-notch.md` and `apple-apis.md`.
14. Foundation component docs: `notch-surface`, `state-management`, `module-system`, `event-protocol`, `action-platform`, `ipc`, `data-persistence`, `performance`.
15. Platform docs: `permissions`, `macos-lifecycle`.
16. F3/F9/F10 operational/design docs as their implementation begins.
17. Module docs only when the Foundation Completion Gate passes.

This order minimizes rework: product boundaries come before architecture, contracts before code, and module details after platform contracts are proven.

---

## 13. Current document inventory

### Present/created

- `README.md`
- `docs/index.md`
- `docs/product/vision.md`
- `docs/product/roadmap.md`
- `docs/product/requirements.md`
- `docs/architecture/overview.md`
- `docs/architecture/c4-context.md`
- `docs/architecture/c4-container.md`
- `docs/architecture/module-system.md`
- `docs/architecture/notch-surface.md`
- `docs/architecture/state-management.md`
- `docs/architecture/event-protocol.md`
- `docs/architecture/action-platform.md`
- `docs/architecture/ipc.md`
- `docs/architecture/data-persistence.md`
- `docs/architecture/performance.md`
- `docs/platform/permissions.md`
- `docs/platform/macos-lifecycle.md`
- `docs/quality/testing-strategy.md`
- `docs/security/threat-model.md`
- `docs/references/boring-notch.md`
- `docs/references/apple-apis.md`
- `docs/development/setup.md`
- `docs/development/contributing.md`
- `docs/development/agent-instructions.md`
- `docs/development/tooling/mattpocock-skills.md`

### Still to create when relevant

- `docs/design/design-system.md`.
- `docs/design/notch-interaction.md`.
- `docs/design/settings-information-architecture.md`.
- `docs/design/accessibility.md`.
- `docs/operations/logging-diagnostics.md`.
- `docs/operations/privacy.md`.
- `docs/operations/release.md`.
- `docs/development/module-authoring.md`.
- `docs/quality/manual-qa.md`.
- `docs/quality/performance-test-plan.md`.
- `docs/security/ipc-security.md` if the IPC threat detail becomes large enough to extract.
- Module/integration documents only after the foundation gate.

The inventory must be updated whenever files are created, renamed, deprecated, or replaced.

---

## 14. Change control

Update this index when:

- A document is created/renamed/removed.
- A document changes authority or status.
- A roadmap phase changes its gate/deliverables.
- A new module/document template is introduced.
- A product boundary changes (which requires a separate product decision and ADR).
- A new security/privacy/permission/API boundary is introduced.

The index is not a substitute for the authoritative documents; it is the map that keeps the whole documentation set navigable and phase-aware.
