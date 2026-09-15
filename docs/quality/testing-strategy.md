# Testing Strategy
## NotchHub — Quality, Verification, and Release Confidence

**Status:** Draft v0.1  
**Owner:** Quality / Architecture  
**Last updated:** 2026-09-14
**Location:** `docs/quality/testing-strategy.md`  
**Related documents:** [Requirements](../product/requirements.md), [Roadmap](../product/roadmap.md), [Architecture Overview](../architecture/overview.md), [State Management](../architecture/state-management.md), [Event Protocol](../architecture/event-protocol.md), [Action Platform](../architecture/action-platform.md), [IPC](../architecture/ipc.md), [Permissions](../platform/permissions.md), [Performance](../architecture/performance.md), [Boring Notch Reference](../references/boring-notch.md)

---

## 1. Purpose

This document defines the test strategy for NotchHub across domain logic, macOS AppKit/SwiftUI behavior, permissions, settings, module lifecycle, events, actions, local IPC, privacy, performance, energy, and release readiness.

NotchHub is a menu-bar utility whose most difficult failures are often environment-dependent rather than obvious in a single UI screenshot. The application must therefore be tested as:

- A pure Swift domain system.
- A stateful, concurrent runtime.
- A native macOS windowing application.
- A local IPC server/client boundary.
- A modular host with failure isolation.
- A long-running, battery-sensitive background utility.

The strategy is **risk-based and foundation-first**. No real business module—especially the future Xiaozhi Display Companion—may be added until the foundation has passed the Foundation Completion Gate.

---

## 2. Quality goals

1. **Correctness** — state, settings, events, actions, permissions, and module behavior match documented contracts.
2. **Reliability** — the app survives common macOS lifecycle/display changes and recovers from partial failures.
3. **Isolation** — one module, client, or event handler cannot crash or disable unrelated platform behavior.
4. **Security** — untrusted IPC/imported input cannot bypass validation, permissions, authorization, or action policy.
5. **Responsiveness** — Notch interaction is immediate; main actor is not blocked by I/O or high-rate streams.
6. **Efficiency** — idle CPU/RAM/wakeup/energy impact remains within budget over long runs.
7. **Privacy** — secrets and sensitive user content do not enter logs, fixtures, diagnostics exports, or test artifacts.
8. **Maintainability** — tests are close to the contracts they protect and run consistently in CI.
9. **Accessibility** — core actions and status/error states remain usable by keyboard and accessibility tools.
10. **Release confidence** — a release candidate has repeatable evidence, not only a manual happy-path demonstration.

---

## 3. Testing principles

### Test the contract, not the implementation detail

Test event envelopes, state transitions, action policy, settings migrations, module lifecycle, and observable behavior. Avoid tests coupled to private helper method names unless the helper itself is a public architectural boundary.

### Keep core tests AppKit-free

Pure state, event, action, settings, and module-runtime tests should not require a real `NSPanel`, display server, permission prompt, or running application scene.

### Use real macOS tests for macOS behavior

Window levels, Spaces, full-screen, display topology, permission prompts, menu-bar behavior, sleep/wake, and Accessibility behavior require integration/manual testing on macOS. Mocks alone are not sufficient.

### Prefer deterministic fixtures

Use fixed event payloads, timestamps where practical, fake clocks, test transports, permission adapters, and controlled state stores. Do not place real credentials, personal transcripts, clipboard data, or absolute personal paths into fixtures.

### Test failure and recovery first-class

Every subsystem must define what happens when data is invalid, permission is denied, a module fails, a display disappears, IPC clients flood the app, or persistence fails.

### Performance is a quality test

CPU, memory, wakeups, event rate, animation hitches, and cleanup behavior must be measured before adding high-rate modules or declaring the foundation complete.

---

## 4. Test pyramid

```text
                         ┌──────────────────────┐
                         │ Release/soak/profile │
                         │ Manual macOS matrix  │
                         └──────────┬───────────┘
                                    │
                       ┌────────────▼────────────┐
                       │ UI automation + system  │
                       │ lifecycle/integration    │
                       └────────────┬────────────┘
                                    │
                ┌───────────────────▼───────────────────┐
                │ Package integration / IPC / runtime    │
                └───────────────────┬───────────────────┘
                                    │
       ┌────────────────────────────▼────────────────────────────┐
       │ Pure unit tests: domain, state, events, actions, stores │
       └─────────────────────────────────────────────────────────┘
```

