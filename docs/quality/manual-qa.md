# Manual QA Plan
## NotchHub — macOS Lifecycle, UI, Permission, Security, and Release Verification

**Status:** Draft v0.1  
**Owner:** Quality / Platform / Architecture  
**Last updated:** 2026-09-14  
**Location:** `docs/quality/manual-qa.md`  
**Related documents:** [Testing Strategy](testing-strategy.md), [Requirements](../product/requirements.md), [Roadmap](../product/roadmap.md), [Notch Surface](../architecture/notch-surface.md), [macOS Lifecycle](../platform/macos-lifecycle.md), [Permissions](../platform/permissions.md), [Accessibility](../design/accessibility.md), [Threat Model](../security/threat-model.md), [Performance](../architecture/performance.md), [Boring Notch Reference](../references/boring-notch.md)

---

## 1. Purpose

This document defines the manual quality assurance plan for NotchHub on real macOS environments.

Automated tests protect contracts and deterministic state transitions. Manual QA is required for behavior that depends on the macOS window server, display topology, Spaces, full-screen applications, sleep/wake, lock/unlock, menu-bar behavior, privacy prompts, signed builds, accessibility tools, and long-running resource behavior.

The goal is to verify that NotchHub is:

- Reliable as a menu-bar utility.
- Safe and predictable as a floating Notch surface.
- Usable through keyboard and VoiceOver paths.
- Respectful of permissions and privacy.
- Secure at its local IPC/action boundary.
- Stable across display/session lifecycle changes.
- Efficient during long idle and repeated interaction.
- Ready for a real module only after the Foundation Completion Gate.

This plan covers the foundation and provides a template for future modules. It does not cover ESP-IDF, ESP32 gateway, IoT, MQTT, BLE gateway, or LAN device-control workflows because those domains are permanently outside NotchHub scope.

---

## 2. QA principles

1. **Test on real macOS** — especially windowing, display, permission, and lifecycle behavior.
2. **Use release-like builds** — signing/sandbox/entitlements can change behavior compared with Debug.
3. **Record environment** — macOS, Xcode/build, Mac model, display setup, permission state, and module configuration.
4. **Start with a clean baseline** — known settings, known modules, no stale IPC/socket/process state.
5. **Test both success and recovery** — denial, failure, disconnect, invalid input, sleep/wake, and display loss are normal QA cases.
6. **Do not weaken safety to pass QA** — do not expose LAN, accept raw commands, disable validation, or grant broad permissions as workarounds.
7. **Repeat lifecycle tests** — one successful run is insufficient for a long-running menu-bar utility.
8. **Protect test data** — use synthetic content; never collect real credentials, transcripts, clipboard, audio, camera, screen, calendar, or personal file data.
9. **Log evidence** — each failed case has a reproduction path, environment, diagnostics export, and severity.
10. **Foundation first** — real modules start only after foundation cases and gates pass.

---

## 3. Supported test scope

### 3.1 Required foundation environment

- macOS 14 or newer, matching the supported project target.
- MacBook with built-in display; physical notch preferred for primary UI verification.
- A second external display for display topology tests when available.
- Release-like signed build for permission/Keychain/launch behavior.
- Development build for debug overlay, test event injection, and diagnostics detail.

### 3.2 Recommended matrix

| Profile | Purpose |
|---|---|
| MacBook Apple Silicon with physical notch | Primary surface/windowing validation |
| MacBook without physical notch or fallback environment | Top-center fallback geometry |
| Apple Silicon with external display | Attach/detach/scale/topology behavior |
| Lowest supported macOS/hardware target | Baseline performance/reliability |
| Latest supported macOS | Compatibility/regression verification |
| Release-like signed build | Permission, Keychain, entitlement, launch behavior |
| Development build | Debug overlay, test injector, detailed diagnostics |

The project must record actual tested models/OS versions in release evidence. If only one machine is available, document the limitation rather than claiming broad compatibility.

---

## 4. Test data and initial state

### 4.1 Safe test data

Use synthetic data such as:

