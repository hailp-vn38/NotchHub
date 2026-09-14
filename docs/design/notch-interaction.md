# Notch Interaction Design
## NotchHub — Surface States, Attention Policy, and Input Behavior

**Status:** Draft v0.1
**Owner:** Design / Platform / Architecture
**Last updated:** 2026-09-14
**Location:** `docs/design/notch-interaction.md`
**Related documents:** [Vision](../product/vision.md), [Requirements](../product/requirements.md), [Notch Surface](../architecture/notch-surface.md), [State Management](../architecture/state-management.md), [Action Platform](../architecture/action-platform.md), [Settings Information Architecture](settings-information-architecture.md), [Accessibility](accessibility.md), [Performance](../architecture/performance.md), [Manual QA](../quality/manual-qa.md)

---

## 1. Purpose

This document defines the user interaction model for the NotchHub surface: how it appears, expands, collapses, accepts input, presents status, manages attention, and transitions to detail content.

The design goal is a surface that feels native and intentional on a MacBook: useful at a glance, quick to use, accessible without precise pointer movement, and quiet when the user is focused elsewhere.

This document describes product behavior and interaction policy. Native panel ownership, geometry, lifecycle handling, and implementation detail remain defined in [`notch-surface.md`](../architecture/notch-surface.md).

---

## 2. Design principles

### Calm by default

When there is no useful activity, NotchHub should visually recede. The default state is collapsed or hidden according to the user’s preference; the app must not behave like a permanent dashboard.

### Progressive disclosure

Information and controls appear in layers. A user sees only what is needed for the current moment, and can open a larger context intentionally.

### Deliberate interaction

Hover is a convenience, not a requirement. Every important control must also be reachable through menu bar, keyboard shortcut, Settings, or a standard application scene.

### Attention follows urgency

Events do not automatically deserve a visible interruption. The presentation policy decides whether to remain silent, show a compact update, present a badge, or open detail after a user action.

### Clear state over decoration

The interface communicates state through concise labels, icons, and controls. Animation, color, blur, and waveform-style visuals are supporting signals only.

### Safe exit and recovery

The user can always collapse with Escape or click outside. Errors point to a useful recovery route rather than leaving a stuck panel.

---

## 3. Presentation model

NotchHub uses three presentation layers.

| Layer | User purpose | Visibility | Interaction |
|---|---|---|---|
| Passive indicator | Quiet awareness of a relevant state | Minimal, optional | Usually not primary interaction target |
| Collapsed surface | Resting NotchHub state | Small/near-notch | Click or hover trigger; shortcut/menu alternative |
| Compact status | Brief state, result, or progress | Time-limited | Click may expand for context |
| Expanded panel | Quick action and short interaction | User-triggered or explicitly permitted | Buttons, controls, action grid, summary |
| Application scene | Long content, history, configuration, diagnostics | Explicit application navigation | Standard macOS window interaction |

`hidden` and `suppressed` are operational states, not interaction layers: content is not presented or is intentionally minimized due to context policy.

---

## 4. Surface states

### 4.1 State catalogue

| State | What the user sees | How it enters | How it exits |
|---|---|---|---|
| Hidden | Nothing from NotchHub | Recovery failure or unavailable display | Display recovery or app restart returns to collapsed |
| Collapsed | Minimal near-notch shape or optional indicator | App ready; compact timeout; expanded collapse | Hover/click/shortcut expands; event may show compact |
| Compact | One to three lines of short information | Allowed status/action result/progress event | Timeout collapses; click/shortcut expands |
| Expanded | Short actions and current context | User hover/click/shortcut/action | Escape, click outside, or timeout |
| Suppressed | No visible or reduced surface due to context policy | Full-screen/privacy/focus policy | Context clears; returns safely to collapsed |
| Recovering | Temporary transition while native surface revalidates | Display/session/panel change | Success returns collapsed/suppressed; failure hides and exposes diagnostics |

### 4.2 State design rules

- A passive status event must not open a application scene.
- `expanded` is primarily user initiated. Presentation policy may allow an explicit high-value action result to open an expanded context only when this behavior is enabled and non-disruptive.
- A **application scene** is a separate route, never a `SurfaceState`, and always requires clear user navigation.
- Recovery never restores a previously visible long/private application scene automatically; it returns the surface to a safe collapsed or suppressed state.
- Suppression takes precedence over automatic expansion.
- Invalid or duplicate state transitions must produce no confusing animation; they are ignored or normalized by the state machine.

---

## 5. Attention and notification policy

### 5.1 Event presentation matrix

