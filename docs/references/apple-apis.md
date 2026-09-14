# Apple APIs Reference
## NotchHub — Public macOS APIs, Responsibilities, and Adoption Rules

**Status:** Draft v0.1  
**Owner:** Architecture / Platform  
**Last updated:** 2026-09-13  
**Location:** `docs/references/apple-apis.md`  
**Related documents:** [Architecture Overview](../architecture/overview.md), [C4 Container](../architecture/c4-container.md), [Notch Surface](../architecture/notch-surface.md), [State Management](../architecture/state-management.md), [Permissions](../platform/permissions.md), [Data Persistence](../architecture/data-persistence.md), [Performance](../architecture/performance.md), [Boring Notch Reference](boring-notch.md)

---

## 1. Purpose

This document maps the Apple/macOS APIs and frameworks that NotchHub may use, explains which architecture component owns each API, and records adoption constraints for a public-API-first implementation.

The goal is not to list every available Apple framework. The goal is to prevent API sprawl and accidental coupling by answering:

- Which API solves which NotchHub problem?
- Which package/container is allowed to use it?
- Does it require a privacy permission, entitlement, or distribution decision?
- What is the fallback when it is unavailable or denied?
- How should it be tested and profiled?

NotchHub targets macOS 14+ and uses SwiftUI for most UI with AppKit for native panel/window/input behavior. Apple documents the [Observation framework](https://developer.apple.com/documentation/observation) as the model-observation facility used to track changes in observable types.

---

## 2. Public-API-first policy

### 2.1 Rules

1. Prefer documented public Apple frameworks and APIs.
2. Keep platform-specific code behind small adapters/protocols.
3. Do not place private framework imports in `NotchDomain` or `NotchCore`.
4. Do not make a visual effect a reason to introduce a private API into the core.
5. Record availability, minimum OS, permission, entitlement, and fallback behavior for every API.
6. Add an ADR before introducing a privileged helper, private framework, undocumented API, or new distribution-sensitive entitlement.
7. Test a signed release-like build, not only an unsigned Xcode debug build.

### 2.2 API adoption record

Before using a new system API, document:

```text
API/framework:
Minimum macOS:
Owning package/container:
Purpose:
Required permission:
Required entitlement:
Data accessed:
Fallback when unavailable/denied:
Lifecycle/cleanup:
Performance impact:
Unit/integration/manual tests:
Distribution impact:
ADR required:
```

---

## 3. Framework map

| Framework/API family | NotchHub use | Owner | Foundation status |
|---|---|---|---|
| SwiftUI | Settings, menu bar scenes, Notch content, design system | `NotchUI`, App Shell, `NotchSurface` views | Adopt |
| AppKit `NSPanel`/`NSWindow` | Native floating Notch surface and separate detail windows | `NotchPanelController` / `DetailWindowCoordinator` | Adopt |
| AppKit `NSScreen` | Screen topology, display frames, scale, built-in-display policy | `NotchSurface` | Adopt |
| AppKit `NSEvent` | Local/global input monitoring where required, click-outside/hotkey support | `NotchSurface`/Shortcut service | Review per feature |
| SwiftUI `MenuBarExtra` | Menu-bar-first recovery/control surface | App Shell | Adopt |
| Observation | Focused presentation stores and settings-facing models | `NotchCore`, `NotchUI` | Adopt on macOS 14+ |
| Foundation | Codable, URLs, dates, process-independent models, file operations | All packages as appropriate | Adopt |
| Network | Loopback IPC/WebSocket if needed | `NotchIPC` | Add when concrete use case exists |
| Security/Keychain | IPC tokens, credentials, secrets | `NotchCore`/persistence adapter | Adopt for secrets |
| OSLog | Structured privacy-aware logging | `NotchCore`/Diagnostics | Adopt |
| UserNotifications | Optional notification module | Notification adapter/module | Future/opt-in |
| EventKit | Calendar/Reminders modules | Future modules only | Future/permissioned |
| AVFoundation | Optional native microphone/audio module | Future Xiaozhi Voice module | Future/permissioned |
| ScreenCaptureKit | Optional screen capture/OCR/context module | Future module only | Future/permissioned |
| CoreServices/LaunchServices | Open known apps/URLs where appropriate | Action adapters | Review per action |
| ServiceManagement | Launch at login | App Shell adapter | Future/optional |
| UniformTypeIdentifiers | File/drop module type declarations | Future Files module | Future |
| Pasteboard APIs | Clipboard module | Future Clipboard module | Future/permission/privacy review |
| Instruments/Xcode tooling | Profiling and release verification | Quality process | Required in F10 |

---

## 4. SwiftUI

### 4.1 Responsibilities

Use SwiftUI for:

- `NotchRootView` and state-specific content views.
- Settings navigation and controls.
- Diagnostics and About views.
- Design-system components.
- Module presentation views and detail windows.
- Accessibility labels, focus behavior, and reduced-motion UI policy.

SwiftUI views should render focused snapshots and send typed intents/actions. They should not own external side effects.

### 4.2 Scenes and lifecycle

SwiftUI scenes represent system-managed UI groupings. [`MenuBarExtra`](https://developer.apple.com/documentation/swiftui/menubarextra) provides a persistent control in the macOS menu bar; Apple documents both menu-like and window-like [`MenuBarExtraStyle`](https://developer.apple.com/documentation/swiftui/menubarextrastyle) variants.

NotchHub uses the menu bar as an independent recovery/control surface:

```text
MenuBarExtra
├── Toggle Notch
├── Open Settings
├── Open Diagnostics
├── Restart App Shell
└── Quit
```

The menu bar scene is not the Notch panel. It should remain usable when the Notch surface is suppressed, hidden, or recovering.

### 4.3 SwiftUI rules

- Keep expensive work out of `body`.
- Observe focused models rather than a global state object.
- Do not create timers, sockets, permission requests, or process execution directly in a view.
- Use `.task` only with explicit cancellation/lifecycle expectations.
- Avoid unbounded `ScrollView`/log/transcript updates in the compact surface.
- Apply Reduced Motion and accessibility labels centrally through `NotchUI` components.

---

## 5. Observation framework

### 5.1 Purpose

The [Observation framework](https://developer.apple.com/documentation/observation) provides Swift-native change tracking for observable model types. Availability must also be enforced by the project's macOS 14 deployment target and verified by the pinned Xcode toolchain.

### 5.2 NotchHub usage

Use `@Observable` for focused presentation models:

```swift
@MainActor
@Observable
final class SurfacePresentationStore {
    private(set) var state: SurfaceState = .collapsed
    private(set) var compactSnapshot: CompactStatusSnapshot?
    private(set) var suppressionReason: SuppressionReason?

    func apply(_ snapshot: SurfacePresentationSnapshot) {
        state = snapshot.state
        compactSnapshot = snapshot.compactSnapshot
        suppressionReason = snapshot.suppressionReason
    }
}
```

### 5.3 Rules

- Split models by domain: surface, settings projection, permissions, runtime health, diagnostics, and module presentation.
- Keep storage actors and external services behind interfaces; expose small main-actor projections.
- Do not make a high-rate event source observable directly by every view.
- Coalesce transcript/audio/metrics snapshots before updating an observable model.
- Test model transitions without SwiftUI.

### 5.4 Migration note

If a component uses `ObservableObject`/`@Published`, migration to [Observation](https://developer.apple.com/documentation/observation) and the `@Observable` macro should be deliberate and covered by tests.

---

## 6. AppKit `NSPanel` and `NSWindow`

### 6.1 Purpose

[`NSPanel`](https://developer.apple.com/documentation/appkit/nspanel) is an AppKit panel/window type suited to auxiliary utility behavior.

NotchHub uses `NSPanel` for the native Notch surface and a separate detail window for long-form content. `DetailWindowCoordinator` owns that window; opening it never creates a `detail` state in the Notch `SurfaceStateMachine`.

### 6.2 Ownership

Only `NotchPanelController` may:

- Create or destroy the Notch `NSPanel`.
- Set frame/position.
- Set window level.
- Set collection behavior.
- Order front/order out.
- Configure titlebar/style masks/appearance.
- Change hit-testing/click-through behavior.
- Attach the SwiftUI hosting view.

No module, view, EventBus handler, or IPC route may call these operations directly.

### 6.3 Panel behavior requirements

- Borderless/utility appearance appropriate to the product design.
- Small hit-test region when collapsed.
- Stable frame animation between surface states.
- No accidental focus stealing for passive compact status.
- Safe recovery after display/sleep/panel invalidation.
- Detail content remains a separate explicit presentation level.

### 6.4 API risks and fallback

Window-level and collection-behavior choices can vary in effect across macOS versions and full-screen/Space configurations. Treat exact constants as an implementation detail validated by F2 manual QA, not as an assumption in `NotchDomain`.

If a desired effect requires private API, first look for a public AppKit behavior or change the UX. Private APIs cannot be introduced into core without a dedicated ADR/security/distribution review.

---

## 7. AppKit `NSScreen`

### 7.1 Purpose

[`NSScreen`](https://developer.apple.com/documentation/appkit/nsscreen) describes available screens and their attributes and provides the screen information used for placement decisions.

NotchHub uses `NSScreen` for:

- Enumerating current displays.
- Identifying the built-in display under the foundation policy.
- Reading visible/frame coordinate spaces and scale-related information.
- Recalculating Notch geometry after display changes.
- Avoiding off-screen/unsafe panel frames.

### 7.2 Ownership

`ScreenTopology` and `NotchGeometry` inside `NotchSurface` own screen calculations. Modules receive only screen-independent presentation slots/snapshots.

### 7.3 Requirements

- Do not assume `NSScreen.main` is always the built-in display.
- Handle empty/invalid screen lists during transitions.
- Recompute geometry after screen-parameter notifications.
- Test physical-notch and no-notch fallback behavior.
- Keep external-display behavior limited and documented in the foundation.

---

## 8. AppKit `NSEvent`

### 8.1 Potential uses

- Local event monitor for click-outside behavior.
- Global shortcut/event support if the selected implementation requires it.
- Keyboard/Escape handling.
- Pointer/hover detection within a narrowly scoped region.

Apple's [`NSEvent`](https://developer.apple.com/documentation/appkit/nsevent) API provides local and global event monitors. Global monitoring receives copies of events posted to other applications; key-related global events require Accessibility trust, so NotchHub must prefer narrowly scoped mouse monitoring and document any permission impact.

### 8.2 Rules

- Prefer the narrowest event mechanism that satisfies the feature.
- Remove monitors when the owning surface/service stops.
- Do not install a full-screen transparent event-catching layer.
- Do not collect or log unrelated keystrokes/mouse events.
- Never place raw event data in diagnostics.
- Document whether the chosen shortcut approach requires Accessibility.
- Test monitor cleanup during module/app shutdown.

### 8.3 Global shortcut boundary

A global shortcut maps to an `ActionID`; it must not call a module method directly. The action still goes through availability, authorization, confirmation, and audit policy.

---

## 9. Menu bar with `MenuBarExtra`

### 9.1 Purpose

[`MenuBarExtra`](https://developer.apple.com/documentation/swiftui/menubarextra) is the preferred SwiftUI entry point for a persistent menu-bar control.

### 9.2 NotchHub use

The menu bar is a recovery path and control center:

- Toggle surface.
- Open Settings.
- Open Diagnostics.
- Show current module/runtime health summary.
- Restart runtime.
- Quit.

### 9.3 Rules

- Menu actions dispatch through `ActionRegistry`.
- The menu bar must work when Notch panel creation/recovery fails.
- Do not place long status/history into the menu.
- Module contributions go under a stable “Modules” section/submenu where appropriate.
- Menu bar labels/icons must remain accessible and concise.

---

## 10. `Foundation` and Swift Concurrency

### 10.1 Use

`Foundation` supports:

- `Codable` models.
- Dates/UUIDs/URLs.
- `Duration`/timing abstractions where available.
- File/persistence adapters.
- `Process` only for a separately reviewed, in-scope macOS use case; not for arbitrary IPC input.
- `NotificationCenter` observation adapters.
- `FileManager` for controlled app-owned paths.

### 10.2 Concurrency rules

- Use `async/await`, actors, and structured task groups where they improve ownership/cancellation.
- Avoid detached tasks without an explicit owner.
- Keep I/O/parsing/persistence off main actor.
- Use `AsyncStream` with bounded/backpressure policy for event streams.
- Test cancellation and shutdown.

### 10.3 File path security

- Resolve app-owned paths explicitly.
- Do not accept arbitrary external paths for execution or persistence.
- Validate import files before applying them.
- Avoid logging full personal paths when a redacted/relative identifier suffices.

---

## 11. `Network` and local IPC

### 11.1 Purpose

The Network framework may be used for local transport when Unix sockets alone are insufficient, including loopback HTTP/WebSocket or a future stream adapter.

### 11.2 Rules

- Bind to `127.0.0.1` or a Unix domain socket; no LAN bind in current product.
- Authenticate HTTP/WebSocket clients.
- Validate protocol version, source, event/action schema, payload size, and rate.
- Keep transport details inside `NotchIPC`.
- Do not pass raw incoming text to an executor.
- Use backpressure/slow-client disconnect for streams.

### 11.3 Availability

`Network` is not required for the first UI shell. The project may implement Unix socket transport first and add loopback HTTP/WebSocket when a concrete local integration needs it.

---

## 12. Security and Keychain

### 12.1 Purpose

Use Apple Security/Keychain APIs for secrets:

- IPC token.
- Future Xiaozhi relay credentials.
- Explicitly approved desktop-module credentials.

### 12.2 Rules

- Expose only a narrow `SecretStore` protocol to core/adapters.
- Do not place secrets in `AppSettings`, UserDefaults, export files, logs, diagnostics, command-line arguments, or source code.
- Diagnostics reports presence/absence, not values.
- Reset non-secrets does not delete credentials.
- Credential deletion is explicit and confirmed.
- Test with a fake secret store; never commit real credentials.

---

## 13. `OSLog` / `Logger`

### 13.1 Purpose

Apple's [`OSLog`](https://developer.apple.com/documentation/oslog) framework provides unified logging and signposting used with tools such as Console and Instruments.

NotchHub uses structured categories:

```text
app.lifecycle
surface.windowing
surface.interaction
settings.persistence
permissions
runtime.modules
events.router
actions.execution
ipc.server
performance
diagnostics
```

### 13.2 Privacy rules

- Use privacy annotations/redaction where supported.
- Log IDs, categories, error codes, durations, and sanitized summaries.
- Do not interpolate tokens, authorization headers, transcript, clipboard, file content, screen content, audio, or camera data.
- Do not use logging as the primary unlimited event store.
- Diagnostics uses bounded storage and export redaction separately from OSLog.

### 13.3 Logging levels

| Level | Use |
|---|---|
| Debug | Development-only state/geometry/resource detail |
| Info | Lifecycle and normal significant transitions |
| Notice | Recoverable degradation or unusual condition |
| Error | Failed operation requiring attention |
| Fault | Invariant violation/system-level failure; use carefully |

---

## 14. `UserNotifications`

### Status

Optional future capability, not required by the foundation.

### Use

- Background action result/error when user opts in.
- Module failure or permission recovery summary.

### Rules

- Request authorization contextually.
- Do not notify for every compact status event.
- Avoid sensitive content in notification body by default.
- Provide notification settings and module-level policy.
- Test denied authorization and notification scheduling failures.

---

## 15. `EventKit` for Calendar/Reminders

### Status

Future modules only.

### Rules

- Access only after user enables/open the feature.
- Use `PermissionCoordinator`.
- Fetch only the minimal date/range/data needed for the UI.
- Cache summaries briefly; do not persist full bodies by default.
- Do not write raw event/reminder data to diagnostics.
- Handle authorization changes and unavailable calendars gracefully.

The module must document the exact macOS API behavior, usage-description requirements, and release/distribution testing before implementation.

---

## 16. `AVFoundation` for Native Xiaozhi Voice

### Status

Future M5 module only; not used by the foundation or display-only Xiaozhi module.

### Potential use

- Microphone input/output device discovery.
- Audio session/input handling.
- Level meter or local waveform support.

### Rules

- Request Microphone permission only when user enables native voice.
- Clearly show active listening/capture state.
- Stop capture on mute/stop/session end/module disable.
- Keep raw audio out of ordinary logs/history.
- Audio processing/streaming must run off main actor.
- Profile CPU, energy, device switching, interruption, and thermal behavior.
- Keep protocol/Opus/backend adapter outside `NotchSurface`.

---

## 17. `ScreenCaptureKit`

### Status

Future screenshot/OCR/screen-context module only.

Apple documents [`ScreenCaptureKit`](https://developer.apple.com/documentation/screencapturekit) for screen and system-audio capture on supported platforms.

### Rules

- Do not request Screen Recording in foundation.
- Explain exactly what screen/audio content is captured and where it goes.
- Use the smallest capture scope possible.
- Stop capture when the feature closes or module stops.
- Do not persist frames or content in generic diagnostics.
- Test permission denial, display changes, capture shutdown, and CPU/energy impact.

---

## 18. `ServiceManagement` / launch at login

### Status

Optional App Shell capability.

### Rules

- User-controlled setting; disabled by default unless product decision changes.
- Start only the intended app/helper target.
- Provide a clear status and error path.
- Do not install hidden background processes.
- Test enable/disable, app removal/update, and launch failure.
- Document signing/entitlement requirements in release docs.

---

## 19. `UniformTypeIdentifiers` and future file interaction

### Status

Future Files module only.

### Potential use

- Declare supported drop/file types.
- Validate dragged/imported data types before processing.
- Keep file content outside generic logs/diagnostics.

### Rules

- Use user-initiated file selection/drop paths.
- Do not treat an imported file as executable configuration.
- Limit thumbnail/cache work and use background tasks.
- Define retention/delete policy before storing metadata or copies.
- Keep file shelf within Notch content constraints; long file lists belong in detail UI.

---

## 20. Pasteboard APIs for Clipboard module

### Status

Future Clipboard module only.

### Rules

- Treat clipboard content as user-content-sensitive.
- Use change detection rather than aggressive polling where practical.
- Keep bounded history and make retention opt-in/visible.
- Do not log clipboard contents.
- Provide clear/delete controls.
- Protect sensitive strings as much as technically possible; do not claim perfect secret detection without evidence.
- Test app restart, clear history, privacy setting, and memory/disk limits.

---

## 21. Xcode Instruments and performance tools

NotchHub must use Instruments during F10 and before adding high-rate modules:

| Tool | Use |
|---|---|
| SwiftUI Instrument | View body cost and excessive update/invalidation |
| Time Profiler | CPU hotspots, parsing, action work |
| Allocations | Retained data/allocation churn |
| Leaks | Object/closure/observer leaks |
| Energy Log | Wakeups, timer/network/disk energy behavior |
| Hangs and Hitches | Main-thread stalls and animation jank |
| Activity Monitor | Broad CPU/RAM/Energy Impact/App Nap validation |

Apple's [Instruments documentation](https://developer.apple.com/documentation/xcode/instruments) covers performance, resource usage, responsiveness, memory, and behavior over time.

Record Mac model, macOS version, display setup, app build, enabled modules, scenario duration, and summarized results.

---

## 22. API-to-container ownership matrix

| API/framework | Primary owner | Test level | Permission/entitlement review |
|---|---|---|---|
| SwiftUI | `NotchUI`, App Shell, Surface views | Unit/snapshot/UI | No privacy permission by itself |
| Observation | Core presentation projections | Unit/integration/UI | No privacy permission |
| `NSPanel`/`NSWindow` | `NotchSurface` | Unit via fake + real macOS manual | Windowing/lifecycle behavior |
| `NSScreen` | `ScreenTopology`/`NotchGeometry` | Geometry + manual display | Display/lifecycle review |
| `NSEvent` | Interaction/shortcut adapter | Unit fake + manual permission | Accessibility/global event review |
| `MenuBarExtra` | App Shell | UI/manual | No privacy permission by itself |
| Network | `NotchIPC` | IPC integration/security | Loopback/local-only policy |
| Keychain | Secret storage adapter | Unit fake + signed integration | Entitlement/distribution review |
| OSLog | Diagnostics | Redaction/unit + release | Privacy review |
| UserNotifications | Notification module | Permission/integration | Notification authorization |
| EventKit | Calendar/Reminders | Permission/integration | Calendar/Reminders authorization |
| AVFoundation | Native voice module | Audio/integration/performance | Microphone authorization |
| ScreenCaptureKit | Screen-context module | Permission/performance | Screen Recording authorization |
| ServiceManagement | App Shell | Release/manual | Signing/entitlement review |
| Pasteboard | Clipboard module | Privacy/integration | Data-retention review |
| UniformTypeIdentifiers | Files module | Unit/UI | File/privacy review |

---

## 23. API adoption checklist

Before merging code that uses a new Apple API:

```text
[ ] API is public/documented for supported macOS versions
[ ] Minimum availability is checked in code
[ ] Owning package/container is correct
[ ] No API call is made from SwiftUI view directly when an adapter is appropriate
[ ] Permission/entitlement requirement is documented
[ ] User-facing explanation exists if sensitive
[ ] Denied/unavailable fallback exists
[ ] Lifecycle cleanup is implemented
[ ] Main-actor/performance impact is reviewed
[ ] Unit/integration/manual tests exist
[ ] Diagnostics/redaction behavior is tested
[ ] Distribution/signing impact is documented
[ ] ADR created if it changes architecture, security, or product scope
```

---

## 24. Public API and private API boundary

### Public API preferred

The foundation should be implementable with:

- SwiftUI and Observation.
- AppKit `NSPanel`, `NSWindow`, `NSScreen`, `NSEvent`.
- Foundation, Security/Keychain, OSLog.
- Network for loopback IPC when needed.
- UserNotifications/EventKit/AVFoundation/ScreenCaptureKit only in future permissioned modules.

### Private/undocumented API policy

Do not import private frameworks or call undocumented symbols in the core. A private/privileged approach is allowed only after:

- Public alternatives are evaluated.
- User value justifies the compatibility/distribution risk.
- A dedicated threat/distribution review is completed.
- An ADR records the decision and fallback.
- The code is isolated behind an adapter/helper.
- The feature can be disabled safely when unavailable.

Boring Notch may provide implementation ideas for notch behavior, but it does not override this public-API-first policy. See [`boring-notch.md`](boring-notch.md).

---

## 25. Example API adoption records

### Example A — `NSPanel`

```text
API/framework: AppKit NSPanel
Minimum macOS: macOS 14
Owner: NotchSurface / NotchPanelController
Purpose: Borderless floating Notch surface
Permission: None by itself
Entitlement: Distribution-dependent; verify target
Data accessed: Window/screen geometry and user interaction
Fallback: Hide surface and preserve menu-bar recovery path
Lifecycle: Create/destroy/reframe on SurfaceCoordinator policy
Performance: Small panel; no continuous render when hidden
Tests: State-machine fake, geometry tests, lifecycle/manual matrix
ADR: Covered by SwiftUI/AppKit hybrid and public-API-first decisions
```

### Example B — `AVFoundation` microphone

```text
API/framework: AVFoundation microphone/audio APIs
Minimum macOS: Verify at implementation time
Owner: Future Native Xiaozhi Voice module
Purpose: Optional Mac voice input/output
Permission: Microphone, requested on explicit user action only
Data accessed: Audio while active session runs
Fallback: Display-only Xiaozhi mode and all other modules remain usable
Lifecycle: Stop capture on mute/stop/session end/disable
Performance: Profile CPU, energy, device switch, interruptions
Tests: Permission, audio lifecycle, privacy, performance, redaction
ADR: Required before M5 implementation
```

---

## 26. Summary

NotchHub uses Apple APIs through narrow, documented adapters: SwiftUI/Observation for focused UI state, AppKit for the native Notch panel and display/input behavior, Keychain for secrets, OSLog for sanitized diagnostics, and Network only for controlled local IPC. Privacy-sensitive frameworks such as EventKit, AVFoundation, ScreenCaptureKit, UserNotifications, and Pasteboard are future module dependencies, not first-launch foundation requirements.

The public-API-first policy keeps the core easier to test, sign, distribute, and maintain across macOS versions. Every new API must have an owner, permission/entitlement review, fallback behavior, cleanup path, performance test, and documentation before it becomes part of the platform.