```text
User: QA Test User
Project: NotchHub Demo
Transcript: “Xin chào, đây là dữ liệu kiểm thử.”
Clipboard: “SYNTHETIC_CLIPBOARD_VALUE_NOT_SECRET"
File: /tmp/NotchHub-QA/synthetic.txt
Calendar: “Synthetic QA Event”
Token: generated test token, never a real credential
```

Do not use:

- Real API keys/passwords.
- Real Xiaozhi credentials.
- Personal clipboard/history.
- Real calendar/reminder content.
- Real private files.
- Microphone recordings/camera frames/screen captures.
- User-specific absolute paths in screenshots/reports.

### 4.2 Baseline reset

Before a clean test run:

1. Quit NotchHub.
2. Ensure no prior NotchHub process is running.
3. Ensure stale IPC socket/lock state is handled by the app, not manually hidden.
4. Launch with a documented clean settings profile or reset non-secret settings through the app.
5. Confirm no unexpected modules are enabled.
6. Confirm Diagnostics/log retention is bounded.
7. Confirm test permission state is known.
8. Record app version/build and environment.

Do not delete Keychain credentials as part of a normal settings reset. Use the explicit credential reset procedure only when a test requires it.

---

## 5. Evidence and result format

### 5.1 Test case result

Use:

```text
Test ID:
Date/time:
Tester:
App version/build:
macOS version:
Mac model/architecture:
Display setup/scale:
Build type/signing:
Enabled modules:
Relevant permission state:
Preconditions:
Steps:
Expected result:
Actual result:
Result: PASS / FAIL / BLOCKED / NOT APPLICABLE
Diagnostics/report:
Screenshots/video:
Issue ID:
Severity:
Notes:
```

### 5.2 Evidence rules

- Screenshots/videos must not contain secrets or personal data.
- Diagnostics exports must be sanitized before attachment.
- Record exact steps for failures; do not write “doesn’t work.”
- Include logs around the failure, but redact tokens/paths/user content.
- For performance issues, include Instruments/Activity Monitor summary and scenario duration.

### 5.3 Severity

| Severity | Meaning | Release effect |
|---|---|---|
| Critical | Arbitrary action execution, secret leak, data loss, crash loop, severe permission bypass | Blocks all release |
| High | Core crash, panel unrecoverable, permission storm, unbounded memory growth, severe focus trap | Blocks foundation/module release |
| Medium | Module failure contained, incorrect state, diagnostics gap, recoverable lifecycle issue | Must have issue/owner; release only by decision |
| Low | Minor visual/copy/animation mismatch with no safety impact | May defer with issue |

---

## 6. Foundation smoke test

**Purpose:** Fast verification after every build.

### Steps

1. Launch the app.
2. Confirm the menu-bar icon/control appears.
3. Open menu-bar menu.
4. Open Settings.
5. Open Diagnostics.
6. Toggle the Notch surface.
7. Test expanded → collapse with Escape.
8. Test click outside.
9. Trigger a deterministic Demo status if available.
10. Check no unexpected permission prompt appears.
11. Quit and relaunch.

### Expected result

- App launches without crash or duplicate instance.
- Menu bar remains usable.
- Settings and Diagnostics open independently of the surface.
- Surface state transitions are responsive.
- No raw secret or personal data appears in Diagnostics.
- Quit/relaunch is clean.

**Release blocking:** Any crash, focus trap, arbitrary prompt, inaccessible recovery path, or broken menu-bar control is at least High severity.

---

## 7. App shell and lifecycle QA

## QA-APP-001 — First launch

**Preconditions:** Clean settings; no sensitive permissions granted; no stale process/socket.

**Steps:** Launch app for the first time.

**Expected:**

- Menu bar utility starts.
- No mass permission prompts.
- Settings/Diagnostics available.
- Surface starts hidden/collapsed according to default.
- Startup errors appear only as safe diagnostics.

## QA-APP-002 — Relaunch and single instance

**Steps:** Launch twice quickly; then quit/relaunch repeatedly.

**Expected:**

- Only one process owns surface/IPC.
- Second launch exits safely or activates existing instance.
- No duplicate menu icon, panel, event listener, timer, or socket.
- Settings are not overwritten by the second process.

## QA-APP-003 — Menu-bar recovery path