### Test layers

| Layer | Purpose | Typical speed | Environment |
|---|---|---:|---|
| Unit | Pure logic/contracts/reducers/validators | Very fast | Any CI macOS runner |
| Package integration | Stores, EventBus, ModuleRuntime, ActionRegistry, IPC routing | Fast–medium | macOS CI, test doubles |
| UI automation | Settings/menu/Notch interactions and accessibility | Medium | Dedicated macOS test machine |
| System/lifecycle | Spaces, full-screen, sleep/wake, displays, permissions | Slow | Physical/controlled macOS environment |
| Performance/energy | CPU/RAM/wakeups/latency/hitches/soak | Slow | Representative supported Macs |
| Release smoke | Signed/notarized-like app, launch/quit/permissions | Medium–slow | Release candidate environment |

---

## 5. Test architecture

### 5.1 Test seams

The codebase must provide injectable seams for:

- Clock/time and timeout behavior.
- Screen topology and display geometry.
- Window/panel controller.
- Pointer and keyboard monitors.
- Permission adapter.
- Settings backend/file system.
- Keychain/secret store.
- IPC transport.
- Event clock/sequence source.
- Module runtime scheduler.
- Action executor.
- Diagnostics sink.
- Resource tracker/task registry.

### 5.2 Test doubles

| Double | Purpose |
|---|---|
| `FakeClock` | Deterministic timeout/debounce/retry tests |
| `FakeScreenTopology` | Geometry and display-change tests without display mutation |
| `FakePanelController` | Verify surface intents without AppKit |
| `FakePermissionAdapter` | Grant/deny/revoke/restricted/unavailable transitions |
| `InMemorySettingsBackend` | Migration/corruption/write-failure tests |
| `TestSecretStore` | Keychain behavior without real credentials |
| `InMemoryIPCTransport` | Request routing, auth, rate-limit, framing tests |
| `FakeActionExecutor` | Confirmation, result, timeout, cancellation tests |
| `FakeEventBus`/fixture bus | Module subscription and event projection tests |
| `ResourceTracker` | Task/timer/observer/socket cleanup assertions |
| `FakeDiagnosticsSink` | Redaction and bounded-history tests |

No test double may weaken a security contract. For example, an IPC fake must still enforce authentication/source policy, and a fake action executor must still receive only validated typed input.

---

## 6. Unit testing requirements

## 6.0 F1 app-shell and lifecycle

Required automated coverage:

- `AppCoordinator` startup is idempotent and tears down F1-owned observers/tasks in reverse order.
- The menu exposes exactly Settings, Restart App Shell, and Quit.
  scenes; surface/demo intents report unavailable; Restart App Shell does not create a module runtime.
- Activation, deactivation, sleep, wake, lock, and unlock are observable without creating an `NSPanel` or
  requesting a permission.
- The `SMAppService` launch-at-login adapter is behind a fakeable protocol; no test changes the
  machine’s actual login-item registration.

Required manual macOS evidence:

- Cold launch, quit, and relaunch leave one reachable menu-bar item and no hung process.
- Settings and Diagnostics placeholders remain reachable if the other scene is closed or fails.
- Sleep/wake and activation/deactivation preserve a usable menu bar and do not show a panel or
  permission prompt.

F1 does not claim the panel, persistent settings, ModuleRuntime, IPC, or full diagnostics cases
listed in later sections; those remain phase-specific gates.

## 6.1 `NotchDomain`

Required coverage:

- `ModuleID`, `ActionID`, `SessionID` validation/equality/coding.
- `SurfaceState` and event type coding.
- `EventEnvelope` encode/decode.
- Action input/result/error models.
- Module metadata and resource policy validation.
- Permission kind/status coding.
- Version/compatibility rules.

**Target:** near-complete coverage of pure types and validators.

## 6.2 Surface state machine

Required cases:

- Every valid transition from `hidden`, `collapsed`, `compact`, `expanded`, `suppressed`, and `recovering`.
- Invalid transition rejection/normalization.
- User interaction priority over auto-collapse.
- Full-screen suppression and clearing.
- Screen/panel invalidation always entering bounded recovery.
- Recovery success/failure convergence.
- User disable behavior.
- Long-form content is handled by dedicated application scenes and does not add a `detail` state to the Notch surface state machine.
- Hover-origin exit closes only after the 100 ms grace, cancels on re-entry, and is held by active keyboard/popover/drag/confirmation/accessibility leases.
- Expanded admission distinguishes insufficient safe geometry from invalid topology/native panel failure; only the latter enters recovery.
- `expandedAvailability` expires on topology invalidation and is refreshed by topology revision; historical admission rejection is asserted through bounded Diagnostics events.
- Duplicate events and idempotent commands.

Use a fake clock and fake panel controller. Do not create a real `NSPanel` for these tests.

## 6.3 Geometry

Required cases:

- Physical-notch built-in display.
- No-notch fallback.
- Retina scale/resolution changes.
- Safe on-screen frame.
- Menu-bar overlap prevention.
- Built-in display unavailable.
- External display attached/detached.
- Invalid/zero screen bounds.

Assertions should test invariants (inside usable screen bounds, correct anchor, no illegal overlap) rather than only one hard-coded pixel value.

## 6.4 State management

Required cases:

- Store defaults.
- Command/event projection.
- Narrow snapshot updates.
- Bounded history rotation.
- Coalescing/throttling.
- Concurrent event ordering guarantees.
- Cancellation and subscription cleanup.
- Failed state versus suspended/stopped state.
- No unrelated store invalidation in focused projections.

## 6.5 Settings and persistence

Required cases:

- Default settings.
- Typed mutation validation.
- Schema migration for every version.
- Unknown future schema.
- Corrupt/truncated settings.
- Corrupt-settings quarantine rotation (three 1 MiB files, 3 MiB total) and export exclusion.
- Atomic write failure.
- Debounced writes.
- Reset scopes.
- Sanitized import/export.
- Secrets excluded from export.
- Module namespace isolation.
- Persistence failure leaves last-known-good settings intact.

## 6.6 Permissions

Required cases:

- `notDetermined → authorized`.
- `notDetermined → denied`.
- `authorized → denied/revoked`.
- `restricted`.
- `unavailable`.
- Concurrent duplicate requests are deduplicated.
- Requests without user initiation/reason are rejected before the system adapter.
- Module availability changes after status update.
- No prompt loop after denial.
- Diagnostics contains status metadata but no sensitive content.

## 6.7 Action platform

Required cases:

- Registration and duplicate ID rejection.
- Namespace ownership.
- Input schema validation.
- Availability based on module/permission/settings state.
- Source allow-list.
- Confirmation policies.
- User rejection produces no executor call.
- Timeout/cancellation/result mapping.
- Progress coalescing.
- Action removal/unavailability when module stops.
- Raw command/script/executor config rejection.
- Audit redaction.

## 6.8 Module runtime

Required cases:

- Register/start/stop.
- Start throw.
- Start timeout.
- Double start/stop.
- Suspend/resume.
- Enable/disable.
- Bounded retry.
- Failure isolation.
- Module health projection.
- Resource cleanup through `ResourceTracker`.
- Actions/subscriptions removed or unavailable after stop.

## 6.9 Event protocol

Required cases:

- Valid envelope.
- Missing/invalid required fields.
- Unknown protocol/event version.
- Unknown source/event type.
- Payload size/depth/string limits.
- Timestamp/skew policy.
- Event ID deduplication.
- Sequence regression/gap.
- Correlation ID propagation.
- Rate limiting/coalescing.
- One subscriber failure does not cancel others.
- Sensitive data redaction.

## 6.10 Local IPC

Required cases:

- Framing and decoding.
- Auth success/failure/revocation.
- Client/source allow-list.
- Health/status routes.
- Valid event route.
- Valid foundation action route.
- Unknown action/operation rejection.
- Raw command field rejection.
- Oversized/deep/malformed payload.
- Rate limiting/backpressure.
- Slow WebSocket/client disconnect, if enabled.
- Graceful shutdown with active clients.
- Stale Unix socket handling.

---

## 7. Integration testing

### 7.1 Core event path

```text
fixture/client
    → transport
    → authentication
    → payload validation
    → EventRouter
    → EventBus
    → module/store projection
    → PresentationPolicy
    → focused UI snapshot
```

Verify both success and rejection. A valid event should reach only its allowed consumers; an invalid event should never reach module handlers.

