# Performance and Energy
## NotchHub — Resource Budgets, Concurrency, Profiling, and Regression Control

**Status:** Draft v0.1  
**Owner:** Architecture / Quality  
**Last updated:** 2026-09-13  
**Related documents:** [Architecture Overview](overview.md), [State Management](state-management.md), [Module System](module-system.md), [Data Persistence](data-persistence.md), [Event Protocol](event-protocol.md), [Notch Surface](notch-surface.md), [Requirements §6.3](../product/requirements.md#63-performance-and-responsiveness), [Roadmap F10](../product/roadmap.md#f10--quality-profiling-and-foundation-completion-gate)

---

## 1. Purpose

NotchHub is designed to run for many hours as a menu-bar utility. Performance is therefore a product requirement, not a final optimization task.

This document defines:

- CPU, memory, latency, energy, and responsiveness budgets.
- Main-actor and concurrency rules.
- Event/update cadence and coalescing policies.
- Per-module resource declarations.
- Buffer/cache/log limits.
- Profiling scenarios and Instruments workflow.
- Performance regression gates.
- Low-power, hidden-state, thermal, and failure behavior.

The goal is a surface that feels immediate when used and nearly invisible when idle.

---

## 2. Performance principles

1. **Idle is a first-class state** — hidden/collapsed app behavior must be measured, not assumed.
2. **Event-driven over polling** — use observers/streams where possible; slow or suspend polling when hidden.
3. **Main actor for presentation only** — heavy work never blocks UI responsiveness.
4. **Snapshots over raw streams** — UI receives small coalesced values, not high-rate protocol/log/audio data.
5. **Bound everything** — event queues, histories, logs, caches, tasks, retries, and output buffers have limits.
6. **Modules pay for their work** — every module declares refresh/event/memory policy and releases resources on stop.
7. **Visibility controls work** — hidden modules do less; disabled modules do nothing.
8. **Measure on representative hardware** — profile Apple Silicon and the lowest supported configuration, not only the development Mac.
9. **Energy matters over time** — wakeups, timers, network heartbeat, disk writes, and continuous animation are tracked.
10. **Regressions block release** — a visually correct feature is not complete if it breaks idle CPU, memory, battery, or responsiveness budgets.

---

## 3. Performance budgets

These are initial engineering targets. They are measured targets, not guarantees, and may be revised only through measurement, documentation, and an ADR.

### 3.1 Foundation budgets

| Scenario | CPU target | Memory target | UX target |
|---|---:|---:|---|
| Idle, hidden/collapsed | < 0.3% average | 40–80 MB | No continuous animation, no fast polling |
| Expanded, no high-rate module | < 1–2% average | 60–120 MB | Surface opens/expands under 150 ms |
| Local compact event | Brief spike < 5% | No unbounded growth | Event-to-presentation under 100 ms under normal load |
| Settings navigation | Brief bounded work | No growth across repeated navigation | Navigation remains responsive |
| Diagnostics refresh | < 2% average while visible | Bounded snapshot | Refresh at 1–2 Hz or on demand |
| Module enable/disable | Short bounded spike | Returns near baseline | UI remains interactive; cleanup completes predictably |

### 3.2 Future streaming budgets

| Scenario | CPU target | Memory target | Update target |
|---|---:|---:|---|
| Future transcript stream | 1–5% average | < 150 MB total app target | 20–30 UI snapshots/s maximum |
| Future audio level | < 1–3% additional | Small rolling buffer | 15–30 updates/s while active |
| Future media/artwork | Short decode bursts | Explicit LRU cap | Lazy load; no full library scan |
| Future clipboard observer | Near-zero while unchanged | Count/byte history cap | Event-driven change handling |
| Future calendar/reminder refresh | Low-rate | Short TTL/cache cap | Refresh on activation/configured interval |

### 3.3 Latency goals

| Operation | Target |
|---|---:|
| Menu-bar command dispatch to action start | < 50 ms under normal load |
| Local event received to compact snapshot | < 100 ms under normal load |
| Notch expand request to first visible frame | < 150 ms under normal load |
| Settings local preview | Perceptually immediate; no blocking disk write |
| Diagnostics health query | < 250 ms for bounded snapshot |
| App recovery after screen event | Bounded and observable; no infinite retry |

---

## 4. Resource ownership model

```text
AppCoordinator
 ├── owns app lifecycle tasks
 ├── owns IPC startup/shutdown
 └── owns global observer lifecycle

NotchPanelController / SurfaceCoordinator
 ├── owns panel/interaction tasks
 ├── owns hover/collapse timers
 └── owns screen/context observers

ModuleRuntime
 ├── owns module lifecycle task groups
 └── enforces module cleanup

Each Module
 ├── owns its subscriptions/timers/adapters
 ├── owns its bounded cache
 └── cancels/releases all resources in stop()

DiagnosticsStore
 ├── owns bounded log/event storage
 └── owns batch/rotation tasks
```

### Ownership rules

- No detached task for normal work without a documented owner and cancellation path.
- Store task handles, observer tokens, subscriptions, timers, sockets, and cache handles.
- `stop()` must be safe to call during startup/failure and must be idempotent or runtime-guarded.
- Module disable cancels in-flight module work and marks actions unavailable.
- Shutdown uses bounded timeouts; one stuck client/module cannot block app termination indefinitely.

---

## 5. Concurrency architecture

### 5.1 Actor boundaries

| Component | Boundary | Allowed work |
|---|---|---|
| UI presentation stores | `@MainActor` | Apply small immutable snapshots and user-visible state |
| `EventBus` | `actor` | Publish/subscribe, bounded queues, subscription cancellation |
| `ModuleRuntime` | `actor` | Lifecycle/health transitions and module task supervision |
| `Event adapters` | `actor` | Network/IPC receive, decode, retry, ordering, coalescing |
| `ActionExecutionManager` | `actor` | Running invocation map, cancellation, timeout, progress throttling |
| `SettingsStore` | storage actor | Decode, validate, migrate, atomic persistence |
| `DiagnosticsStore` | `actor` | Redaction, bounded append, rotation, export |
| `CacheManager` | actor/serial service | LRU accounting, disk I/O, cleanup |
| `NotchPanelController` | main-thread/AppKit owner | Native window operations and visible panel coordination |

### 5.2 Main-actor prohibition

The following must not run on `@MainActor`, SwiftUI `body`, or a synchronous view callback:

- Large JSON/event/log parsing.
- Audio/Opus decode or waveform processing.
- Network/WebSocket/IPC I/O.
- File scanning, thumbnail generation, or calendar history processing.
- Long settings migration/import/export.
- Process execution or blocking subprocess reads.
- Large transcript/clipboard formatting.
- Disk writes for every incoming event.

### 5.3 Presentation snapshot flow

```text
Raw input/data
      ↓ background actor
Decode/validate/aggregate/coalesce
      ↓
Small immutable snapshot
      ↓ @MainActor
Focused presentation store
      ↓
SwiftUI/AppKit view
```

---

## 6. Event and UI update policy

### 6.1 High-rate data

Never update SwiftUI for every raw event when the producer can emit faster than the user can perceive.

```text
Raw events: 100/s
     ↓
Actor assembler
     ↓ coalesce/throttle
UI snapshots: 20–30/s maximum
```

### 6.2 Cadence table

| Data source | Hidden/idle | Visible/active | UI policy |
|---|---:|---:|---|
| Surface animation | Suspended | Native animation while transitioning | No continuous idle animation |
| Future transcript | Buffer/assemble | 20–30 snapshots/s | Tail in Notch; full content in detail |
| Future audio level | Stopped | 15–30/s | Latest smoothed level/short window only |
| CPU/network metrics | 5–15 s or suspended | 0.5–2 s | Graphs max 2–4 Hz |
| Diagnostics | On demand/slow | 1–2 Hz | Bounded snapshot |
| Compact status | No producer polling | Event-driven | 5–10 presentation updates/s max |
| Settings controls | No disk churn | Immediate local preview | Debounced persistence |

### 6.3 Coalescing

- Progress events keep the latest progress while preserving start/completion/failure.
- Equivalent status events replace older pending status.
- Transcript deltas assemble by session/sequence.
- Audio levels keep a smoothed latest value/short rolling window.
- Diagnostics aggregate counters rather than append every high-rate sample.
- Coalesced/dropped counts are visible in Diagnostics.

---

## 7. Memory and storage budgets

### 7.1 Application target

Initial planning target:

```text
Idle app:                 40–80 MB
Lightweight expanded app: 60–120 MB
With future modules:      normally below 150 MB
```

A temporary cache/decoder burst may exceed a steady-state target, but it must return toward baseline and be bounded.

### 7.2 Bounded data policies

| Data | Initial limit | Behavior at limit |
|---|---|---|
| Event diagnostics | 500–2,000 records | Ring-buffer rotation |
| Action results | 100–500 records | Drop oldest sanitized result |
| General log tail | 2–8 MB or line cap | Rotate/truncate |
| Future transcript memory | 50–200 messages or 1–5 MB | Trim oldest or session-boundary policy |
| Future clipboard history | Explicit count + byte cap | Remove oldest; user can clear |
| Future thumbnail/artwork cache | Explicit LRU byte cap | Evict least recently used |
| IPC stream queue | Bounded count + bytes | Coalesce/drop or disconnect slow client |
| Retry attempts | Fixed max + backoff | Mark unavailable/failed |

### 7.3 Allocation hygiene

- Avoid copying large strings/data for every event.
- Use small immutable snapshots for UI.
- Avoid retaining raw payloads after parsing.
- Clear/release module cache on disable according to policy.
- Profile repeated open/close/navigation and module toggle loops for growth.

---

## 8. Idle, hidden, and power policy

### 8.1 Idle rules

When the surface is hidden/collapsed and no active operation needs updates:

- No visualizer or continuous animation.
- No sub-second polling.
- No file/directory/Git-like scans.
- No clipboard polling when an event-driven change mechanism is available.
- No high-frequency system metrics.
- No repeated disk writes.
- Network adapters use waiting/heartbeat/backoff policy.

### 8.2 Visibility-based work

Each module has three work modes:

```text
inactive/disabled → no background work
hidden/idle       → minimal state maintenance, slow refresh or suspended
visible/active    → configured update rate within budget
```

Visibility is a hint, not a license to exceed module limits. User settings, thermal state, permissions, and system policy can further reduce work.

### 8.3 App Nap and energy

NotchHub should cooperate with macOS energy behavior, but must not rely on App Nap to compensate for poor design. Timers, observers, network heartbeat, disk writes, and continuous rendering must be deliberately reduced when the app is not actively useful.

Measure:

- Wakeups.
- Timer fires.
- CPU time.
- Energy impact.
- Network/disk activity.
- App Nap/background state where applicable.

### 8.4 Low-power/thermal mode

The platform may expose a low-power policy that:

- Disables optional continuous animations.
- Reduces metric refresh.
- Suspends optional caches/prefetch.
- Reduces future waveform rate to 10–15 FPS.
- Defers non-urgent diagnostics flush.

This policy must not break core settings, action confirmation, or recovery behavior.

---

## 9. Retry, backpressure, and failure behavior

### 9.1 Retry

- Retry only operations that are safe to retry.
- Use bounded exponential backoff with jitter where appropriate.
- Cap attempts and expose unavailable/failed status.
- Do not retry permission prompts in a loop.
- Do not keep reconnecting a disabled module.

### 9.2 Backpressure

When input is faster than processing:

1. Preserve critical lifecycle/result/error events within limits.
2. Coalesce equivalent progress/status events.
3. Drop stale low-priority events.
4. Increment diagnostics counters.
5. If a client ignores stream backpressure, disconnect it safely.

### 9.3 Failure containment

```text
Adapter/module failure
       ↓
Owner actor catches error
       ↓
Module/adapter state becomes degraded/failed
       ↓
Bounded retry or user-visible recovery
       ↓
Core UI remains responsive
```

A failure must not cause an unbounded retry, memory accumulation, or main-actor block.

---

## 10. Diagnostics and performance metrics

### 10.1 Required metrics

| Metric | Purpose |
|---|---|
| `app.cpuSnapshot` | Recent CPU/resource observation |
| `app.memorySnapshot` | Memory footprint/pressure observation |
| `surface.transitionLatency` | Surface expand/collapse responsiveness |
| `event.acceptedRate` | Event intake rate |
| `event.rejectedRate` | Validation/auth failures |
| `event.coalescedCount` | Backpressure/coalescing visibility |
| `event.droppedCount` | Data loss visibility |
| `ui.snapshotRate` | Presentation update frequency |
| `module.activeTasks` | Resource ownership insight |
| `module.bufferUsage` | Bounded buffer pressure |
| `action.duration` | Invocation performance |
| `action.timeoutCount` | Executor health |
| `ipc.queueDepth` | Client/backpressure state |
| `persistence.writeLatency` | Storage impact |

Metrics may be sampled/aggregated; they must not create another high-rate unbounded stream.

### 10.2 Debug overlay

Development builds may show:

```text
Surface: expanded
Screen: built-in display identifier
Frame: x/y/w/h
Event rate: 4.2/s
UI updates: 12/s
Active module tasks: 2
Buffer use: 14%
Last transition: 86 ms
```

The overlay is disabled by default in release builds and is controlled through the registered debug action.

---

## 11. Profiling workflow

### 11.1 Tools

Use Xcode Instruments and Activity Monitor:

| Tool | Purpose |
|---|---|
| SwiftUI Instrument | Body cost, invalidation, excessive view updates |
| Time Profiler | CPU hotspots, parsing, formatting, action work |
| Allocations | Allocation churn and retained data |
| Leaks | Leaked objects/closures/observers |
| Energy Log | Wakeups, timer/network/disk energy behavior |
| Hangs and Hitches | Main-thread stalls and animation jank |
| Activity Monitor | CPU, memory pressure, energy impact, broad idle validation |

### 11.2 Build configuration

Profile an optimized build that still includes diagnostics sufficient to identify ownership and state. Do not use only Debug builds for final performance decisions.

Record:

- macOS version.
- Mac model/CPU/RAM.
- Display setup.
- App/module configuration.
- Test duration.
- Build/version.
- Instruments template and relevant captures.

### 11.3 Baseline workflow

```text
Define scenario and budget
       ↓
Run clean build with fixed module/settings state
       ↓
Record baseline metrics
       ↓
Implement change
       ↓
Repeat exact scenario
       ↓
Compare CPU/RAM/wakeups/latency/frames
       ↓
Accept, optimize, or record justified ADR change
```

---

## 12. Required profiling scenarios

### P-001 — Idle run

- Run for at least 8 hours where practical.
- Surface hidden/collapsed.
- No active future module stream.
- Measure CPU average, memory growth, wakeups, timer activity, disk/network activity, and energy impact.

**Pass target:** no unbounded memory growth; idle CPU remains within target; no unexpected high-frequency activity.

### P-002 — Surface open/close stress

- Open/collapse/expand the surface 1,000 times.
- Include hover, click, Escape, click-outside, and timeout variants.
- Inspect allocations, native window count, observers, tasks, hitches, and final memory.

**Pass target:** no leak/growth trend and no systematic animation hitch.

### P-003 — Event flood

- Inject high-rate valid and invalid events through an in-memory/test IPC transport.
- Include valid status, progress, malformed, duplicate, oversized, and unauthorized events.
- Verify EventRouter rate limits/coalesces/rejects without blocking UI.

**Pass target:** UI remains responsive; bounded queues; diagnostics counters accurate.

### P-004 — Future text-stream simulation

- Simulate 20–100 text deltas per second.
- Include long Vietnamese Unicode text, duplicate sequence, missing sequence, final message, and session reset.
- Measure parser/assembler CPU, UI snapshot rate, memory, and dropped/coalesced events.

**Pass target:** UI receives bounded 20–30 snapshots/s; memory remains capped; final text is correct.

### P-005 — General operation-output flood

- Simulate 10,000+ lines of generic approved operation/status output from a future in-scope desktop module.
- Verify parser/background handling, tail display, ring buffer, and application-scene handoff.

**Pass target:** no infinite string growth/OOM; compact Notch stays short and responsive.

### P-006 — Module toggle loop

- Enable/disable/restart `DemoModule` 100 times.
- Measure tasks, timers, subscriptions, memory, action registrations, event handlers, and caches.

**Pass target:** resources return to baseline; no duplicate events/actions/subscriptions.

### P-007 — Lifecycle/display stress

- Repeat sleep/wake, lock/unlock, Space changes, full-screen entry/exit, display attach/detach, and resolution/scale changes.

**Pass target:** panel recovers or safely hides; no stuck recovery loop; core/menu/settings remain usable.

### P-008 — Persistence stress

- Repeatedly update settings/sliders.
- Run migration/import/export.
- Simulate corrupt/truncated data and storage failure.
- Verify debounced writes, atomic recovery, and bounded diagnostics.

**Pass target:** no data loss beyond documented last-write semantics; main UI remains responsive.

---

## 13. Performance regression policy

### 13.1 Change classification

| Change | Required performance review |
|---|---|
| Pure static UI/text | Smoke check |
| New animation/blur/material | SwiftUI/hitch check |
| New event producer | Rate/coalescing/buffer review |
| New persistent/cache data | Allocation/storage/retention review |
| New observer/timer/network connection | Idle/energy review |
| New module | Full module resource policy + relevant scenarios |
| New audio/streaming source | Full high-rate stream profile |
| New permission/system API | Lifecycle/latency/energy/privacy review |

### 13.2 Release gate

A release candidate must not knowingly exceed a budget without:

- Measurement and reproducible scenario.
- Documented reason and user impact.
- Mitigation plan or accepted trade-off.
- ADR/update to performance requirements where the budget changes.
- Diagnostics/monitoring sufficient to detect regression.

### 13.3 Regression baseline

Maintain baseline captures or summarized metrics for:

- Idle.
- Surface interaction.
- Event flood.
- Module toggle.
- Lifecycle/display stress.

The baseline need not be committed as huge binary Instruments files; commit scenario metadata and summarized measurements, and store large captures through the project’s chosen artifact system if needed.

---

## 14. Testing requirements

### Unit tests

- Coalescer behavior.
- Bounded buffer rotation.
- Rate-limit windows/buckets.
- Retry/backoff calculation.
- Cancellation ownership.
- Module policy validation.
- Snapshot reduction.
- Persistence write debounce.

### Integration tests

- Event flood through EventBus to presentation store.
- Module enable/disable cleanup.
- IPC backpressure and slow client disconnect.
- Settings migration under load.
- Diagnostics counter correctness.

### Performance assertions

Where stable and non-flaky, add automated assertions for:

- Buffer never exceeds configured maximum.
- Disabled module has zero registered active resources in test doubles.
- UI update rate is below configured cap under fixture stream.
- Retry attempts do not exceed maximum.
- Diagnostics ring buffer remains bounded.

Timing/CPU assertions that vary significantly across CI machines should be run as profiling/release checks rather than hard-failing ordinary unit tests.

---

## 15. Module performance contract

Every module document must include:

```markdown
## Runtime policy

- Disabled behavior:
- Hidden/idle refresh interval:
- Visible refresh interval:
- Maximum incoming event rate:
- Maximum UI update rate:
- Memory budget:
- Cache budget:
- Persistence write policy:
- Retry/backoff policy:
- Task/timer/observer ownership:
- Stop/cleanup behavior:
- Relevant Instruments scenarios:
```

A module cannot be accepted without this section.

---

## 16. Summary

NotchHub performance comes from architecture, not from a last-minute optimization pass: focused state observation, actor boundaries, event coalescing, bounded buffers, visibility-aware work, explicit module resource policies, and repeatable Instruments scenarios.

A module is complete only when it is useful, diagnosable, cancellable, bounded, and energy-conscious. This keeps the Notch responsive during interaction and nearly invisible while the app runs quietly in the background.