**Steps:** Make the surface hidden, suppress it, or simulate panel failure in a development build. Use menu bar.

**Expected:**

- Settings, Diagnostics, Restart App Shell, and Quit remain available. A ModuleRuntime-specific restart is only applicable after F7.
- User can inspect why surface is unavailable.
- Menu bar does not depend on successful panel creation.

## QA-APP-004 — Quit and relaunch

**Steps:** Quit while surface is expanded, DemoModule is running, IPC client connected, and an action is active where testable. Relaunch.

**Expected:**

- New actions/IPC are rejected or closed safely during shutdown.
- Modules/tasks/observers/sockets stop within bounded time.
- No stale lock/socket prevents restart.
- Settings last-known-good state restores.
- No side-effecting action resumes automatically after restart.

## QA-APP-005 — Launch at login (when implemented)

**Steps:** Enable/disable launch at login; log out/in or restart as appropriate.

**Expected:**

- App launches only when enabled.
- No hidden unapproved helper process.
- Sensitive modules do not auto-enable/request permission unexpectedly.
- Disable/uninstall/update behavior is correct.

---

## 8. Notch surface and interaction QA

## QA-SUR-001 — Collapsed surface

**Steps:** Launch/return app to collapsed state. Move/click pointer across menu bar around the surface.

**Expected:**

- Collapsed content is minimal/quiet.
- Hit-test region is limited; unrelated menu-bar items remain clickable.
- Transparent corners and shadow envelope click through, including after native mouse events have been ignored and then re-enabled by pointer movement.
- No full-screen transparent overlay intercepts clicks.
- No continuous animation or high CPU while idle.

## QA-SUR-002 — Hover expansion

**Steps:** Enable hover-to-expand. Move pointer into/out of trigger region, including brief incidental passes.

**Expected:**

- Configured hover delay is respected.
- Incidental pointer movement does not cause excessive expansion.
- Expansion is smooth and bounded.
- Hover can be disabled in Settings; menu/shortcut still works.
- Hover-origin close observes the 100 ms grace, re-entry cancellation, and active interaction holds.

## QA-SUR-003 — Click expansion

**Steps:** Click collapsed/compact surface.

**Expected:**

- Surface enters expanded state.
- Focus behavior is predictable; passive status does not steal focus unnecessarily.
- Primary controls are visible and actionable.

## QA-SUR-004 — Escape and click-outside

**Steps:** Expand surface. Press Escape. Reopen and click outside. If a detail window is available, repeat its independent Escape/back route.

**Expected:**

- Escape collapses/returns according to documented route.
- Click outside collapses when appropriate.
- Focus is not trapped after collapse.
- No action is accidentally triggered by Escape.

## QA-SUR-005 — Auto-collapse

**Steps:** Expand and remain inactive; then interact immediately before timeout; repeat with configured timeout values.

**Expected:**

- Panel collapses after configured inactivity timeout.
- Interaction resets timeout.
- Auto-collapse does not interrupt active keyboard/pointer interaction.
- Timeout tasks are cancelled when panel closes/stops.

## QA-SUR-006 — Detail route

**Steps:** Open a detail view from a deterministic demo contribution. Navigate back/collapse.

**Expected:**

- Detail requires explicit user action.
- Long content appears in a suitable detail window, not compact surface.
- Keyboard/Escape/back route works.
- Closing detail does not leave stale focus or panel state.

## QA-SUR-007 — Debug overlay (development build)

**Steps:** Toggle `surface.toggleDebugOverlay`.

**Expected:**

- Overlay shows state, selected display, frame, suppression reason, event/update/resource summary where implemented.
- Overlay is readable and does not alter release behavior.
- Overlay is disabled by default in release-like builds.

---

## 9. Display and geometry QA

## QA-DIS-001 — Physical notch built-in display

**Steps:** Run on a supported MacBook with physical notch. Test collapsed/compact/expanded surface states and the separate detail window route.

**Expected:**

- Panel aligns with notch/top-center geometry.
- All states remain on-screen and do not overlap unusable areas unexpectedly.
- Geometry remains stable after repeated open/close.

## QA-DIS-002 — No-notch fallback

