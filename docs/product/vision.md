# Product Vision
## NotchHub — Modular macOS Notch Platform

**Status:** Draft v0.2  
**Owner:** Product / Architecture  
**Last updated:** 2026-09-13  
**Related documents:** [README](../../README.md), [Requirements](requirements.md), [Roadmap](roadmap.md), [Architecture Overview](../architecture/overview.md), [Boring Notch Reference](../references/boring-notch.md)

---

## 1. Vision statement

**NotchHub transforms the space around a MacBook notch into a calm, modular, local-first interaction surface for glanceable information, quick actions, and live status from the desktop tools that matter to the user.**

The app must feel native to macOS: present when useful, quiet when not needed, fast to invoke, respectful of attention, battery, privacy, and screen real estate.

NotchHub is not intended to be a generic dashboard permanently occupying the top of the display. It is a focused control and status surface that expands only for a short interaction, then returns to the background.

---

## 2. Problem

Modern MacBook hardware includes a visually prominent notch, while many daily workflows are distributed across menu-bar icons, application windows, browser tabs, notifications, and small utilities.

Relevant short-lived information may include:

- Current media playback and quick controls.
- A short AI/voice interaction state or streamed reply.
- A pending action requiring confirmation.
- A recent clipboard item, dropped file, timer, calendar item, or system control.
- Connection state of a locally integrated desktop service.

These signals are often fragmented. They either require opening a full application, reading noisy notifications, or placing too many icons in the menu bar. Existing notch utilities demonstrate that the notch can become useful, but they are commonly designed around a fixed consumer feature set rather than a durable, modular platform.

The challenge is not simply drawing a black panel around the notch. The challenge is to create a stable macOS platform that handles panel behavior, settings, permissions, shortcuts, actions, security, resource usage, diagnostics, and future modules without becoming an unstable all-in-one utility.


---

## 3. Target users

### Primary user: macOS power user

A technically capable MacBook user who values fast interaction, AI tools, media, local automation, keyboard shortcuts, and a clean desktop.

They value:

- Fast access to common actions without context switching.
- Live operational state that does not consume a full window.
- Local-first integrations and inspectable behavior.
- Keyboard shortcuts and automation.
- Clear error states, logs, diagnostics, and predictable permissions.

### Secondary user: productivity-focused MacBook user

A user who wants a lightweight notch utility for media, clipboard, quick actions, timers, calendar, or focused reminders, but prefers a calm interface over a dense dashboard.

They value:

- A polished native interaction model.
- Small, useful widgets instead of many menu-bar icons.
- Sensible defaults and easy settings.
- Privacy and battery-friendly behavior.

### Future user: module developer

A developer who wants to add a macOS productivity or assistant module without learning or modifying all details of AppKit window management, global shortcuts, settings persistence, IPC security, or diagnostics.

They value:

- Stable module contracts.
- Clear UI contribution slots.
- Typed events and actions.
- Declared permissions and resource budgets.
- Good templates, tests, and documentation.

---

## 4. User value proposition

NotchHub provides five forms of value.

### 4.1. Glanceability

The user can see relevant short-lived status without opening a dashboard.

Examples:

- “Assistant is thinking…”
- “Timer finished.”
- “Media paused.”
- “Clipboard saved.”
- “Calendar event in 10 min.”

### 4.2. Fast action

The user can invoke common operations from one predictable location using hover, click, or a global shortcut.

Examples:

- Open Settings or Diagnostics.
- Toggle a module.
- Pause/play media.
- Copy a clipboard item.
- Open a dropped file.
- Stop a future voice session.

### 4.3. Unified integration surface

Instead of every integration adding its own menu-bar icon, floating window, or notification behavior, modules publish events and actions into one shared platform with consistent UI and policy.

### 4.4. Controlled extensibility

Modules can be added without coupling the entire application to one backend, protocol, device ecosystem, or AI vendor. The platform provides stable contracts for state, settings, actions, permissions, UI slots, event flow, and diagnostics.

### 4.5. Trustworthy background behavior

The app aims to be a good macOS citizen:

- Minimal activity while idle.
- No surprise permission prompts.
- No raw arbitrary command execution from external integrations.
- Local-first IPC by default.
- Explicit, inspectable settings.
- Diagnostics available when something fails.

---

## 5. Experience principles

### Calm by default

The notch should disappear into the background when there is no useful information. The app must not create constant visual noise, distracting animation, or frequent interruption.

### Reveal information progressively