| Event category | Default presentation | User interruption level | Example |
|---|---|---|---|
| Informational state | Store internally; no surface change | None | A noncritical module refreshes state |
| Short success/result | Compact status for a short period | Low | “Settings saved” |
| Progress | Compact status only while meaningful | Low | “Importing settings · 60%” |
| User-invoked action result | Compact or expanded result depending on action | Low–medium | “Action completed” |
| Recoverable warning | Badge/compact plus recovery route | Low | “Permission needed” |
| Important failure | Compact error plus Diagnostics or Settings link | Medium | “Module could not start” |
| Critical internal failure | Menu-bar state/notification plus Diagnostics | Medium | “Surface unavailable” |
| Long content | Detail only on explicit user action | None until user opens | Transcript, history, logs |

### 5.2 Rules for compact status

- Display no more than one primary status at a time.
- Keep text concise: normally one line, maximum three short lines.
- Show source/module identity for content that could otherwise be ambiguous.
- Use a bounded queue; equivalent updates replace older pending entries.
- Critical lifecycle/action completion/failure remains discoverable in Diagnostics after the compact message disappears.
- Do not animate every incoming update. Coalesce status updates according to performance policy.

### 5.3 Notification separation

A compact Notch status is not automatically a macOS notification. Notifications are optional, user-controlled, and reserved for selected background outcomes. The surface must not produce duplicate alerting through simultaneous compact status, sound, and notification unless the user explicitly chose that behavior.

---

## 6. Collapsed interaction

### 6.1 Visual behavior

Collapsed state should blend into the physical notch area or occupy a minimal top-center footprint on a no-notch fallback display.

Allowed content:

- No text.
- One small indicator or state glyph.
- A quiet visual cue that the surface can be opened.

Not allowed:

- Persistent wide banners.
- Continuous visualizer/waveform.
- Long status text.
- Multiple action buttons.
- Large animated elements.

### 6.2 Trigger region

- The hover/click trigger area is tightly scoped to the visible collapsed surface plus a small configured margin.
- It must not cover unrelated menu-bar items.
- The trigger must not be a full-screen transparent overlay.
- When the surface is hidden or suppressed, it has no active pointer target.

### 6.3 Alternatives to hover

The following must always be available for essential access:

```text
F3/F4 → Settings → Notch Behavior
F6 → Keyboard shortcut / registered `` action
```

---

## 7. Expanded panel interaction

### 7.1 Content hierarchy

Expanded content follows a stable order:

```text
1. Current context/status heading
2. Primary quick actions
3. Secondary controls or module summary
4. Detail affordance, if content is longer
5. Collapse/close affordance when useful
```

This order supports visual scanning, keyboard focus, and VoiceOver navigation.

### 7.2 Expanded layout limits

- Expanded panel is a short interaction surface, not a scroll-heavy dashboard.
- Prefer 2–8 primary actions visible at once.
- Prefer one primary module/context per expansion.
- Keep text summary within roughly 2–4 lines or 250–350 characters.
- If content requires a long list, form, transcript, history, or troubleshooting sequence, use a application scene.
- Avoid nested scroll views in the expanded surface.
- Avoid dense tables, multi-column configuration, and hidden gestures for core tasks.

### 7.3 Input behavior

| Input | Result |
|---|---|
| Click/tap F2 placeholder control | Send a local user intent to the surface owner |
| Hover within panel | Keeps auto-collapse paused/reset |
| Click outside | Collapse to collapsed state |
| Escape | Collapse to collapsed state |
| Global surface shortcut | Expand or collapse according to the registered action |
| Keyboard Tab/Shift-Tab | Move through logical focus order |
| Return/Space | Activate focused control |

F2 placeholder controls send local user intents through platform owners. From F6 onward, controls dispatch typed `ActionID` values; neither path permits a view to call module code directly.

---

## 8. Application scenes

Long-form content does not belong in the Surface. Dedicated application scenes may provide:

- Long text/history.
- Full transcript or conversation context.
- Diagnostics/log tail.
- Module configuration.
- Permission explanations.
- Action confirmation with substantial consequence/context.
- Complex search/filter/navigation.

Settings, diagnostics, history, and transcripts use standard accessible
macOS scenes with bounded and privacy-aware content. The Surface has no route
or affordance for opening a generic long-form window.

---

## 9. Hover, click, timeout, and shortcuts

### 9.1 Hover

Hover is optional. F2 uses a non-persisted, dependency-injected default; F3/F4 may later expose validated settings.

| Behavior | Requirement |
|---|---|
| Hover delay | 300 ms default to prevent accidental expansion |
| Trigger margin | 8 pt around the visible collapsed surface |
| Enter trigger | Start delay; do not expand instantly unless user selects immediate behavior |
| Exit before delay | Cancel expansion |
| Exit after hover-origin expand | Start 100 ms close grace only when no Surface interaction hold is active; otherwise defer until the final hold ends |
| Disabled hover | Surface remains accessible through click, menu, and shortcut |