**Steps:** Run on a supported no-notch/fallback display configuration if available.

**Expected:**

- Surface uses safe top-center fallback.
- UI remains visually/operationally consistent.
- No assumption about a physical camera frame causes crash/off-screen placement.

## QA-DIS-003 — External display attach/detach

**Steps:** With surface visible, attach/detach external display. Repeat with external display as main display.

**Expected:**

- Built-in-display-first policy remains predictable.
- Surface re-evaluates topology/geometry.
- No duplicate panels or off-screen hit-test layer.
- If built-in display unavailable, surface hides/suppresses safely in foundation.
- Settings/Diagnostics remain available.

## QA-DIS-004 — Resolution/scale change

**Steps:** Change built-in display resolution/scale while surface is collapsed, expanded, and detail.

**Expected:**

- Frame recomputes.
- Surface returns to safe collapsed/suppressed state if needed.
- No stale old-scale frame remains.
- Text/control layout remains readable.

## QA-DIS-005 — Lid close/open

**Steps:** Close/open lid with external display where applicable.

**Expected:**

- Built-in display unavailable policy is followed.
- App does not render Notch surface arbitrarily on external screen in foundation.
- On reopen, geometry and surface recover safely.

---

## 10. Spaces and full-screen QA

## QA-SPACE-001 — Space switching

**Steps:** Switch Spaces with surface collapsed, compact, expanded, and detail.

**Expected:**

- Behavior matches documented collection policy.
- No panel duplication/disappearance inconsistency.
- No unexpected focus stealing.
- State converges to collapsed/suppressed after context changes where required.

## QA-SPACE-002 — Full-screen application

**Steps:** Enter/exit full-screen with “show on full-screen” disabled and enabled.

**Expected:**

- Suppression policy is applied consistently.
- Low-priority module/event cannot force expansion during suppression.
- Exiting full-screen returns to safe collapsed state, not unexpected expanded state.
- No transparent overlay blocks the full-screen app.

## QA-SPACE-003 — Menu-bar auto-hide

**Steps:** Enable menu-bar auto-hide; test menu bar and Notch interaction.

**Expected:**

- App does not create a stuck trigger zone.
- Menu-bar recovery path works when menu bar is available.
- Surface remains safe when menu bar is hidden.

---

## 11. Sleep, wake, lock, and session QA

## QA-LIFE-001 — Sleep/wake while collapsed

**Steps:** Put Mac to sleep and wake.

**Expected:**

- No crash.
- No duplicate observer/task/panel.
- Surface state is safe and geometry is valid.
- Diagnostics records recovery status if applicable.

## QA-LIFE-002 — Sleep/wake while expanded/detail

**Steps:** Sleep while expanded/detail, then wake/unlock.

**Expected:**

- Panel hides/suppresses during sleep.
- On wake, it returns to collapsed/suppressed rather than unexpectedly exposing long/private content.
- No stuck `recovering` state.
- Focus restoration is safe.

## QA-LIFE-003 — Lock/unlock

**Steps:** Lock session with surface/detail open; unlock.

**Expected:**

- Private content is not exposed unexpectedly on lock screen/session transition.
- No crash/focus trap.
- Permission/screen status refreshes after activation.
- User can reopen detail intentionally.

## QA-LIFE-004 — Repeated lifecycle stress

**Steps:** Repeat sleep/wake, lock/unlock, Space and full-screen transitions.

**Expected:**

- No increasing memory/task/observer count.
- No duplicate event/action subscriptions.
- Recovery remains bounded.

---

## 12. Settings QA

## QA-SET-001 — Navigation

**Steps:** Open all pages: General, Appearance, Notch Behavior, Shortcuts, Permissions, Actions, Modules, Diagnostics, About.

**Expected:**

- Navigation order and labels are consistent.
- All pages are reachable from keyboard.
- No page starts disabled modules or network adapters merely because it was opened.
- Deep links land on the intended page/control.

## QA-SET-002 — Appearance settings

**Steps:** Change theme/opacity/preset/Reduced Motion.

**Expected:**

