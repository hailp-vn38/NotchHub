# Boring Notch Reference
## Technical study boundary for NotchHub

**Status:** Draft v0.1  
**Owner:** Architecture / Product / Legal  
**Last updated:** 2026-09-13  
**Location:** `docs/references/boring-notch.md`  
**Primary reference:** [TheBoredTeam/boring.notch](https://github.com/TheBoredTeam/boring.notch)  
**Related documents:** [Vision](../product/vision.md), [Architecture Overview](../architecture/overview.md), [C4 Container](../architecture/c4-container.md), [Notch Surface](../architecture/notch-surface.md), [Module System](../architecture/module-system.md), [Threat Model](../security/threat-model.md)

---

## 1. Purpose

Boring Notch is an important open-source reference for understanding how a macOS application can turn the MacBook notch area into an interactive surface. NotchHub uses it to study practical issues around native panel positioning, SwiftUI/AppKit composition, animation, feature organization, and macOS lifecycle behavior.

Boring Notch is **not** the base codebase for NotchHub. NotchHub is a separate project with its own product scope, architecture, security model, module contracts, performance policy, and documentation.

The purpose of this document is to record:

- What technical problems Boring Notch helps us investigate.
- Which ideas are relevant to NotchHub.
- Which decisions NotchHub makes independently.
- What must be checked before reusing any code, asset, design, dependency, or documentation.
- Which lessons should become tests or ADRs rather than copied implementation.

---

## 2. Reference snapshot

The upstream [Boring Notch README](https://github.com/TheBoredTeam/boring.notch/blob/main/README.md) describes a macOS notch utility focused on media control and a visualizer, with additional features such as calendar integration, a file shelf/AirDrop support, and a roadmap covering items such as reminders, mirror, charging indicator, gestures, layout options, system HUD replacements, notifications, and an extension system. It lists macOS 14 Sonoma or later and Apple Silicon/Intel support, and documents building from source with Xcode.

As checked on 2026-09-13, the upstream [`LICENSE`](https://github.com/TheBoredTeam/boring.notch/blob/main/LICENSE) contains the **GNU General Public License version 3 (GPL-3.0)**. This is a strong copyleft license; any source reuse, modification, linking, or distribution decision requires a deliberate compatibility and legal review. Re-check the exact upstream commit and license before reuse because the repository has changed licenses in the past.

The [upstream README](https://github.com/TheBoredTeam/boring.notch/blob/main/README.md#notable-projects) also credits NotchDrop as instrumental to the first Shelf implementation, so dependency, provenance, and attribution review is necessary before adapting that area.

### Reference facts are time-sensitive

The upstream repository, license, dependencies, branch state, and features may change. Before copying or adapting anything:

1. Inspect the exact upstream commit/branch.
2. Read the repository `LICENSE` and any file-level notices.
3. Check dependency licenses and attribution requirements.
4. Preserve required notices only if reuse is legally approved.
5. Re-run this review before public distribution of NotchHub.

This document is a technical reference record, not legal advice.

---

## 3. What NotchHub should study

### 3.1 Native panel/window behavior

Study how a notch utility addresses:

- Borderless/floating panel creation.
- Top-center placement around a physical notch.
- Safe positioning on Macs without a physical notch.
- Window level and collection behavior.
- Hit-testing and click-through when collapsed.
- Expansion/collapse without stealing focus unnecessarily.
- Panel behavior across full-screen apps, Spaces, display changes, and sleep/wake.

**NotchHub decision:** implement a dedicated `NotchPanelController` as the only owner of the native panel. The result should expose intents/snapshots to the rest of the platform, not a feature-specific window API. See [`notch-surface.md`](../architecture/notch-surface.md).

### 3.2 SwiftUI/AppKit composition

Study the division of responsibilities between:

- AppKit for native `NSPanel`, window level, screen coordinates, event monitoring, and lifecycle.
- SwiftUI for content layout, reusable components, settings, state-driven presentation, and animation.

**NotchHub decision:** keep `NotchSurface` AppKit-aware and `NotchUI`/module presentation mostly SwiftUI-based. The state machine remains AppKit-free and testable.

### 3.3 Animation and interaction

Study:

- How a small collapsed surface expands into a larger content area.
- How the shape/size transition avoids sudden layout jumps.
- Hover delay, click-outside, Escape, and timeout handling.
- How animation is reduced or disabled for accessibility and power efficiency.

**NotchHub decision:** animation is subordinate to the explicit surface state machine and Reduced Motion policy. No module may introduce an always-running animation or force expansion outside `PresentationPolicy`.

### 3.4 Feature organization

Study how a notch application groups media, calendar, shelf, battery, camera/mirror, HUD, and other functionality. The [upstream README](https://github.com/TheBoredTeam/boring.notch/blob/main/README.md) presents this breadth as a product direction and roadmap.

**NotchHub decision:** use a stronger platform/module boundary:

- Modules declare UI slots, settings, permissions, actions, events, privacy, and resource policy.
- Modules do not manipulate the native panel directly.
- Core owns permissions, actions, state policy, persistence boundaries, and diagnostics.
- The initial implementation uses static compile-time modules, not dynamic executable plugins.

### 3.5 Edge-case hypotheses

Boring Notch helps identify likely edge cases to test even if NotchHub uses independent code:

- MacBook with physical notch versus no-notch fallback.
- Built-in display unavailable in clamshell mode.
- External display attach/detach.
- Resolution/scale changes.
- Full-screen application transitions.
- Space changes.
- Sleep/wake and lock/unlock.
- Menu-bar auto-hide.
- Panel hit-test/click-through behavior.
- Gatekeeper/signing/notarization differences between source builds and release artifacts.

These become NotchHub manual QA and performance scenarios, not assumptions copied from the reference implementation.

---

## 4. What NotchHub will not copy as architecture

| Reference-style direction | NotchHub decision |
|---|---|
| Add features directly into one product codebase | Use explicit static module contracts and lifecycle isolation |
| Let feature code control window behavior | One `NotchPanelController` owns all native panel operations |
| Let each feature request permissions | Central `PermissionCoordinator` with on-demand requests |
| Let integrations define arbitrary actions | Typed `ActionID`, schema, source policy, confirmation, timeout |
| Let raw protocol data reach views | EventRouter/EventBus and focused presentation snapshots |
| Treat logs/history as an implementation detail | Data classification, bounded retention, redaction, export policy |
| Optimize after feature growth | Performance/resource policy required before every module |
| Treat extension system as an early feature | Static modules first; dynamic plugins require separate ADR/security review |
| Expand into broad hardware/IoT controls | ESP-IDF, ESP32, IoT, MQTT, BLE gateway, and LAN device control permanently excluded |

---

## 5. Legal and license handling

### 5.1 Current reference license snapshot

As checked on 2026-09-13, the upstream [`LICENSE`](https://github.com/TheBoredTeam/boring.notch/blob/main/LICENSE) contains **GPL-3.0**. Treat this as a time-stamped snapshot rather than a permanent fact; record the exact upstream commit and re-check the license before any code reuse.

GPL-3.0 permits modification and redistribution under its terms but imposes strong copyleft/source-disclosure obligations on covered derivative distributions. It should be treated as **not suitable for direct source copying or integration until compatibility with NotchHub's intended license and distribution model has been reviewed**.

### 5.2 NotchHub policy

- Do not copy source files from Boring Notch into NotchHub by default.
- Do not copy assets, branding, icons, screenshots, UI text, animations, or distinctive layouts without review.
- Do not reuse dependencies merely because the reference uses them; assess each dependency independently.
- Do not claim NotchHub is a fork, derivative, or official successor.
- Use public technical behavior as a learning reference and implement independently.
- If code is ever reused, record the exact file/commit, license, permission, attribution, modification status, and distribution obligations in an ADR and legal review record.
- Keep NotchHub's own license separate from reference-project licenses.

### 5.3 Dependency and attribution checklist

Before using any reference-derived code or dependency:

```text
[ ] Exact upstream repository/commit recorded
[ ] License file and file-level notices inspected
[ ] Dependency licenses inspected
[ ] Copyright/attribution obligations identified
[ ] Commercial/distribution compatibility reviewed
[ ] Derivative-work/no-derivatives restrictions reviewed
[ ] Security and maintenance status reviewed
[ ] ADR and NOTICE decision added if reuse is approved
[ ] Tests prove independently implemented behavior where possible
```

If this checklist cannot be completed, do not reuse the code.

---

## 6. Independent implementation strategy

### 6.1 Build behavior tests first

For a feature inspired by Boring Notch:

1. Write a NotchHub requirement and acceptance criteria.
2. Write platform-neutral unit tests where possible.
3. Write macOS manual/UI tests for windowing/interaction behavior.
4. Implement independently using NotchHub contracts.
5. Compare behavior against the requirement, not source code structure.
6. Document the lesson in architecture docs/ADR.

### 6.2 Example: notch panel

```text
Requirement: expanded panel opens from collapsed state without blocking unrelated menu-bar clicks.

Test:
- collapsed hit-test bounds are minimal
- click trigger expands
- click outside collapses
- Escape collapses
- external menu-bar area remains clickable
- panel survives display/sleep changes

Implementation:
- NotchHub NotchPanelController
- NotchHub SurfaceStateMachine
- NotchHub Geometry/Interaction components
```

The implementation may be informed by reference behavior, but it is not copied from reference source.

### 6.3 Example: shelf/file interaction

If NotchHub later implements a file shelf, study the concept and edge cases, including the NotchDrop acknowledgment in the [Boring Notch README](https://github.com/TheBoredTeam/boring.notch/blob/main/README.md#notable-projects). Then design a separate module contract with its own privacy, permission, cache, drag/drop, and retention policies.

Do not copy the Shelf implementation by default.

---

## 7. Technical comparison

| Concern | Boring Notch reference role | NotchHub implementation direction |
|---|---|---|
| Windowing | Observe practical notch panel behavior | `NotchSurface` + single panel owner |
| UI framework | Study SwiftUI/AppKit composition | SwiftUI UI, AppKit native window/input |
| Surface state | Observe expand/collapse patterns | Explicit tested `SurfaceStateMachine` |
| Modules/features | Study grouping and user-facing feature breadth | Static `NotchModule` contract + runtime isolation |
| Settings | Study organization and onboarding ideas | Typed schema/version/migration/module namespaces |
| Permissions | Identify likely OS edge cases | Central on-demand `PermissionCoordinator` |
| Actions | Observe user interaction patterns | Typed `ActionRegistry`, confirmation and source policy |
| External integration | Study conceptual media/calendar/shelf inputs | Versioned EventEnvelope + local IPC adapters |
| Performance | Observe visualizer/cache/window work risks | Budgets, coalescing, bounded data, Instruments scenarios |
| Release | Study source-build/release considerations | Independent signing/notarization/release process |

---

## 8. Questions to answer while studying the reference

For each technical observation, record:

1. What user problem does this behavior solve?
2. Is the behavior required by NotchHub's vision/requirements, or merely interesting?
3. Can it be implemented with public macOS APIs?
4. Does it require a permission or sensitive data category?
5. Does it create a new event/action/Module contract?
6. What is the idle CPU/energy impact?
7. What is the memory/cache/retention policy?
8. What happens during sleep/wake, full-screen, display changes, and denial?
9. Does it create a new trust boundary?
10. Does it remain inside NotchHub's macOS productivity scope?
11. Does it require an ADR?
12. Can the behavior be implemented independently without copying source?

---

## 9. Reference study log

Use this table as the project studies the upstream repository. It is intentionally a living record.

| Date | Upstream commit/tag | Area studied | Observation | NotchHub decision | Follow-up |
|---|---|---|---|---|---|
| 2026-09-13 | `main` at review time (commit not pinned) | README/features/license | Media/visualizer, calendar, shelf/AirDrop direction; repository license file contained GPL-3.0 | Use as behavioral/reference input; no source copy; focus NotchHub on foundation | Pin a commit and re-check license/dependencies before any reuse |
|  |  |  |  |  |  |

The review date and exact commit/tag must be filled in whenever implementation decisions are based on a new upstream revision.

---

## 10. Required follow-up documents

This reference document should link to:

- `docs/architecture/notch-surface.md` — independent panel/window design.
- `docs/architecture/module-system.md` — independent module model.
- `docs/architecture/performance.md` — budgets and Instruments scenarios.
- `docs/platform/permissions.md` — permission policy.
- `docs/security/threat-model.md` — trust boundaries and threat analysis.
- `docs/architecture/decisions/0002-use-swiftui-appkit-hybrid.md`.
- `docs/architecture/decisions/0003-static-modules-before-dynamic-plugins.md`.
- `docs/architecture/decisions/0011-use-public-apis-first.md`.
- A legal/third-party notices file before distribution if any reference code/dependency is approved for reuse.

---

## 11. Scope boundary reminder

Boring Notch's breadth or future roadmap must not be interpreted as a reason to expand NotchHub into excluded domains. NotchHub will not add:

- ESP-IDF build/flash/monitor actions.
- ESP32 gateway/BLE device telemetry.
- IoT/MQTT/smart-home integration.
- LAN device control or hardware command routing.

These exclusions remain in [Vision](../product/vision.md), [Roadmap](../product/roadmap.md), [Requirements](../product/requirements.md), and ADR-0013.

---

## 12. Summary

Boring Notch is a valuable technical reference for the macOS notch problem, especially native panel behavior, SwiftUI/AppKit composition, feature UX, and lifecycle edge cases. NotchHub will learn from those problems while implementing its own foundation-first architecture: a single `NSPanel` owner, explicit surface state machine, static module contracts, centralized permissions/actions, local validated IPC, bounded performance, and independent licensing.

The correct relationship is **study, test, implement independently, and document**—not copy, fork, or silently inherit the reference project's license, branding, feature coupling, or scope.