| Layer | Purpose | Example |
|---|---|---|
| Passive indicator | Quiet status at a glance | Small state icon or badge |
| Compact Notch | One to three lines of transient information | “Assistant is thinking…” |
| Expanded panel | Quick interaction lasting seconds | Action grid, controls, current summary |
| Detail window | Long content or configuration | Settings, transcript, history, diagnostics |

### One action model everywhere

Menu items, Notch buttons, keyboard shortcuts, local IPC, scripts, and future AI integrations invoke the same registered `ActionID` with validated typed input.

### Make activity explainable

If the app is accessing a capability, showing a status, failing a module, or asking for a permission, the user should be able to discover why through the UI and diagnostics.

### Local-first and privacy-conscious

The default path should not expose a LAN service or send user data to a remote backend. Future external integrations must be explicit and must preserve a clear data boundary.

### Efficient by design

A Notch utility may remain open all day. It must have small idle CPU and battery impact, bounded memory, controlled update rates, and modules that truly stop their background work when disabled.

### Accessible and keyboard-capable

All interactive elements need accessible labels, keyboard reachability, visible focus states where appropriate, sufficient contrast, and a reduced-motion mode.

---

## 6. Product scope

### Base platform scope

Before business modules, NotchHub must provide:

- A menu-bar-first application shell and recovery path.
- A Notch surface based on AppKit `NSPanel` with SwiftUI content.
- Notch surface states: hidden, collapsed, compact, expanded, suppressed, recovering.
- Long-form module content opens in a separate, explicitly requested detail view/window and is not a Notch surface state.
- Interaction: hover, click, click-outside, Escape, auto-collapse, keyboard shortcut.
- Settings with typed schema, validation, migration, reset, and sanitized import/export.
- A centralized Permission Center.
- Action Registry with typed actions, availability checks, confirmation policies, and cancellation/timeouts.
- A compile-time module runtime with enable/disable, lifecycle, health state, and fault isolation.
- Versioned events, EventBus, Presentation Policy, and local IPC.
- Diagnostics, structured logging, resource metrics, debug overlay, and testing hooks.
- Performance budgets and bounded data/resource policies.

### Initial module direction

| Order | Module | First purpose |
|---|---|---|
| M0 | Sample Status Module | Validate real module contracts end to end |
| M1 | Xiaozhi Display Companion | Display voice/AI state and streamed text through a normalized relay |
| M2 | Media or Clipboard | Daily macOS utility and consumer UX validation |
| M3 | Files or System Controls | File interaction or selected system controls with permission review |
| M4 | Calendar or Reminders | Contextual productivity information and actions |
| M5 | Native Xiaozhi Voice | Optional Mac microphone/audio path if needed |

### Permanent exclusions

NotchHub does not include:


---

## 7. Non-goals

NotchHub will not initially:

- Clone the full feature set, implementation, or branding of Boring Notch.
- Behave like an always-visible desktop dashboard.
- Render full terminal output, full transcripts, or long documents in the notch.
- Implement dynamic runtime loading of third-party executable plugins.
- Receive arbitrary shell commands from voice, AI, HTTP, WebSocket, or local scripts.
- Expose network controls to a LAN by default.
- Ask for microphone, camera, calendar, screen recording, accessibility, or automation permissions on first launch without an explicit user action.
- Depend on private macOS APIs in the core platform.
- Promise perfect multi-display behavior before the built-in display experience is stable.

---

## 8. Reference and differentiation

### Boring Notch reference