- Changes preview safely and persist after relaunch.
- Text/status remains readable under all supported combinations.
- Reduced Motion removes/reduces nonessential animation.
- Invalid/unsafe values cannot be saved.

## QA-SET-003 — Notch behavior settings

**Steps:** Change hover, timeout, full-screen, and display-policy settings.

**Expected:**

- Runtime behavior changes safely.
- Settings do not expose raw window-level/unsafe geometry fields.
- Panel recreation/recovery is bounded.
- Menu/shortcut alternatives remain available when hover is disabled.

## QA-SET-004 — Reset settings

**Steps:** Reset appearance/behavior, shortcuts, module settings, and all non-secrets using explicit confirmation.

**Expected:**

- Exact scope is shown before confirmation.
- Last-known-good/backup behavior is safe if write fails.
- Keychain credentials are not deleted by non-secret reset.
- App remains usable after reset.

## QA-SET-005 — Import/export (when implemented)

**Steps:** Export sanitized settings. Inspect safely. Import valid, invalid, old-version, unknown-version, and oversized files.

**Expected:**

- Export contains no secrets/raw sensitive data.
- Import validates/previews before apply where supported.
- Invalid/unknown config is rejected or safely migrated.
- Failed import leaves active settings unchanged.

---

## 13. Permission QA

## QA-PERM-001 — First launch no prompt storm

**Preconditions:** All optional sensitive permissions not determined.

**Steps:** Launch app, open Settings, navigate Permissions.

**Expected:**

- No Microphone/Camera/Calendar/Screen Recording/Automation prompt appears.
- Page accurately labels capabilities as not used/not required.
- User can read why a future module may need them.

## QA-PERM-002 — Notifications opt-in (when implemented)

**Steps:** Enable Notifications through contextual UI; deny; open System Settings; grant; return to app.

**Expected:**

- Explanation appears before prompt.
- Denied state is clear and non-blocking.
- “Open System Settings” route works.
- Status refreshes after return.
- No repeated prompt loop.

## QA-PERM-003 — Accessibility/shortcut permission (if required)

**Steps:** Enable the feature that actually requires Accessibility; deny/grant; test shortcut.

**Expected:**

- Permission is not requested for unused features.
- Explanation matches actual behavior.
- Fallback menu/click action remains available.
- Shortcut status reflects permission accurately.

## QA-PERM-004 — Future Microphone display-only boundary

**When M1 exists:** Run Xiaozhi Display Companion without Native Voice.

**Expected:**

- No Microphone prompt.
- Display/status/transcript relay path works without capture.
- Settings explains display-only behavior.

## QA-PERM-005 — Permission revoke while active module

**When a permissioned module exists:** Grant, run feature, revoke externally, return to app.

**Expected:**

- Capability-specific work stops.
- Module becomes suspended/degraded.
- Core remains usable.
- No repeated prompt/capture.
- Regrant resumes only according to explicit module policy.

---

## 14. Shortcut and keyboard QA

## QA-KEY-001 — Shortcut recording

**Steps:** Open Settings → Shortcuts, record valid shortcut, clear it, cancel recording with Escape.

**Expected:**

- Recording state is visible/readable.
- Escape cancels without changing existing binding.
- Clear removes binding only.
- Conflict/unavailable state is explained.

## QA-KEY-002 — Shortcut behavior

**Steps:** Invoke core shortcuts from another app, while Notch is collapsed/expanded, and during full-screen suppression.

**Expected:**

- Shortcut maps to ActionID and follows surface/policy state.
- It does not execute twice.
- It does not bypass suppression/confirmation.
- It does not capture/log unrelated keystrokes.

## QA-KEY-003 — Keyboard-only Settings

**Steps:** Navigate Settings with keyboard only.

**Expected:**

- All pages and controls reachable.
- Focus order logical.
- Return/Space activates expected controls.
- Escape closes/cancels where documented.
- No focus trap.

---

## 15. Accessibility and VoiceOver QA

## QA-A11Y-001 — VoiceOver menu/Settings

**Steps:** Enable VoiceOver; navigate menu bar and all Settings pages.

**Expected:**

- Controls have meaningful labels/values/hints.
- Disabled/denied/error states include explanations.
- Focus follows route/deep link.
- No decorative blur/icon/waveform noise overwhelms navigation.