### 7.2 Action path

```text
menu/notch/shortcut/IPC test input
    → ActionRegistry
    → authorization/confirmation
    → fake typed executor
    → result event
    → presentation/diagnostics
```

Verify all entry points use the same action implementation and that user confirmation cannot be bypassed through IPC or a future external source.

### 7.3 Module lifecycle path

- Register `DemoModule`.
- Start it.
- Observe status/action/event contribution.
- Disable it.
- Verify action removal/unavailability, surface contribution removal, subscriptions/tasks cleanup, and unchanged core health.
- Simulate start/handler failure.
- Verify Settings, Diagnostics, Notch core, and unrelated modules remain functional.

### 7.4 Settings/permissions path

- Enable a permission-dependent test capability.
- Show explanation.
- Fake deny.
- Verify degraded state and System Settings recovery action.
- Fake grant and app activation.
- Verify module resumes without app restart.
- Reset non-secret settings and verify secret store remains unchanged.

---

## 8. UI and accessibility testing

### F3 Settings-shell boundary tests

Before later feature owners exist, automate the nine Settings routes, shared component states,
keyboard order, VoiceOver labels, contrast semantics, and Reduced Motion behavior. Assert that
opening a placeholder route does not write settings, request a permission, capture a shortcut,
execute an Action, start a Module, or begin diagnostics polling. Persistence, permission,
shortcut, Action, Module, and Diagnostics behavior is verified only in F4–F9 tests.

### 8.1 UI automation scope

Automate where stable:

- Menu bar menu opens and exposes core actions.
- Settings navigation through all foundation sections.
- Settings control updates preview/persistence.
- Permission row status/disabled/recovery states.
- Shortcut recorder input/clear/conflict display.
- Modules page enable/disable/health/error display.
- Diagnostics page filtering/export action.
- Notch expanded/compact/collapse behavior using controlled interaction/test hooks.
- Application-scene navigation does not mutate `SurfaceState` or create unbounded duplicate windows.
- Error/empty/loading states.

### 8.2 Accessibility checks

- VoiceOver can identify controls, state, and action purpose.
- Keyboard navigation reaches Settings controls and action buttons.
- Focus does not become trapped in an invisible/suppressed Notch panel.
- Status is not conveyed by color alone.
- Reduced Motion disables/reduces continuous animations.
- Dynamic text/contrast remain usable in Settings/application scenes.

### 8.3 Visual testing

Use snapshots cautiously:

- Prefer snapshots for stable design-system components and deterministic states.
- Do not make full-screen/window pixel snapshots the only proof of macOS panel correctness.
- Allow for display scale, font rendering, OS theme, and macOS version differences.
- Use accessibility/state assertions in addition to visual comparison.

---

## 9. macOS lifecycle and system testing

These tests require a real macOS environment and should be maintained as a manual/automation matrix.

| Scenario | Expected result |
|---|---|
| First launch | No unsolicited sensitive permission prompts; menu bar and Settings available |
| Relaunch | Single app instance; settings/modules restore safely |
| Quit | IPC, modules, observers, and panel shut down cleanly |
| Sleep/wake | Surface revalidates; no crash/stuck recovery; core remains usable |
| Lock/unlock | No crash; permission/status refresh is correct when app active |
| Space switch | Surface follows documented collection/suppression policy |
| Full-screen app | Suppression policy is consistent and user-configurable |
| Menu-bar auto-hide | Menu bar recovery path remains usable when visible |
| External display attach/detach | Built-in-display policy remains safe; no off-screen panel |
| Display scale/resolution change | Geometry recomputes and remains on-screen |
| Lid close/open | Built-in display unavailable policy behaves predictably |
| Permission denied/granted | Module degrades/resumes correctly without retry loop |
| App activation after System Settings | Permission status refreshed |
| Multiple local clients | Auth/source policy and rate limits work |

### Boring Notch reference testing

Where Boring Notch provides useful implementation clues, use it as a reference for edge-case hypotheses—not as an oracle. Test NotchHub's documented behavior and implementation independently, and keep any license/reference notes in `docs/references/boring-notch.md`.

---

## 10. Security and privacy testing

### Security tests