### 9.2 Click

- Click collapsed/compact surface to expand.
- Click compact content to open relevant expanded context, not an unrelated application scene.
- Click outside collapses only when the pointer target is clearly outside the active interactive panel.
- Clicking a noninteractive status does not accidentally invoke a destructive action.

### 9.3 Auto-collapse

Auto-collapse reduces obstruction and limits exposure of transient content.

- In F2, start a 3-second countdown when entering compact/expanded; pass the value through a test seam rather than persistence.
- Reset countdown on meaningful user interaction.
- Do not collapse while a confirmation dialog is active or keyboard focus is inside an active control.
- Do not collapse solely because a high-rate status update arrives.
- Use restrained animation or immediate transition when Reduced Motion is enabled.

For an expansion opened by hover, pointer exit uses the shorter 100 ms grace instead of the
3-second inactivity policy when no interaction hold is active. Click/shortcut-origin expansion
continues to use the inactivity policy. Holds are scoped to the current expanded interaction
session and include keyboard focus, popover, drag/control tracking, confirmation, and assistive
interaction; leaving `expanded` invalidates all outstanding holds.

### 9.3.1 Fixed expanded admission

Expanded presentation has a fixed `640 × 190 pt` visible contract and requires a `640 × 210 pt`
native host envelope. If current validated topology cannot contain that envelope, NotchHub does
not scale/crop the surface and does not enter recovery: hover stays silent, while click or keyboard
gets bounded accessible feedback and may offer a dedicated application scene. The availability is a
current-topology capability, not a persistent failure state.

### 9.4 Keyboard shortcut

The global surface shortcut maps to ``.

- If hidden/collapsed/compact: open expanded surface.
- If expanded/application scene is active: collapse the surface or close the application scene according to route policy.
- If suppressed: show a clear unavailable/suppressed indication through menu/settings rather than overriding suppression automatically.
- Shortcut behavior obeys permission/capability availability and does not bypass confirmation or action policy.

---

## 10. Focus and accessibility behavior

### 10.1 Focus rules

- Passive compact updates must not steal focus.
- User-triggered expansion may move focus to the panel heading or first primary action.
- Hidden, collapsed, and suppressed states cannot trap keyboard focus.
- Collapse returns focus to the previous application/control where practical.
- Detail opens with focus on its title/primary content.
- Escape always has a safe, non-destructive result.

### 10.2 Announcements

- Announce user-triggered open/close and meaningful action/permission outcomes.
- Do not announce every compact update or high-frequency state change.
- Do not announce every character/token in a future streamed text response.
- Decorative waveform/animation is hidden from accessibility unless it conveys information not available in text.

### 10.3 Color and motion

- Status does not rely on color alone.
- Error/permission/action states include labels and recovery path.
- Reduced Motion disables nonessential bounce, pulsing, sliding, visualizer, and continuous effects.
- Reduced transparency/increased contrast preferences should improve readability rather than only change appearance.

See [`accessibility.md`](accessibility.md) for detailed requirements.

---

## 11. State-specific content patterns

### 11.1 Action result

```text
[Icon] Settings saved
Your Notch behavior preferences are active.
[Open Settings]
```

- Compact if the outcome is brief.
- Show only one clear follow-up action.
- Keep result visible in Diagnostics/recent activity if meaningful.

### 11.2 Recoverable error

```text
[Warning icon] Permission needed
This feature needs access before it can run.
[Open Permissions]
```

- Do not blame the user.
- Explain the next step.
- Avoid full panel expansion unless user has enabled a more assertive policy.

### 11.3 Module unavailable

```text
[Module icon] Module unavailable
The module is disabled or needs setup.
[Open Module Settings]
```

- Include module identity.
- Do not start a module merely because its status is shown.

### 11.4 Future assistant response

```text
[Assistant icon] Thinking…
A short recent line of response text appears here.
[Open conversation]
```

- Stream/coalesce text within compact limits.
- Keep full content in detail.
- Do not auto-open long content.
- Do not use waveform alone to express voice/assistant state.

### 11.5 Progress

```text
[Progress icon] Importing settings
60% complete
[Cancel]
```

- Prefer fraction + short status over verbose logs.
- Coalesce updates.
- Cancel appears only if registered action supports cancellation.

---

## 12. Error, suppression, and recovery UX

### 12.1 Suppressed surface

When the surface is suppressed by full-screen, focus, privacy, or user policy:

- Do not force the panel visible.
- Keep relevant state in app stores/Diagnostics.
- Expose a reason in menu bar/Settings/Diagnostics where useful.
- Return to collapsed when suppression clears.
- Do not replay queued low-priority statuses as a burst after suppression ends.

### 12.2 Surface recovery

If display/panel recovery occurs:

```text
Recovery starts
      ↓
Surface hidden/minimized temporarily
      ↓
Geometry/context revalidated
      ↓
Return to collapsed or suppressed
      ↓
Expose failure only through concise status/Diagnostics
```

- Do not restore expanded/detail automatically after recovery.
- Make at most two recovery attempts, with a 250 ms backoff; then hide the surface and expose a diagnostics warning.
- If recovery fails, preserve menu-bar access and provide Diagnostics access.

### 12.3 Error presentation

| Error category | Default UX |
|---|---|
| Minor/recoverable | Compact status or Settings inline error |
| Module failure | Compact badge/status + Modules/Diagnostics route |
| Permission denied | Permission row/status + Open System Settings |
| IPC/action validation failure | Diagnostics/recent activity; avoid alarming overlay unless user initiated request |
| Surface failure | Menu-bar indicator + Diagnostics; keep app controllable |

---

## 13. User settings that affect interaction

F3/F4 Settings → Notch Behavior may expose:

| Setting | Options/direction |
|---|---|
| Surface enabled | On/off |
| Default resting state | Collapsed/hidden where supported |
| Hover to expand | On/off |
| Hover delay | Validated preset/range |
| Auto-collapse | On/off |
| Auto-collapse timeout | Validated preset/range |
| Full-screen behavior | Show minimally / suppress / user-configured supported options |
| Compact status duration | Validated preset/range |
| Reduced Motion | Follow system / on / off where policy permits |
| Debug overlay | Development builds only |

Settings must not expose raw panel geometry, window levels, opaque event priorities, or other implementation levers that can make interaction unsafe or inconsistent.

---

## 14. Interaction telemetry and diagnostics

The platform records **sanitized, bounded operational metadata**, not raw user content.

Useful metrics:

- Current/previous surface state.
- State transition reason.
- Transition duration.
- Hover expansion canceled/completed count.
- Auto-collapse count.
- Suppression reason/time.
- Recovery count/outcome.
- Click-through/hit-test configuration state.
- Compact status queue/coalescing/drop count.
- Action invocation/result correlation ID.

Do not record pointer movement history, raw keystrokes, raw transcript, full content, or user-sensitive data merely to analyze interaction behavior.

---

## 15. Interaction QA acceptance criteria

The Notch interaction design is ready for foundation completion when:

1. The surface has explicit, tested states: hidden, collapsed, compact, expanded, suppressed, recovering.
2. Hover is optional; core Surface interaction does not depend on a menu visibility toggle.
3. Collapsed/hidden surface does not block unrelated menu-bar/application input.
4. Expanded surface supports click, keyboard navigation, Escape, click-outside, and predictable auto-collapse.
5. Compact content remains concise and one primary status is visible at a time.
6. Long content remains in dedicated application scenes and is never forced into compact/expanded layout.
7. Presentation policy prevents low-priority events from repeatedly interrupting active work.
8. Suppression/recovery return to a safe collapsed/hidden state without automatic restoration of private application-scene content.
9. Reduced Motion and accessibility requirements are met.
10. State changes, queueing, and recovery are diagnosable without storing sensitive interaction content.
11. Manual QA covers display, full-screen, Spaces, sleep/wake, focus, keyboard, and accessibility behavior.

---

## 16. Change control

Update this document when changing:

- Surface states or transition rules.
- Hover/click/timeout/shortcut behavior.
- Compact/expanded/detail content limits.
- Notification, attention, priority, suppression, or recovery policy.
- Focus, keyboard, VoiceOver, Reduced Motion, contrast, or hit-test behavior.
- Settings that affect Notch interaction.
- Module contribution arbitration that changes what appears in a surface slot.

A change that alters native window ownership, `NSPanel` implementation, new OS permission behavior, action security, or fundamental architecture also requires updates to the corresponding architecture/security/platform document and may require an ADR.

---

## 17. Summary

NotchHub’s interaction model makes the Notch useful without making it demanding. It stays calm at rest, expands only for deliberate interaction or carefully selected status, keeps compact information short, moves long content to a application scene, and always provides keyboard/menu alternatives to hover.

The model depends on explicit state, attention policy, safe input handling, accessible focus behavior, bounded update rates, and reliable recovery. These rules give future modules a consistent surface without allowing them to turn the Notch into a distracting, inaccessible, or unpredictable overlay.