## QA-A11Y-002 — VoiceOver Notch surface

**Steps:** Open expanded surface via shortcut/menu; navigate controls; collapse.

**Expected:**

- Surface open/focus behavior is predictable.
- Primary controls are discoverable.
- Escape/collapse works.
- Focus is not retained on hidden/destroyed panel.

## QA-A11Y-003 — Reduced Motion/contrast

**Steps:** Enable Reduced Motion, increased contrast/reduced transparency where available; exercise panel and Settings.

**Expected:**

- Nonessential animation/visualizer is reduced/disabled.
- Status remains understandable using text/icon.
- Contrast/readability remain acceptable.
- No important state disappears because animation was removed.

---

## 16. Action platform QA

## QA-ACT-001 — Foundation action catalogue

**Steps:** Open Settings → Actions; inspect and run safe foundation actions.

**Expected:**

- Actions use stable IDs/labels/availability.
- Menu/Notch/shortcut/Settings invoke the same behavior.
- Results appear in compact status/Diagnostics according to policy.

## QA-ACT-002 — Confirmation

**Steps:** Run an action requiring confirmation from Notch, Settings, shortcut, and approved IPC source.

**Expected:**

- Confirmation shows action, source, target/consequence.
- Cancel is safe and is default keyboard focus where appropriate.
- Escape cancels.
- User confirmation cannot be bypassed through IPC/future assistant source.

## QA-ACT-003 — Invalid action input

**Steps:** Send unknown ActionID, malformed input, prohibited raw command fields, unknown executor fields, and oversized input through test IPC.

**Expected:**

- Requests are rejected before executor.
- Safe error code is returned.
- Diagnostics records sanitized reason.
- No process/side effect starts.

## QA-ACT-004 — Action timeout/cancellation

**Steps:** Use a deterministic delayed fake action/test operation.

**Expected:**

- Timeout/cancel result is typed and visible.
- Running task stops where possible.
- No orphan task remains.
- Action can be invoked again safely.

---

## 17. Module runtime and DemoModule QA

## QA-MOD-001 — DemoModule enable/disable

**Steps:** Enable/disable DemoModule repeatedly.

**Expected:**

- Status/slot/action appear when enabled.
- Contributions/actions disappear or become unavailable after disable.
- No app restart required where supported.
- No timer/task/observer/subscription duplication.

## QA-MOD-002 — DemoModule failure isolation

**Steps:** Trigger debug-only simulated failure during start/handler.

**Expected:**

- Module enters failed state with sanitized error.
- Settings, Diagnostics, menu bar, surface core, and unrelated modules remain usable.
- Retry is bounded and explicit.

## QA-MOD-003 — Module resource cleanup

**Steps:** Enable/disable/restart DemoModule 100 times in a controlled test build.

**Expected:**

- Resource counters return near baseline.
- No duplicate action/event/subscription.
- Memory does not trend upward.

## QA-MOD-004 — Module UI contribution limits

**Steps:** Use a test contribution exceeding compact/expanded content limits.

**Expected:**

- Contribution is truncated/rejected/degraded with diagnostics warning.
- Module cannot enlarge surface beyond policy.
- Detail route is offered for long content.

---

## 18. Event protocol and IPC QA

## QA-IPC-001 — Health/status

**Steps:** Run `notchctl health/status` before/after app launch/restart and while surface/module is degraded.

**Expected:**

- Health response is bounded/sanitized.
- Status reflects app/runtime/surface/IPC state.
- No secrets/raw settings appear.

## QA-IPC-002 — Authentication/source policy

**Steps:** Use valid token, invalid token, revoked token, unknown client ID, and source/event mismatch.

**Expected:**

- Valid allowed request succeeds.
- Invalid/unknown requests are rejected.
- No raw token in errors/logs/diagnostics.
- Repeated failures trigger bounded rate/backoff behavior.

## QA-IPC-003 — Event validation

**Steps:** Send valid event, unknown version/type, missing fields, oversized/deep payload, stale sequence, duplicate ID, and unauthorized event family.

**Expected:**

