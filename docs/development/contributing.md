# Contributing to NotchHub
## Development, Review, Architecture, and Quality Rules

**Status:** Draft v0.1  
**Owner:** Project Maintainers  
**Last updated:** 2026-09-13  
**Location:** `docs/development/contributing.md`  
**Related documents:** [README](../../README.md), [Development Setup](setup.md), [Vision](../product/vision.md), [Requirements](../product/requirements.md), [Roadmap](../product/roadmap.md), [Architecture Overview](../architecture/overview.md), [Testing Strategy](../quality/testing-strategy.md), [Security Threat Model](../security/threat-model.md), [Apple APIs](../references/apple-apis.md), [Boring Notch Reference](../references/boring-notch.md)

---

## 1. Purpose

This document defines how to contribute code, documentation, tests, architecture decisions, and modules to NotchHub.

NotchHub is intentionally built as a **foundation-first modular macOS platform**. Contributions must preserve the platform boundaries that make future modules—especially the Xiaozhi Display Companion—safe to add without rewriting core windowing, permissions, settings, actions, IPC, state management, or performance behavior.

This document applies to:

- Human contributors.
- AI coding agents.
- Maintainers reviewing pull requests.
- Module authors.
- Contributors updating documentation or architecture decisions.

---

## 2. Project principles

### Build the platform before the feature

Do not add a business integration simply because it makes a demo more interesting. Foundation phases F0–F10 must provide the contracts, settings, permission, action, IPC, diagnostics, performance, and test infrastructure first.

### Keep the Notch calm

NotchHub is for glanceable status and short actions, not a permanent dashboard. New features must use the correct presentation layer and avoid interrupting active work.

### Respect ownership boundaries

- `NotchPanelController` owns the native panel.
- `PermissionCoordinator` owns permission requests.
- `SettingsStore` owns persistence.
- `ActionRegistry` owns executable actions.
- `EventRouter` owns external event validation.
- `ModuleRuntime` owns module lifecycle.
- `DiagnosticsStore` owns bounded diagnostic history.

A contribution that bypasses an owner is not ready for review.

### Treat external input as untrusted

IPC, local scripts, imported settings, future relays, and AI/voice sources must pass authentication/source policy, schema validation, size/rate limits, and typed action/event boundaries.

### Performance is a requirement

Every timer, observer, network connection, cache, event producer, animation, and persistence path has a resource owner and a budget.

### Documentation is part of the implementation

Architecture and contract changes require documentation/ADR updates in the same pull request.

---

## 3. Product scope rules

### In scope

- macOS Notch surface and menu-bar utility behavior.
- Settings, permissions, shortcuts, actions, IPC, diagnostics, and modular runtime.
- Future Xiaozhi display/AI integration.
- Future media, clipboard, files, calendar/reminders, and selected system-control modules.
- macOS public APIs and local-first integrations.

## 4. Before starting work

1. Read `README.md`.
2. Read `docs/product/vision.md`, `requirements.md`, and `roadmap.md`.
3. Read the relevant architecture/component document.
4. Check active ADRs in `docs/architecture/decisions/`.
5. Identify affected security, privacy, permissions, performance, and testing documents.
6. Search existing issues/branches before duplicating work.
7. Define acceptance criteria before implementing non-trivial behavior.
8. Decide whether the change is foundation work, module work, documentation, bug fix, or refactor.

### Required planning artifacts

| Change type | Minimum planning |
|---|---|
| Small UI/copy fix | Issue or clear PR description + relevant test/check |
| Core behavior change | Requirements/architecture impact + tests |
| New action/event/API | Contract document + security/privacy/performance review |
| New permission | Permission doc + user copy + manual test plan |
| New persistence/data | Data classification + retention/delete/export policy |
| New module | Module document/checklist + module tests + resource policy |
| New external process/transport | Threat model + IPC/security/release review + ADR |
| New Apple API | API adoption record + availability/permission/fallback review |
| Durable architecture choice | Numbered ADR |

---

## 5. Repository and branch workflow

### Branch naming

Use descriptive branch names:

```text
feature/f2-notch-state-machine
feature/f5-permission-center
feature/m1-xiaozhi-display-events
fix/ipc-token-redaction
refactor/focused-presentation-stores
docs/c4-container-update
perf/event-coalescing
```

### Commit guidelines

Use concise, imperative commit subjects. Suggested format:

```text
<area>: <short imperative description>
```

Examples:

```text
surface: add recovery transition for display changes
settings: add schema v2 migration
ipc: reject unknown action executor fields
docs: define module resource policy
```

Keep commits logically focused. Avoid mixing unrelated formatting, feature, refactor, and generated-file changes.

### Pull requests

A pull request should:

- Explain the user/technical problem.
- State the scope and non-goals.
- Link requirements/roadmap/issue.
- Describe architecture impact.
- List tests run and manual scenarios.
- State permission/security/privacy/performance impact.
- Include screenshots or recordings only when UI behavior benefits from them; do not use screenshots as a substitute for tests.
- Update documentation and ADRs as required.

---

## 6. Coding architecture rules

### 6.1 Dependency direction

```text
Apps / Tools / Static Modules
            ↓
NotchSurface + NotchUI + NotchActions + NotchIPC
            ↓
        NotchCore
            ↓
       NotchDomain
```

Do not introduce cycles or reverse dependencies without an ADR.

### 6.2 Native panel ownership

Only `NotchPanelController` may call native panel operations such as:

- Create/destroy panel.
- Set frame.
- Set window level.
- Set collection behavior.
- Show/hide/order panel.
- Configure hit-testing/click-through.

Modules, views, IPC handlers, action handlers, and EventBus subscribers must use intents/snapshots/contracts instead.

### 6.3 Main actor rules

Main actor/UI code may apply small presentation snapshots and respond to user interaction. It must not perform:

- Blocking file/network/IPC I/O.
- Large JSON/log parsing.
- Process execution.
- Audio/screen processing.
- File scans/thumbnail generation.
- Large settings migration/import/export.
- Unbounded event/text updates.

Use actors, structured tasks, bounded `AsyncStream`, and cancellation ownership.

### 6.4 No arbitrary execution

Never introduce an endpoint, action, module API, or AI/voice path that accepts:

```text
raw shell command
raw script
arbitrary executable path
arbitrary executor type
unvalidated URL/host
undeclared target
```

Use registered `ActionID` plus validated structured input. Any future in-scope process integration requires a dedicated security review and ADR.

### 6.5 Permissions

- Modules declare required/optional capabilities.
- Only `PermissionCoordinator` requests system permissions.
- Requests require explicit user context and explanation.
- No first-launch permission prompt storm.
- Denied/restricted/unavailable states must be usable and test-covered.

### 6.6 Persistence

- Use typed settings and migrations.
- Use Keychain for secrets.
- Use bounded diagnostics/cache/history.
- Never log or export secrets.
- Any user-content persistence requires a retention/delete/privacy decision.

### 6.7 Boring Notch reference policy

Use Boring Notch as a technical reference for notch/windowing edge cases. Do not copy source/assets/branding/layouts by default. Check the upstream repository/license/dependencies before any reuse; record approved reuse and obligations in documentation/ADR.

---

## 7. Module contribution rules

### 7.1 Static modules first

Modules are compile-time Swift components in the current architecture. Dynamic `.dylib`/`.bundle` loading is not allowed without a new security/ABI/distribution review and ADR.

### 7.2 Module checklist

Before merging a new module, provide:

```text
[ ] ModuleID and version
[ ] User purpose and non-goals
[ ] UI slots and content limits
[ ] Settings schema/defaults/migration/reset
[ ] Required/optional permissions and request timing
[ ] Event inputs/outputs, expected rate, ordering
[ ] Action IDs, input schema, confirmation policy
[ ] Idle/hidden/visible resource policy
[ ] Maximum event rate and memory/cache budget
[ ] Privacy/data retention/delete behavior
[ ] Security/trust boundaries
[ ] Offline/denied/degraded/failure behavior
[ ] Accessibility labels/keyboard/reduced motion
[ ] Diagnostics fields and redaction
[ ] Unit/integration/manual/performance tests
[ ] Documentation and ADR updates where needed
```

### 7.3 Module boundaries

A module must not:

- Directly manipulate `NSPanel`.
- Request a system permission directly.
- Write another module's settings.
- Register an action in another module's namespace.
- Subscribe to every event without a documented need.
- Run unowned detached tasks.
- Continue timers/observers/sockets after `stop()`.
- Put raw sensitive content into generic diagnostics.

---

## 8. Documentation and ADR rules

### Documentation update rule