- IPC unauthenticated request.
- Invalid/revoked token.
- Unknown client ID.
- Unauthorized source/event/action combination.
- Oversized/deeply nested payload.
- Schema smuggling/unknown executor fields.
- Raw shell/script/executable-path input.
- Malicious URL scheme/host input.
- Rate-limit bypass attempts.
- Replay/duplicate request behavior.
- Stale socket/path permissions.
- WebSocket slow-consumer/backpressure behavior.
- Diagnostics and export redaction.
- Secret store failure handling.

### Privacy tests

- No secrets in normal logs.
- No tokens in Diagnostics export.
- No raw microphone/camera/screen/transcript/clipboard/file/calendar data in generic fixtures.
- Sensitive module data retention follows its module document.
- Reset/export/import do not unintentionally expose or delete credentials.
- Permission denial does not cause hidden collection.

### Threat-model traceability

Every security test should link to a threat scenario in `docs/security/threat-model.md` or the relevant module threat document.

---

## 11. Performance and energy testing

## 11.1 Baseline budgets

| Scenario | Target |
|---|---|
| Idle/collapsed | < 0.3% average CPU; 40–80 MB target; no fast polling |
| Expanded/no stream | < 1–2% average CPU; 60–120 MB target; open < 150 ms |
| Local compact event | Event-to-UI < 100 ms under normal load; no unbounded growth |
| Future text stream | 20–30 UI snapshots/s max; memory < 150 MB target |
| Module toggle | Resources return near baseline after stop |

### 11.2 Required scenarios

#### PT-001 — Idle soak

- Duration: at least 8 hours where practical.
- Surface: hidden/collapsed.
- Modules: foundation/DemoModule only as specified.
- Measure CPU, memory, wakeups, timer fires, disk/network, energy impact.

#### PT-002 — Surface stress

- 1,000 open/collapse/expand cycles.
- Include hover, click, Escape, click-outside, timeout.
- Measure allocations, native window count, observers, tasks, hitches, final memory.

#### PT-003 — Event flood

- High-rate valid/invalid/duplicate/oversized/unauthorized events.
- Verify bounded queues, coalescing, drop/reject counters, UI responsiveness.

#### PT-004 — Text-stream simulation

- 20–100 deltas/s, long Vietnamese Unicode, sequence gaps/duplicates/final event.
- Verify assembler correctness, 20–30 UI flush cap, memory bound, no main-actor blocking.

#### PT-005 — Operation-output flood

- 10,000+ lines from an in-scope future desktop operation/status source.
- Verify bounded tail/history and responsive application scene.

#### PT-006 — Module toggle loop

- Enable/disable/restart DemoModule 100 times.
- Verify no growth in active tasks/timers/subscriptions/actions/cache.

#### PT-007 — Lifecycle/display stress

- Sleep/wake, lock/unlock, Spaces, full-screen, external display, scale/resolution.
- Verify recovery and no orphan resources.

#### PT-008 — Persistence stress

- Repeated settings changes, migration/import/export, corrupt data/storage failure.
- Verify debounce, atomic recovery, no UI block, bounded diagnostics.

### 11.3 Tools

Use:

- SwiftUI Instrument.
- Time Profiler.
- Allocations.
- Leaks.
- Energy Log.
- Hangs and Hitches.
- Activity Monitor.

Record macOS version, Mac model/RAM, display configuration, app build, modules/settings, scenario duration, tool template, and summarized results.

---

## 12. Test data and fixtures

### Fixture directory

```text
Tests/
├── Fixtures/
│   ├── Events/
│   ├── Settings/
│   ├── Permissions/
│   ├── Actions/
│   ├── IPC/
│   └── Screens/                       # only sanitized/stable visual fixtures
├── TestDoubles/
├── IntegrationTests/
├── UIAutomationTests/
└── PerformanceTests/
```

### Fixture rules

- Use synthetic IDs, timestamps, text, paths, and tokens.
- Use Vietnamese Unicode cases where future transcript/UI behavior is relevant.
- Include malformed and hostile-but-safe test inputs.
- Never commit real credentials, authorization headers, personal transcripts, clipboard data, calendar details, file contents, audio, camera frames, or screen captures.
- Document fixture schema/version.
- Keep large profiling artifacts outside Git or in a controlled artifact store.

---

## 13. CI and local developer workflow

### Pull request checks

Minimum CI checks:

1. Resolve packages.
2. Build the app target.
3. Run domain/core/package unit tests.
4. Run integration tests that do not require interactive permission/display manipulation.
5. Validate Markdown/docs links or required document presence.
6. Run formatting/lint checks according to repository policy.
7. Check for accidental secrets in changed files where a suitable scanner is available.

### Main/release checks

- Full automated test suite.
- Signed build smoke test.
- macOS UI/lifecycle matrix as available.
- Performance smoke/baseline scenarios.
- Privacy/security test suite.
- Diagnostics export/redaction test.

### Local developer workflow

```text
make/bootstrap or documented setup
        ↓
format/lint
        ↓
build
        ↓
unit/package tests
        ↓
integration tests
        ↓
UI/manual QA for platform changes
        ↓
profile when performance-sensitive
```

Exact commands will be defined in `docs/development/setup.md` when the project scaffold exists.

---

## 14. Test naming and organization

Use names that state behavior and condition:

```text
test_surface_invalidated_recovers_to_collapsed_after_screen_change()
test_denied_microphone_suspends_native_voice_module_without_prompt_loop()
test_ipc_rejects_raw_command_action_payload()
test_event_coalescer_caps_transcript_ui_updates()
test_disabling_module_cancels_owned_tasks_and_unregisters_actions()
```

Group tests by architectural responsibility, not by incidental class layout.

---

## 15. Defect severity and release blocking

| Severity | Example | Release handling |
|---|---|---|
| Critical | Arbitrary external command execution, secret leak, crash loop, data loss | Blocks all release |
| High | Core crash on sleep/display change, permission prompt storm, unbounded memory growth | Blocks foundation/module release |
| Medium | Module fails but core recovers, incorrect compact state, diagnostics gap | Must be tracked; release only with owner/mitigation |
| Low | Minor visual mismatch, non-critical wording/animation issue | May defer with issue |

Any Critical/High defect involving security, data retention, lifecycle recovery, or performance budget must be linked to an issue and a regression test before closure.

---

## 16. Foundation Completion Gate

The foundation cannot pass until:

- Unit tests for domain, state, settings, permissions, actions, modules, events, IPC, persistence, and bounded resource policy pass.
- Integration tests prove EventBus, Action Registry, ModuleRuntime, SettingsStore, PermissionCoordinator, and local IPC work together.
- Manual macOS lifecycle/display/permission matrix is complete for the supported initial scope.
- Security/privacy tests show no arbitrary action path and no secret/sensitive fixture leakage.
- Performance scenarios meet or document justified deviations from CPU/RAM/latency/energy targets.
- Diagnostics identifies surface, module, permission, IPC, event, action, persistence, and resource failures.
- Documentation and ADRs match the implementation.
- `DemoModule` can fail/disable/restart without destabilizing the core app.

Only after this gate may the project implement M0/M1 real module behavior.

---

## 17. Future module test contract

Every future module must add:

```text
ModuleTests/
├── <Module>ContractTests
├── <Module>SettingsTests
├── <Module>PermissionTests
├── <Module>EventTests
├── <Module>ActionTests
├── <Module>FailureTests
├── <Module>ResourceCleanupTests
└── <Module>PerformanceTests
```

And document:

- Purpose/non-goals.
- Inputs/outputs/events.
- Settings and migration.
- Permissions and denied state.
- Actions and confirmation.
- Resource/performance policy.
- Privacy/retention.
- Diagnostics.
- Manual QA.

For a future Xiaozhi Display Companion specifically:

- Test normalized relay fixtures, not raw protocol inside the UI.
- Test transcript delta ordering, gaps, duplicates, finalization, Unicode, bounded memory, and 20–30 Hz UI coalescing.
- Test disconnect/reconnect and stale session handling.
- Test that display-only mode does not request Microphone permission.

---

## 18. Summary

NotchHub quality is established through multiple layers: fast pure tests for contracts and state, integration tests for routing and isolation, real macOS tests for windowing/permissions/lifecycle, security/privacy tests for trust boundaries, and Instruments-based profiling for long-running behavior.

The strategy deliberately delays real modules until the platform can demonstrate stable recovery, bounded resources, safe actions, clear permissions, diagnosable failures, and repeatable release confidence. This makes the future Xiaozhi, Media, Clipboard, Files, and Calendar modules smaller and safer to implement.