- Only valid allowed events reach EventBus/module.
- Invalid events produce safe error and diagnostics counter.
- Duplicate/stale events follow documented policy.
- Event flood does not block UI.

## QA-IPC-004 — Slow stream client

**When WebSocket is implemented:** Connect a client that does not consume messages.

**Expected:**

- Queue remains bounded.
- Server coalesces or disconnects slow client safely.
- Other clients/app UI remain responsive.

## QA-IPC-005 — Shutdown/restart with client

**Steps:** Keep IPC client connected; quit/restart app.

**Expected:**

- Server stops accepting clients.
- Client disconnect is bounded.
- Stale socket is recovered on restart.
- No duplicate event subscription after reconnect.

---

## 19. Persistence and privacy QA

## QA-DATA-001 — Settings migration

**Steps:** Start with each supported old schema fixture; launch app.

**Expected:**

- Migration completes deterministically.
- Settings are valid and behavior matches documented migration.
- Migrated data is written safely.
- Migration failure falls back without blocking startup.

## QA-DATA-002 — Corrupt settings

**Steps:** Use truncated/invalid settings fixture; launch app.

**Expected:**

- App starts with safe defaults/last-known-good state.
- Diagnostics explains sanitized migration/load failure.
- User can reset/import safely.

## QA-DATA-003 — Secret handling

**Steps:** Configure synthetic IPC credential through intended secure flow; export settings/diagnostics and inspect logs.

**Expected:**

- Secret value never appears in export/log/diagnostic.
- Non-secret reset does not delete credential.
- Explicit credential deletion requires confirmation.

## QA-DATA-004 — Bounded data

**Steps:** Flood diagnostic/action/event data; repeat app/module operation.

**Expected:**

- Ring buffers rotate.
- Disk/memory stays within configured cap.
- Old data is dropped/coalesced as documented.
- No raw user-content data appears in generic history.

---

## 20. Security and privacy QA

## QA-SEC-001 — Arbitrary execution rejection

**Steps:** Send action requests containing `command`, `script`, `executablePath`, unknown executor, unvalidated URL/host, and hardware/LAN target fields.

**Expected:**

- Request rejected before executor.
- No process/network/hardware action occurs.
- Sanitized security diagnostic recorded.

## QA-SEC-002 — Scope exclusion verification

**Steps:** Inspect action catalogue, event registry, Settings, IPC routes, module list, and documentation.

**Expected:**

- No ESP-IDF, ESP32 gateway, IoT, MQTT, BLE gateway, or LAN device-control actions/events/settings/routes exist.

## QA-SEC-003 — Diagnostic redaction

**Steps:** Inject synthetic token, authorization header, transcript, clipboard, file path/content, calendar text, and error payload through test doubles.

**Expected:**

- Logs/Diagnostics/export contain only redacted/sanitized metadata.
- No secret or raw sensitive payload appears.

## QA-SEC-004 — Local-only binding

**Steps:** Inspect listener binding/Diagnostics; attempt connection from local interface and verify no LAN bind.

**Expected:**

- IPC is Unix socket/loopback only.
- No wildcard/LAN listener exists.
- Any future network exposure is blocked until security review.

---

## 21. Performance and energy QA

Detailed scenarios are in [`performance.md`](../architecture/performance.md) and [`testing-strategy.md`](testing-strategy.md). Manual QA must verify the following before foundation completion.

## QA-PERF-001 — Idle soak

**Duration:** At least 8 hours where practical.

**Expected:**

- Idle CPU within target (< 0.3% average target).
- Memory does not grow without bound.
- No unexpected fast timer/polling/network/disk activity.
- App remains responsive after idle period.

## QA-PERF-002 — Panel cycle stress

**Steps:** Open/collapse/expand 1,000 times with mixed interaction paths.

**Expected:**

- No increasing memory/native window/task/observer count.
- No systematic hitches.
- Final state is stable and menu bar remains usable.

## QA-PERF-003 — Event flood

**Steps:** Inject high-rate valid/invalid/duplicate/progress events.

**Expected:**

- UI remains responsive.
- Coalescing/drop/rate-limit counters behave correctly.
- Bounded queues/history/cache.
- Main actor is not blocked.