Update the affected document in the same pull request as code behavior changes. Examples:

| Code change | Documentation |
|---|---|
| Panel state/geometry | `architecture/notch-surface.md`, requirements/QA if needed |
| New state/store | `architecture/state-management.md` |
| New event | `architecture/event-protocol.md` + event registry fixture |
| New action | `architecture/action-platform.md` + requirements/security tests |
| IPC route/schema | `architecture/ipc.md` + security/threat model |
| New permission | `platform/permissions.md` + privacy copy/manual QA |
| New data/cache | `architecture/data-persistence.md` + privacy/retention |
| New Apple API | `references/apple-apis.md` |
| Performance-sensitive code | `architecture/performance.md` + profiling scenario |
| New module | `module-system.md` + module document |

### ADR triggers

Create a numbered ADR when a change affects:

- Supported macOS version.
- Package/dependency direction.
- `NSPanel`/window ownership.
- Module loading model.
- Event/action contract versioning.
- IPC transport/binding/authentication.
- Permission/privacy model.
- Persistent data/retention model.
- Performance budgets.
- Private API/privileged helper.
- Signing/distribution.

ADR format:

```markdown
# ADR-NNNN: <Decision title>

## Status

Proposed | Accepted | Superseded | Rejected

## Context

## Decision

## Alternatives considered

## Consequences

## Security/privacy/performance impact

## Links
```

---

## 9. Testing requirements for contributions

Every behavior change needs tests proportional to risk.

### Minimum checks

```text
[ ] Build passes
[ ] Focused unit tests pass
[ ] Relevant integration tests pass
[ ] Formatting/lint passes where configured
[ ] Documentation/links remain valid
[ ] No secrets or personal data added
```

### Additional checks by area

| Area | Required checks |
|---|---|
| `NotchSurface` | State/geometry tests + macOS lifecycle/manual QA |
| State/Observation | Store/snapshot tests + invalidation/performance review |
| Settings/persistence | Migration/corruption/reset/import/export tests |
| Permissions | Adapter tests + signed manual permission matrix |
| Actions | Input/source/confirmation/timeout/security tests |
| Events | Schema/order/dedup/rate/coalescing fixtures |
| IPC | Auth/source/size/rate/backpressure/shutdown tests |
| Module | Failure isolation/resource cleanup/health/action tests |
| UI | Accessibility/reduced-motion/keyboard/manual checks |
| Performance | Instruments scenario when high-rate/background/resource behavior changes |
| Security | Threat model update and regression test for new boundary |

### No flaky test masking

Do not weaken tests, add arbitrary sleeps, disable safety checks, or mark failures as expected merely to make CI pass. Use fake clocks, deterministic adapters, proper async synchronization, and environment-specific test classification.

---

## 10. Code quality and style

### Swift guidance

- Prefer value types for domain models and immutable snapshots.
- Use `Sendable` and actor isolation deliberately.
- Avoid force unwraps in long-running platform code.
- Use explicit error types/codes.
- Keep APIs narrow and protocols focused.
- Avoid global mutable state.
- Give tasks, observers, timers, sockets, and subscriptions clear owners.
- Keep logging structured and privacy-aware.
- Avoid premature abstraction; abstract at real platform boundaries.

### SwiftUI guidance

- Keep views focused and small.
- Move business/state transitions to stores/coordinators.
- Avoid expensive work in `body`.
- Use reusable `NotchUI` components.
- Provide accessibility labels and reduced-motion behavior.
- Keep compact/expanded content within documented limits.

### Naming

Use stable namespaces:

```text
Module IDs:        xiaozhi.display, media, clipboard, calendar
Action IDs:        app.openSettings, media.playPause
Event types:       assistant.state.changed, action.completed
Permission feature: xiaozhi.nativeVoice, calendar.upcoming
```

---

## 11. Security and privacy contribution rules

Before merging a change that handles external input, secrets, user content, permissions, or side effects:

- Update the threat model.
- Identify the trust boundary.
- Define validation and authorization.
- Define logging/redaction behavior.
- Define data retention/deletion.
- Add misuse/negative tests.
- Verify no raw secrets appear in fixtures, screenshots, diagnostics, or command output.

Never paste credentials or sensitive user content into issues, PRs, logs, screenshots, or test fixtures.

Report suspected vulnerabilities privately according to `SECURITY.md`, not through a public issue.

