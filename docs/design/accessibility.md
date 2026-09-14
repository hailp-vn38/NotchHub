# Accessibility
## NotchHub — Inclusive Interaction, Keyboard Access, Motion, and Readability

**Status:** Draft v0.1  
**Owner:** Design / Platform / Quality  
**Last updated:** 2026-09-14  
**Location:** `docs/design/accessibility.md`  
**Related documents:** [Vision](../product/vision.md), [Requirements §6.6](../product/requirements.md#66-accessibility-and-usability), [Notch Surface](../architecture/notch-surface.md), [State Management](../architecture/state-management.md), [Settings Information Architecture](settings-information-architecture.md), [Permissions](../platform/permissions.md), [Action Platform](../architecture/action-platform.md), [Testing Strategy](../quality/testing-strategy.md), [Apple APIs](../references/apple-apis.md)

---

## 1. Purpose

This document defines accessibility requirements for NotchHub: a macOS menu-bar and Notch-surface utility designed for glanceable status and quick actions.

The Notch is a small, visually unusual interaction surface. Hover-only behavior, transient content, animations, decorative waveform/status effects, compact text, and floating panels can easily create barriers for people who use keyboard navigation, VoiceOver, increased text sizes, reduced motion, higher contrast, alternate input methods, or who simply prefer not to depend on a pointer.

Accessibility is therefore a platform requirement, not a polish layer. Every core feature, module, action, error state, permission flow, and Settings page must remain understandable and operable without relying solely on hover, color, motion, tiny text, or transient visual effects.

---

## 2. Accessibility goals

1. **Equivalent access** — every important Notch action has a menu, keyboard, or Settings path; hover is never the only route.
2. **Understandable state** — current status, errors, permission state, module state, and action outcome are announced/labelled in text, not conveyed only through color or animation.
3. **Keyboard operability** — core controls are reachable by keyboard and have predictable focus behavior.
4. **VoiceOver compatibility** — panels, controls, status changes, and detail routes have meaningful accessibility labels, values, hints, and grouping.
5. **Motion safety** — reduced-motion preference reduces nonessential expansion, spring, visualizer, and continuous effects while retaining essential feedback.
6. **Readable content** — compact content is short; detail windows support normal macOS text/readability preferences.
7. **No interaction traps** — the floating panel does not steal or trap focus when hidden/collapsed/suppressed.
8. **Recoverable errors** — disabled, denied, failed, unavailable, and loading states explain cause and available next action.
9. **Module accountability** — every module declares accessibility behavior and tests it before merge.
10. **Performance supports accessibility** — UI responsiveness, stable focus, and bounded updates are required to keep assistive technology usable.

---

## 3. Supported interaction paths

### 3.1 Core actions must have alternatives

| User task | Pointer/Notch path | Required alternate path |
|---|---|---|
| Show/hide Notch surface | Hover/click Notch | Menu bar action and configurable shortcut |
| Open Settings | Notch action | Menu bar and `app.openSettings` action |
| Open Diagnostics | Notch action | Menu bar and `app.openDiagnostics` action |
| Collapse expanded surface | Click outside | Escape and surface toggle shortcut/action |
| Enable/disable module | Settings switch | Keyboard focus/Space or Return activation |
| Run action | Notch action button | Settings → Actions, menu/shortcut when registered |
| Resolve permission | Inline Notch/module prompt | Settings → Permissions and System Settings route |
| View long status/transcript/history | Notch detail affordance | Detail window/Settings route with keyboard navigation |

A user must never need to hover precisely around the camera/notch to reach an essential function.

### 3.2 Presentation levels

| Presentation level | Accessibility expectation |
|---|---|
| Passive indicator | Decorative unless it communicates critical state; provide equivalent status in menu/Settings/VoiceOver context |
| Collapsed surface | Must not capture focus or obscure unrelated controls |
| Compact status | Short text state; announce only meaningful/high-priority changes without notification spam |
| Expanded panel | Focusable, grouped controls, Escape to collapse, predictable keyboard order |
| Detail window | Standard accessible macOS window/scene with normal focus/navigation support |
| Suppressed/hidden | Not focusable, not exposed as stale actionable UI |

---

## 4. Accessibility ownership

| Concern | Owner | Requirement |
|---|---|---|
| Native panel focus/hit testing | `NotchPanelController` / `SurfaceCoordinator` | Hidden/collapsed/suppressed panel cannot trap focus or intercept unrelated interaction |
| Surface state announcements | `SurfacePresentationStore` + Notch UI | Expose meaningful state changes without announcing animation internals |
| Action labels/hints | `ActionRegistry` metadata + `NotchUI` | Every action has title, purpose, availability reason, shortcut hint |
| Permission explanation/status | `PermissionCoordinator` + Settings UI | Explain reason, state, decline effect, recovery path |
| Module UI accessibility | Module author + `NotchUI` | Module contributes labels, grouping, status descriptions, keyboard behavior |
| Settings navigation | Settings scene / design system | Correct labels, focus order, error/disabled explanations |
| Reduced motion | Appearance settings + design system | System preference respected; user setting can reduce nonessential movement |
| Diagnostics accessibility | Diagnostics UI | Sanitized, readable, navigable status/error information |
| Test verification | Quality/maintainers | Unit/UI/manual VoiceOver and keyboard test coverage |

No module can compensate for a broken panel focus model by adding custom event handling. Native surface behavior remains a platform responsibility.

---

## 5. VoiceOver requirements

### 5.1 General rules

- All interactive controls expose an accessibility label.
- Labels describe **purpose**, not only visual appearance.
- Controls with a state expose a value: enabled/disabled, running/stopped, connected/disconnected, permission granted/denied.
- Controls that need context expose a short accessibility hint.
- Decorative icon, blur, waveform, and animation elements are hidden from accessibility unless they communicate unique information.
- Status content must not be announced on every animation frame or raw event update.
- When a floating surface becomes interactive, VoiceOver focus should move predictably only after a user-triggered expansion, not when a passive status message appears.
- When the surface collapses or is suppressed, focus must return to a sensible prior target or app context where practical.

### 5.2 Labels by component

| Component | Accessibility label/value/hint example |
|---|---|
| Surface trigger | Label: “NotchHub controls”. Value: “Collapsed” or “Expanded”. Hint: “Press Return to open controls.” |
| Expand/collapse button | Label: “Expand NotchHub” / “Collapse NotchHub” |
| Status pill | Label: “Assistant status”. Value: “Thinking” |
| Action button | Label: “Open Settings”. Hint: “Opens NotchHub settings.” |
| Toggle | Label: “Enable Notch surface”. Value: “On”/“Off” |
| Shortcut recorder | Label: “Shortcut for Toggle NotchHub”. Hint: “Press Return to record a new shortcut.” |
| Permission row | Label: “Microphone permission”. Value: “Not enabled”. Hint: “Required only for Native Xiaozhi Voice.” |
| Module row | Label: “Demo module”. Value: “Running”. Hint: “Press Return to open module settings.” |
| Error state | Label: “Notch surface unavailable”. Value: “Built-in display is unavailable”. Hint: “Open Diagnostics for recovery options.” |
| Progress | Label: “Action progress”. Value: “60 percent complete” |

Use current localized text in real implementation. The examples establish information content, not exact strings.

### 5.3 Status announcements

Announcements must be meaningful and rate-limited.

| Event | VoiceOver behavior |
|---|---|
| User explicitly opens expanded surface | Move focus to panel heading/primary control; announce “NotchHub controls opened” |
| User explicitly opens detail | Move focus to detail window heading |
| Compact non-critical status | Do not automatically interrupt; make it discoverable when user navigates to the surface/menu |
| Action started by user | Announce concise action start only if operation lasts long enough to matter |
| Action completed/failed | Announce concise outcome; include recovery path for failure |
| Permission result | Announce granted/denied/restricted outcome after user request |
| Module failed | Announce only when user is interacting or failure impacts active feature; otherwise show in Diagnostics/menu state |
| Future transcript delta | Do not announce every delta/token; announce final response, a user-requested readout, or a bounded summary |

Use platform-appropriate accessibility notification APIs/SwiftUI accessibility modifiers through a centralized helper. Do not create a new spoken announcement task per incoming event.

---

## 6. Keyboard navigation and focus

### 6.1 Core keyboard behavior

| Context | Required behavior |
|---|---|
| Menu bar | Standard macOS menu navigation; all core actions reachable |
| Collapsed/hidden surface | Does not steal focus; global shortcut/menu action can reveal it |
| Expanded surface | Logical focus order; Tab/Shift-Tab through controls; Return/Space activates appropriate controls |
| Detail window | Standard window focus behavior, Escape/back behavior documented |
| Settings | Sidebar/page controls and rows navigable with keyboard |
| Confirmation | Initial focus is safe default (usually Cancel); confirm action has clear label |
| Shortcut recorder | Clearly enters/exits recording mode; Escape cancels recording without altering binding |

### 6.2 Focus order

Expanded surface focus order should generally be:

```text
Panel heading/status
→ primary action(s)
→ secondary controls
→ module/detail affordance
→ collapse/close control
```

Settings focus order follows visual/top-to-bottom reading order within a page. Avoid custom focus jumps that make keyboard navigation unpredictable.

### 6.3 Focus restoration

- Passive compact status must not steal focus.
- User-triggered expanded panel may receive focus if needed for keyboard interaction.
- On collapse, restore focus to the previously focused application/control where practical; otherwise fall back to menu-bar context without trapping focus.
- On panel suppression, display change, sleep, or module failure, remove panel focus safely.
- Do not preserve focus references to destroyed windows/views.

### 6.4 Escape behavior

- Escape in expanded surface collapses it.
- Escape in detail returns to expanded or closes detail according to documented route behavior.
- Escape in shortcut recording cancels capture.
- Escape must never perform a destructive action.

---

## 7. Visual accessibility

### 7.1 Color and contrast

- Color is never the only channel for status. Combine color with icon, label, and/or text value.
- Text and controls must retain sufficient contrast against dark/translucent Notch materials.
- Test System, Light, and Dark appearance where supported.
- Avoid relying only on a subtle opacity change to convey disabled/denied/failed states.
- Error/warning state must use a semantic label (for example “Permission denied”), not just red color.
- Do not allow user-configurable opacity/theme combinations that make core controls unreadable; validate or warn.

### 7.2 Typography and compact layout

- Use legible system text styles/tokens.
- Compact Notch content is intentionally short: one to three lines.
- Do not force long user text into tiny Notch UI; truncate safely and provide “Open details.”
- Detail windows and Settings must adapt to macOS text-size/accessibility preferences where available.
- Avoid fixed-height controls that clip larger text.
- Never use all caps for essential status/instructions.

### 7.3 Icons

- Use SF Symbols or clear icons consistently, but never without text/accessible label for essential actions.
- Decorative icons must not create VoiceOver noise.
- Do not distinguish important states solely by icon shape without text/state value.

### 7.4 Transparency and materials

- Translucent/blur materials must not reduce legibility below acceptable contrast.
- Provide a more opaque/high-contrast presentation when system/user accessibility settings indicate reduced transparency or increased contrast.
- Do not animate material opacity continually in idle state.

---

## 8. Motion and animation

### 8.1 Reduced Motion policy

NotchHub must respect the macOS system reduced-motion preference and provide a user-facing Reduced Motion setting in Settings → Appearance.

When Reduced Motion is enabled:

- Replace spring/bounce transitions with short fade or immediate state change.
- Disable continuous decorative visualizers/waveforms unless they communicate essential state; use a static “Listening”/“Speaking” label instead.
- Avoid large scale/position movement around the notch.
- Do not use parallax, pulsing, or flashing attention effects.
- Preserve essential transition information through text/state announcements.

### 8.2 Animation rules

| Animation type | Default | Reduced Motion |
|---|---|---|
| Collapse/expand | Short, restrained transition | Fade/short crossfade or immediate |
| Compact status arrival | Subtle fade/slide | Fade or immediate |
| Action progress | Progress indicator/state text | Static progress/value updates |
| Future audio waveform | Active session only, 15–30 Hz max | Disabled/static state label |
| Error attention | One restrained indication | Static error label; no repeated flashing |
| Loading indicator | Bounded/semantic | Static “Loading” text where possible |

### 8.3 Performance relationship

Continuous animations and high-rate visual updates can impair assistive technologies and consume battery. Follow the event coalescing/update limits in [`performance.md`](../architecture/performance.md): do not update the UI for every raw audio sample or transcript token.

---

## 9. State, errors, and availability

### 9.1 Required textual states

Every module/action/permission should expose a textual state where relevant:

```text
Available
Unavailable
Enabled
Disabled
Starting
Running
Paused
Suspended
Loading
Connected
Disconnected
Permission needed
Permission denied
Restricted
Failed
Retrying
Completed
Cancelled
Timed out
```

The exact status vocabulary should be consistent across UI, VoiceOver, diagnostics, and documentation.

### 9.2 Disabled controls

A disabled control must have:

- A readable label.
- A reason it is disabled.
- A recovery path where one exists.

Example:

```text
Native Voice is unavailable
Microphone access is not enabled.
Open Permissions
```

Do not present a disabled toggle/button without explanation.

### 9.3 Error states

Use this structure:

```text
What happened
Why it matters
What the user can do next
Optional Diagnostics link
```

Example:

```text
Notch surface is unavailable.
The built-in display is currently not available.
Use the menu bar to open Diagnostics or reconnect the display.
```

### 9.4 Time-sensitive/transient status

- Auto-dismissing compact text must remain available in Diagnostics/recent action status when it represents a meaningful result/error.
- Do not rely only on a toast/animation for critical completion/failure information.
- Future assistant transcript should have a detail view/readout path and bounded history policy.

---

## 10. Permissions accessibility

Permission UI must answer:

1. What will be accessed?
2. Why does the enabled feature need it?
3. When is access active?
4. What happens if access is declined?

### Requirements

- Opening Settings → Permissions does not automatically show a system prompt.
- Pre-permission explanation is readable by VoiceOver and keyboard operable.
- The system prompt trigger is user initiated.
- Denied/restricted/unavailable status is announced and visible in text.
- “Open System Settings” is a clearly labelled recovery action.
- Future Microphone permission for Native Xiaozhi Voice states that display-only Xiaozhi remains usable without microphone access.
- Do not use a waveform/animated microphone indicator as the only proof of active audio capture; show text/state too.

See [`permissions.md`](../platform/permissions.md).

---

## 11. Actions and confirmation accessibility

### Action metadata

Every action must include:

- Human-readable title.
- Short purpose/subtitle.
- Availability/disabled reason.
- Shortcut hint if assigned.
- Confirmation policy if relevant.

### Confirmation dialog requirements

For side-effecting actions, confirmation must include:

- Action title.
- Source: Notch UI, menu, shortcut, local script, or future assistant.
- Target/consequence summary.
- Structured input summary where applicable.
- Safe initial focus (Cancel unless the platform standard dictates otherwise).
- Clearly distinguishable Confirm and Cancel controls.
- Keyboard behavior: Escape cancels; Return only confirms when focus is explicitly on Confirm and policy allows.

A confirmation must not rely on a red/green color distinction or an icon alone.

---

## 12. Settings accessibility

Settings is the primary accessible fallback for all Notch functionality.

### Requirements

- All top-level pages are keyboard navigable: General, Appearance, Notch Behavior, Shortcuts, Permissions, Actions, Modules, Diagnostics, About.
- Settings labels reflect actual behavior; do not label future/unimplemented capability as active.
- Route/deep-link opening moves focus to the page heading or relevant control.
- Shortcut recorder announces recording state, conflict, save, clear, and cancellation.
- Permission rows announce current status and recovery action.
- Module rows announce enabled state, lifecycle/health, and any required capability.
- Diagnostics rows use sanitized readable summaries; avoid presenting inaccessible raw machine-only data as the only error information.
- Destructive settings/reset controls are grouped/separated and provide confirmation.

See [`settings-information-architecture.md`](settings-information-architecture.md).

---

## 13. Module accessibility contract

Every module must document and test:

```markdown
## Accessibility

- User-visible purpose and status labels:
- Keyboard entry points:
- VoiceOver labels, values, and hints:
- Focus order and focus restoration:
- Compact/expanded/detail content limits:
- Reduced Motion behavior:
- Contrast/transparency considerations:
- Loading/disabled/error/recovery states:
- Permission accessibility copy and denial flow:
- Announcement/coalescing policy for live updates:
- UI automation/manual VoiceOver test plan:
```

### Future Xiaozhi Display Companion requirements

- Display-only M1 provides text labels for `idle`, `listening`, `thinking`, `speaking`, `disconnected`, and `error` states.
- Transcript delta must not trigger VoiceOver announcement for every token/chunk.
- Provide a keyboard-accessible route to full transcript/detail, if transcript display is enabled.
- State changes and final response are announced according to user/notification policy, with rate limits.
- Display-only mode must clearly state that Microphone permission is not needed.
- If Native Xiaozhi Voice is later added, active capture/mute/stop state must be obvious in both visual UI and VoiceOver.
- Assistant tool/action state must be described as an action/status, not hidden behind waveform/color animation.

---

## 14. Testing requirements

### 14.1 Unit tests

- Accessibility label/value/hint builder for standard components.
- Status vocabulary mapping.
- Disabled/error/recovery message generation.
- Reduced Motion policy mapping.
- Surface state to focusability/exposure mapping.
- Shortcut recorder state mapping.
- Permission state/accessibility copy mapping.
- Action confirmation metadata includes source/consequence.
- Module accessibility metadata completeness.

### 14.2 UI automation

Verify:

- Keyboard can open Settings and Diagnostics through menu/action.
- Tab/Shift-Tab focus order in expanded surface and Settings.
- Escape collapses/cancels appropriately.
- Return/Space activates focused controls only.
- Focus does not remain on hidden/suppressed/destroyed panel.
- Disabled controls expose explanatory text/recovery controls.
- Reduced Motion setting changes animation policy.
- Color-independent status labels appear in all state views.
- Deep links land on the intended Settings page/control.

### 14.3 Manual VoiceOver testing

On a supported macOS release, test:

- Menu-bar discovery and core actions.
- Collapsed/compact/expanded/detail surface behavior.
- Focus movement and restoration.
- Settings page navigation.
- Shortcut recorder.
- Permission explanation, request, denial, System Settings recovery, and refresh.
- Module enable/disable/failed state.
- Diagnostics reading and export controls.
- Light/dark/high contrast/reduced transparency/reduced motion conditions.
- Future text streaming only after M1, including announcement rate limits and Vietnamese Unicode pronunciation/readability considerations.

### 14.4 Regression checks

Accessibility regression checks are required when changing:

- Surface state machine or native panel configuration.
- Focus/hit-test/keyboard/hover code.
- Design-system typography/color/material/animation.
- Settings navigation/row controls.
- Permissions/action confirmation UI.
- Module UI contribution contract.
- High-rate streaming/coalescing behavior.

---

## 15. Accessibility acceptance criteria

The foundation is not ready for real modules until:

1. Every core action has a non-hover access path.
2. Menu bar, Settings, and Diagnostics remain usable when the Notch is hidden, suppressed, or unavailable.
3. Expanded surface can be operated by keyboard and exited with Escape.
4. Hidden/collapsed/suppressed surface does not trap focus or intercept unrelated input.
5. Core controls expose meaningful VoiceOver labels, values, and hints.
6. Critical state is not conveyed solely by color, icon, animation, or timing.
7. Reduced Motion changes nonessential Notch animation/continuous effects.
8. Settings supports keyboard navigation, readable errors, permission recovery, shortcut recording, module state, and destructive-action confirmation.
9. Permission requests are contextual and accessible; denial has a clear recovery path.
10. Action confirmation states source, consequence, and safe keyboard behavior.
11. Auto-dismissed meaningful results/errors remain discoverable in Diagnostics/recent status.
12. Accessibility tests and manual VoiceOver checks are recorded in the quality evidence.

---

## 16. Anti-patterns

Do not implement:

- Hover-only action access.
- An invisible panel that captures keyboard focus.
- Status conveyed only by waveform, animated dots, color, or icon.
- VoiceOver announcement for every event/token/audio frame.
- Small unscalable text with no detail path.
- A focus trap in compact/expanded Notch content.
- A disabled button with no reason.
- A confirmation relying on red/green or icon-only meaning.
- Motion that cannot be reduced/disabled.
- A permission prompt shown without a readable explanation and user action.
- Settings controls that cannot be reached by keyboard.
- An accessibility workaround that bypasses ActionRegistry, PermissionCoordinator, or surface state ownership.

---

## 17. Summary

NotchHub must be usable without precise pointer hover, color perception, motion tolerance, or access to a small transient Notch panel. Menu bar, Settings, keyboard shortcuts, standard focus behavior, VoiceOver labels, readable state, reduced motion, and clear recovery paths are foundational platform capabilities.

By making these requirements part of the Notch surface, action system, permission flow, Settings IA, module contract, and quality gate, future modules—including Xiaozhi Display Companion—can add rich live status without making the app inaccessible, noisy, or fragile.