## QA-PERF-004 — Module toggle loop

**Steps:** Enable/disable/restart DemoModule 100 times.

**Expected:**

- Resources return near baseline.
- No duplicate event/action/subscription.
- No memory trend.

## QA-PERF-005 — Instruments profile

**Tools:** SwiftUI Instrument, Time Profiler, Allocations, Leaks, Energy Log, Hangs/Hitches, Activity Monitor.

**Expected:**

- Any hotspot has an issue/decision.
- No unexplained leak/growth or main-actor blocking.
- Profile records include OS/Mac/display/build/module configuration.

---

## 22. Release smoke checklist

A release candidate must pass:

```text
[ ] Clean install/launch
[ ] Menu-bar item/control visible
[ ] Settings/Diagnostics open
[ ] No unexpected permission prompts
[ ] Notch surface basic interaction
[ ] Shortcut/menu/action routing
[ ] Settings persistence and reset
[ ] IPC health/status/auth (if enabled)
[ ] Module enable/disable/failure (DemoModule)
[ ] Sleep/wake/lock/unlock smoke
[ ] External display attach/detach smoke
[ ] Signed/release-like Keychain/permission behavior
[ ] Diagnostic export redaction
[ ] No excluded ESP/IoT/LAN scope present
[ ] No critical/high unresolved defect
[ ] Version/build/license/third-party notices correct
[ ] README/setup/release docs accurate
```

---

## 23. Module QA template

Every future module must add a manual QA section based on this template:

```markdown
# <Module> Manual QA

## Environment

## Test data

## Preconditions

## Permissions

## Startup/enablement

## Main user flows

## Disabled/degraded/failed states

## Permission denied/revoked

## Action/confirmation behavior

## Keyboard/VoiceOver/Reduced Motion

## Sleep/wake/Space/full-screen/display behavior

## IPC/reconnect behavior, if applicable

## Privacy/redaction/retention

## Performance/energy

## Cleanup/disable/restart

## Evidence

## Known issues
```

### Future Xiaozhi Display Companion additions

- Display-only mode without Microphone permission.
- Relay connect/disconnect/reconnect.
- Assistant state transitions.
- Transcript delta/final/sequence/duplicate/gap behavior.
- Vietnamese Unicode display/readability.
- Bounded transcript history.
- No raw audio/protocol dump in UI/Diagnostics.
- Assistant action allow-list/confirmation.
- Detail transcript navigation and accessibility announcements.
- Event flood/coalescing and performance.

---

## 24. Foundation Completion Gate

Manual QA is complete enough for a real module only when:

1. Foundation smoke passes on the primary supported MacBook.
2. Menu bar/Settings/Diagnostics remain usable when surface is unavailable.
3. Notch interaction/geometry/lifecycle matrix passes for supported initial scope.
4. Sleep/wake/lock/unlock/Spaces/full-screen/display tests pass or have documented accepted limitations.
5. Settings, permissions, shortcuts, actions, module runtime, EventBus, IPC, persistence, and diagnostics manual scenarios pass.
6. Accessibility/VoiceOver/keyboard/Reduced Motion checks are recorded.
7. Security/privacy negative tests pass; no arbitrary execution or secret leakage.
8. Performance/energy smoke and required Instruments scenarios meet budgets or have approved deviations.
9. No excluded ESP-IDF/ESP32/IoT/LAN functionality exists.
10. All Critical/High defects are closed or release-blocking decisions are recorded.
11. Results/evidence are linked from roadmap/index/release notes.

Only after this gate may M0/M1 real module development begin.

---

## 25. Summary

Manual QA protects the platform behaviors that automated tests cannot fully reproduce: real macOS windowing, display topology, Spaces, full-screen, sleep/wake, permission prompts, signed builds, VoiceOver, keyboard focus, and long-running energy behavior.

The plan deliberately tests failure, denial, recovery, resource cleanup, security boundaries, and product-scope exclusions—not only the normal Notch animation. A passing manual QA cycle means NotchHub is a reliable foundation for future in-scope macOS modules such as Xiaozhi, Media, Clipboard, Files, Calendar, and System Controls.