---

## 12. Performance contribution rules

Before merging a change that adds a timer, observer, event source, animation, network connection, cache, persistence loop, or background task, document:

```text
Owner:
Start condition:
Stop/cancellation condition:
Idle behavior:
Hidden behavior:
Visible behavior:
Maximum event/update rate:
Memory/cache bound:
Disk/network behavior:
Diagnostics metrics:
Relevant profiling scenario:
```

Disabled modules must release resources. High-rate inputs must be coalesced before reaching UI. A contribution that cannot define its resource policy is not ready for merge.

---

## 13. AI coding agent rules

AI coding agents may assist with implementation, tests, documentation, and refactoring, but the repository boundaries remain mandatory.

### Before editing

The agent should read:

- `README.md`.
- The relevant product/architecture document.
- Active ADRs.
- Relevant security/performance/permission/testing documents.
- Existing tests and fixtures.

### While editing

- Make the smallest coherent change.
- Do not invent APIs, permission behavior, or external integrations without documentation.
- Do not introduce arbitrary shell/script execution.
- Do not bypass module/action/permission/event owners.
- Preserve public-API-first policy.
- Add tests before/with behavior changes.
- Update documentation/ADR when required.

### Before finalizing

The agent must report:

- Files changed.
- Behavior changed.
- Tests/build commands run.
- Tests not run and why.
- Permission/security/privacy impact.
- Performance/resource impact.
- Documentation/ADR updates.
- Known limitations or follow-up work.

AI-generated code is reviewed as ordinary code; it receives no reduced security or testing standard.

---

## 14. Pull request template

Use or adapt the following template:

```markdown
## Summary

## Motivation / user problem

## Scope

### Included

### Explicitly not included

## Architecture impact

- [ ] No architecture impact
- [ ] Existing architecture document updated
- [ ] ADR added/updated

## Security/privacy

- [ ] No new trust boundary
- [ ] Threat model reviewed
- [ ] No new secrets/user-content data
- [ ] Permission behavior reviewed
- [ ] Logs/diagnostics redacted

## Performance

- [ ] No new background work
- [ ] Resource owner/cancellation documented
- [ ] Rate/cache/buffer policy defined
- [ ] Profiling scenario run or not applicable

## Tests

- [ ] Unit
- [ ] Integration
- [ ] UI/accessibility
- [ ] Manual macOS lifecycle
- [ ] Security/privacy
- [ ] Performance/profile

Commands run:

## Documentation

## Screenshots/recording, if useful

## Known limitations
```

---

## 15. Review checklist for maintainers

### Correctness

- Does behavior satisfy requirements and acceptance criteria?
- Are invalid/error/recovery states handled?
- Is the change covered by an appropriate test layer?

### Architecture

- Does dependency direction remain valid?
- Is ownership clear?
- Does a module bypass a platform boundary?
- Is an ADR required?

### Security/privacy

- Is external input validated and authorized?
- Can the change trigger a side effect?
- Are secrets/user contents excluded from logs/exports?
- Is permission request contextual and on demand?

### Performance

- Does it add polling, timers, observers, cache, I/O, animation, or high-rate events?
- Are buffers bounded and updates coalesced?
- Does disabled/hidden state stop work?
- Does it need Instruments profiling?

### Product scope

- Does it support NotchHub's macOS desktop/productivity/AI direction?
- Is the Notch still calm, concise, and not a full dashboard?

---

## 16. Release contribution requirements

Before a change is included in a release candidate:

- CI passes.
- Critical/high defects are resolved or explicitly accepted with owner/mitigation.
- Signed/release-like build smoke test passes for relevant permissions/APIs.
- Diagnostics export/redaction passes.
- Manual macOS lifecycle matrix is updated/passed for windowing changes.
- Performance baseline is not regressed beyond accepted budget.
- Changelog/release notes include user-visible behavior.
- Third-party/license notices are updated when dependencies/reference reuse changes.

---

## 17. Summary

Contributing to NotchHub means extending a platform, not merely adding UI. Every contribution must respect single ownership of native windowing, permissions, persistence, actions, events, IPC, and diagnostics; keep external input typed and bounded; keep the app efficient when idle; and update the documentation that explains why the code is structured this way.

The project welcomes future Xiaozhi and macOS productivity modules. Small, testable, documented, secure changes are preferred over broad feature branches that create hidden coupling.
