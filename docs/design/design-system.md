# Design System
## NotchHub — F3 visual language and reusable UI boundary

**Status:** F3 Settings-shell implementation complete; phase gate remains open
**Owner:** Design / NotchUI / Quality
**Last updated:** 2026-09-15
**Location:** `docs/design/design-system.md`
**Related documents:** [Roadmap](../product/roadmap.md#f3--design-system-and-settings-ui-shell), [Settings information architecture](settings-information-architecture.md), [Settings UI specification](notchhub-settings-ui-spec.md), [Accessibility](accessibility.md), [Notch interaction](notch-interaction.md), [State management](../architecture/state-management.md), [Testing strategy](../quality/testing-strategy.md)

---

## 1. Purpose and current boundary

This document is the visual contract for reusable SwiftUI presentation in `NotchUI`. It keeps the Notch surface and application scenes visually coherent without making UI views owners of settings persistence, permissions, actions, module lifecycle, or diagnostics.

The repository's execution phase remains F2 until its native manual gate is closed. The following
F3 scope is implemented on the current branch:

- `NotchUI` provides typed route/phase state, semantic layout tokens, a Settings shell, common
  section/status/unavailable presentation, and a session-only motion preview.
- The app opens the Settings shell from the existing menu-bar route; Diagnostics remains an F1
  placeholder application scene.
- The F2 Notch surface already uses system Reduced Motion and has accessibility labels/focus handling.

F3 adds the **Settings shell**: navigation, reusable visual primitives, and honest unavailable-state content. A control that lacks an owner in the current phase is a non-interactive explanatory placeholder. It must not simulate persistence or trigger a future permission, shortcut, action, module, or diagnostics capability.

---

## 2. Design principles

1. **Quiet before decorative.** The Notch surface communicates a small amount of useful state; long explanation belongs in an application scene.
2. **Semantic before visual.** Views request semantic tokens such as `surfacePrimary` and `statusWarning`, never arbitrary colors scattered through feature views.
3. **Native before custom.** Use SwiftUI/macOS controls and system material where they meet the contract. Add a custom primitive only to encode a repeated NotchHub rule.
4. **Accessible by construction.** Labels, values, hints, focus order, disabled reasons, contrast, and reduced motion are part of each component contract.
5. **No false affordance.** Planned functionality is shown as unavailable with a short reason, not as an enabled switch or button that discards user intent.
6. **Surface safety.** A theme, density, or motion choice must not change `NotchPanelController` ownership, unsafe geometry, hit-testing, or recovery policy.

---

## 3. Token model

Tokens live in `NotchUI`; the initial implementation should expose typed Swift values rather than raw string keys or a runtime theme engine.

| Token family | Initial semantic tokens | Contract |
|---|---|---|
| Color | `surfacePrimary`, `surfaceSecondary`, `contentPrimary`, `contentSecondary`, `statusSuccess`, `statusWarning`, `statusError`, `focusRing` | Must remain distinguishable in Light, Dark, Increased Contrast, and Reduced Transparency environments; status also has text/icon. |
| Typography | `title`, `body`, `caption`, `monospacedDiagnostic` | Use Dynamic Type-compatible styles in application scenes. The compact surface has a bounded content contract rather than shrinking text below readability. |
| Spacing | `space2`, `space4`, `space8`, `space12`, `space16`, `space24` | Components use this scale; no local magic-number spacing where a token applies. |
| Shape | `controlRadius`, `cardRadius`, `surfaceShoulderRadius`, `surfaceBottomRadius` | Surface radii remain geometry-owned inputs, not a Settings customization control. |
| Elevation/material | `applicationMaterial`, `surfaceShadow` | Respect Reduced Transparency; material never makes primary text or error/recovery state unreadable. |
| Motion | `standard`, `quick`, `none` | `none` removes nonessential scale, spring, pulse, and continuous effects while preserving an immediate state change. |

The design system may map tokens to system colors/materials. It must not promise a user-selectable theme or persistence in F3; those are future typed-settings work.

---

## 4. Reusable component contracts

| Component | Responsibility | Accessibility and unavailable state |
|---|---|---|
| `NHActionButton` | Presents an already-owned user intent | Has label, enabled state, optional shortcut hint, and disabled reason. It does not execute an unregistered Action. |
| `NHStatusPill` | Compact, bounded status summary | Includes textual status; color/icon alone is insufficient. Decorative duplicate content is hidden from VoiceOver. |
| `NHSettingRow` | Label, explanation, value/control, validation or unavailable reason | Stable keyboard order; uses a non-interactive value when no F3 owner exists. |
| `NHPermissionRow` | Future Permission Center presentation | F3 version states that capability information is planned; it must not request a system permission. |
| `NHModuleRow` | Future module-health presentation | F3 version is an empty/unavailable state; it must not start a module. |
| `NHShortcutRecorderShell` | Future shortcut recorder container | F3 version explains that shortcut registration arrives in F6; it does not capture keys. |
| `NHContentState` | Shared loading, empty, error, and unavailable presentation | Explains what happened, why it matters, and the next available route; never exposes raw secret or diagnostic payloads. |

Components accept presentation data and callbacks supplied by their owning application scene. They must not reach into `SettingsStore`, `PermissionCoordinator`, `ActionRegistry`, `ModuleRuntime`, `DiagnosticsStore`, AppKit panel APIs, or system privacy APIs.

---

## 5. Settings shell scope

F3 supplies the nine routes defined by the Settings IA: General, Appearance, Notch Behavior, Shortcuts, Permissions, Actions, Modules, Diagnostics, and About.

| Route | F3 responsibility | Deferred owner |
|---|---|---|
| General | Application identity and explanation of planned configuration | F4 persistence/reset/import/export |
| Appearance | Token preview and availability explanation | F4 typed appearance settings |
| Notch Behavior | Explain current F2 interaction defaults | F4 validated persisted preferences |
| Shortcuts | Explain route/accessibility alternatives | F6 shortcut registration and recording |
| Permissions | Explain no permission is requested by the shell | F5 Permission Center |
| Actions | Explain that no action catalogue is available yet | F6 Action Registry |
| Modules | Empty foundation state | F7 ModuleRuntime |
| Diagnostics | Route/status placeholder only | F9 diagnostics store and export |
| About | Static app/version/license information safe to show now | Release/operations additions |

The F3 shell may apply a purely in-memory preview only when its lifetime and reset-on-relaunch behavior are explicitly stated in the UI. It must never claim that the preference was saved.

---

## 6. Motion, contrast, and focus

- Respect `accessibilityReduceMotion` at the component boundary. The F2 surface already uses a short non-spring transition when it is enabled; F3 components must do the same for nonessential effects.
- Respect Increased Contrast and Reduced Transparency. Do not use opacity as the only distinction between enabled, disabled, warning, and error states.
- Application scenes use normal SwiftUI focus traversal. The compact/collapsed Notch surface remains non-focusable; expanded-surface focus is owned by the F2 interaction session.
- Every interactive component has a visible label, VoiceOver label/value/hint where system defaults are insufficient, and an equivalent keyboard path.
- Announce user-initiated success, failure, and unavailable outcomes once. Do not announce animation or high-frequency visual updates.

---

## 7. F3 verification contract

F3 is ready to exit only when:

1. `NotchUI` provides the documented token families and the shared components used by the Settings shell and current surface where applicable.
2. All nine Settings routes open from the menu-bar application scene without requiring the Notch surface.
3. Each future-phase route is visibly unavailable or explanatory; opening Settings performs no persistence write, permission request, shortcut capture, module startup, action execution, or diagnostics polling.
4. Placeholder and current-surface UI use semantic tokens rather than feature-local styling.
5. UI tests cover route availability and component states; accessibility checks cover labels, focus order, contrast semantics, and Reduced Motion.
6. A physical macOS check confirms the Settings scene remains usable when the Notch surface is hidden or suppressed.

F3 does **not** close F4–F9 gates. Persistence, migration, privacy permissions, shortcut registration, Action Registry execution, module runtime health, and operational diagnostics require their own owners and verification evidence.

The F3 automated checks pass, but physical macOS UI/VoiceOver verification remains required before
the F3 gate can be closed.

---

## 8. Change rules

Update this document when a token family, reusable component contract, motion rule, or accessibility behavior changes. Update the Settings IA for route/content changes, the Notch interaction document for surface behavior, and the testing strategy for a new verification obligation. An ADR is warranted only if a durable cross-cutting choice materially changes the public UI boundary or platform constraint.