[Boring Notch](https://github.com/TheBoredTeam/boring.notch) is an open-source reference project that demonstrates useful notch behavior and provides practical implementation ideas around panel management, animation, system integration, and macOS edge cases.

NotchHub will study Boring Notch for technical learning, especially:

- AppKit and SwiftUI composition.
- Floating panel/window management.
- Notch/non-notch geometry behavior.
- Hover, expansion, and animation patterns.
- Settings and feature organization.
- Lifecycle and macOS environment edge cases.

### Differentiation

| Area | Typical feature-first notch utility | NotchHub direction |
|---|---|---|
| Core purpose | A curated bundle of visible features | A modular command/status platform |
| Feature growth | Add features directly to app code | Add modules through explicit contracts |
| Integration | Product-specific integrations | Local-first event/action/IPC boundary |
| AI/voice | Optional isolated feature | Future module using normalized adapter events |
| Productivity | Usually generic widgets | Extensible macOS productivity surface |
| Security | Depends on each feature | Typed action allow-list and confirmation policy |
| Reliability | Feature behavior centered | Foundation-first lifecycle, diagnostics, testing |
| Performance | Often feature dependent | Budgets and resource policies required per module |

---

## 9. Success criteria

### Foundation success criteria

The base platform is successful when it can be used and extended safely even before a real business module exists.

- The app launches reliably as a menu-bar utility.
- The Notch surface behaves predictably through hover, click, Escape, timeout, sleep/wake, Space changes, and full-screen policy.
- Settings persist, migrate safely, recover from corrupt data, and apply at runtime.
- Permission behavior is centralized, contextual, and non-disruptive.
- Menu bar, Notch UI, shortcut, and IPC invoke the same Action Registry.
- A demo module can start, stop, fail, and be disabled without crashing the core app.
- External IPC input is authenticated, validated, rate-limited, and local-only by default.
- Diagnostics identify the current surface state, active modules, permissions, event/action health, and major resource indicators.
- No unbounded event, log, transcript, cache, or process-output storage is present.

### User experience targets

| Area | Target |
|---|---|
| Notch opening latency | Less than 150 ms under normal load |
| Local event to compact UI | Less than 100 ms under normal load |
| Idle CPU | Less than 0.3% average target |
| Typical memory footprint | 40–80 MB idle; 60–120 MB with lightweight expanded UI |
| Visible interaction | No systematic frame hitches during normal open/close/use |
| Permissions | No unrequested prompts at first launch |
| Failure containment | One module failure does not crash the platform |
| Security | No arbitrary shell execution path from external input |

### Long-term success criteria

- Adding a module does not require editing `NotchPanelController`.
- Adding an integration does not require changing the UI core.
- A module can declare permissions, settings, actions, UI slots, and resource policy through contracts.
- AI/voice integrations are replaceable adapters, not hard dependencies of the platform.

---

## 10. Trust, privacy, and safety

### Privacy commitments

- Default integrations are local-only.
- The user controls which modules are enabled.
- Future transcript/history retention is opt-in and configurable.
- Diagnostics export redacts secrets, authorization headers, tokens, and sensitive raw payloads.
- The app does not request permissions before there is a clear user-visible need.
- The app documents what each module reads, stores, sends, and displays.

### Safety commitments

- External inputs are treated as untrusted until validated.
- Voice/AI integrations invoke registered actions only, with typed inputs.
- Destructive or side-effecting actions require an appropriate confirmation policy.
- Local HTTP/WebSocket services bind to loopback by default; Unix domain sockets are preferred for local tooling where practical.
- Secrets are stored in Keychain, never ordinary settings or application logs.

---

## 11. Platform constraints

### Technical constraints

- Minimum supported OS: macOS 14 Sonoma.
- Primary language: Swift 6.
- UI: SwiftUI.
- Native panel/window/input integration: AppKit.
- Initial display scope: built-in MacBook display first.
- Initial plugin model: compile-time static modules.
- Initial integration scope: local IPC before LAN API.
- Initial macOS API policy: public APIs first; privileged helpers or private APIs require separate architectural review.

### Product constraints

- The app must remain useful even with no enabled feature module.
- The settings and diagnostics experience cannot be deferred until after modules exist.
- Performance and energy behavior must be considered before adding streaming, media, system-monitoring, or file features.
- Module authors cannot be trusted to manage window lifecycle or permission prompts correctly; the platform must centralize those concerns.

---

## 12. Open questions

1. Should the application ship as a sandboxed app, a non-sandboxed direct distribution app, or support both distribution paths?
2. What is the exact signing/notarization strategy for beta and public releases?
3. Which global shortcut implementation offers the best balance of capability, user expectations, and permission requirements?
4. What UI contribution API should modules use after static module architecture stabilizes?
5. Which local IPC transport should become the primary developer API: Unix socket, loopback HTTP, or both?
6. What configuration format should be used for import/export and action profiles?
7. Which first daily-use module best validates the platform after M0: Xiaozhi Display Companion, Media, or Clipboard?
8. When and how should multi-display support be introduced without degrading reliability?
9. What diagnostics retention policy balances debuggability with privacy and disk use?
10. Under what conditions, if any, should an external plugin model be considered?

---

## 13. Vision summary

NotchHub aims to make the MacBook notch useful without making the Mac distracting. It will be a modular, local-first macOS platform that turns the notch into a trustworthy surface for brief status and deliberate action.

The project begins by investing in the difficult but reusable foundation: window behavior, settings, permissions, shortcuts, actions, IPC, diagnostics, performance, and tests. Only after that foundation is stable will Xiaozhi, media, clipboard, files, calendar, system controls, and other desktop modules be added.

This order is intentional. A polished module is valuable; a reliable platform that can host many modules for years is more valuable.
