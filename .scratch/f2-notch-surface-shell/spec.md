# F2 Notch Surface Shell

**Status:** complete
**Phase:** F2
**Owner:** Platform / Architecture / Design

## Problem Statement

NotchHub đã hoàn tất App shell F1 và có menu-bar recovery path, nhưng Notch surface vẫn chỉ là một intent unavailable. Người dùng chưa thể mở một panel native quanh camera housing, chưa có phản hồi hover/click/Escape/timeout đáng tin cậy, và chưa có cách phục hồi panel sau thay đổi màn hình, Space, full-screen hay sleep/wake. Nếu feature hoặc Module tự tạo cửa sổ ở giai đoạn này, AppKit ownership, hit-testing và lifecycle sẽ phân tán và tạo ra một overlay không an toàn.

## Solution

Xây dựng F2 như một vertical slice Notch surface cho built-in MacBook display: `NotchPanelController` là chủ sở hữu duy nhất của `NSPanel`; một `SurfaceCoordinator` điều phối state machine thuần Swift, topology/geometry, local input và lifecycle intents. Surface chỉ hiển thị placeholder deterministic, dùng các default không persist, và luôn có App shell menu-bar làm recovery path. Long-form content đi qua một Detail view riêng do `DetailWindowCoordinator` sở hữu; nó không phải một Notch surface state.

## User Stories

1. As a MacBook user, I want to open the Notch surface from the menu bar, so that the F1 recovery path can reveal the F2 panel.
2. As a MacBook user, I want the surface to appear around my built-in display's camera housing or safe top-center fallback, so that it feels intentional rather than like an arbitrary floating window.
3. As a user, I want the surface to begin hidden or collapsed without showing product integrations, so that F2 remains a deterministic platform slice.
4. As a user, I want a small collapsed indicator, so that I can discover the surface without losing menu-bar input.
5. As a user, I want hovering over the bounded trigger region to expand the surface after 150 ms, so that incidental pointer movement does not cause distraction.
6. As a user, I want the hover trigger to extend only 8 pt beyond visible collapsed content, so that unrelated menu-bar controls remain clickable.
7. As a user, I want collapsed expansion to require the bounded hover trigger while compact content remains clickable, so that clicking a collapsed Surface cannot replay expansion.
8. As a user, I want expanded placeholder content to remain short and legible, so that the Notch surface does not become a dashboard.
9. As a user, I want a compact status to contain at most a few concise lines, so that transient feedback does not obscure my work.
10. As a user, I want an inactive compact or expanded surface to collapse after 3 seconds, so that it clears itself without manual housekeeping.
11. As a user, I want interaction inside an expanded surface to reset auto-collapse, so that a timer never interrupts an active task.
12. As a user, I want Escape and click-outside to return the expanded surface to collapsed, so that I always have a safe exit.
13. As a user, I want collapsed and compact content to remain passive and not steal focus, so that status updates do not disrupt the foreground app.
14. As a keyboard and VoiceOver user, I want user-triggered expansion to provide predictable focus and Escape behavior, so that the surface remains accessible.
15. As a user, I want a placeholder detail affordance to open a separate Detail view, so that long-form content is not forced into the Notch surface.
16. As a user, I want repeated detail requests to focus or reuse the intended Detail view, so that the app does not create an unbounded number of windows.
17. As a user, I want closing the Detail view to leave the Notch surface in a valid non-detail state, so that navigation does not corrupt panel state.
18. As a user, I want the panel to remain reachable across Spaces when not suppressed, so that its behavior is predictable.
19. As a user, I want the surface to suppress by default while another app is full-screen, so that it does not overlay immersive work.
20. As a user, I want the surface to return safely to collapsed when the full-screen condition clears, so that it does not unexpectedly reopen expanded.
21. As a user, I want display attach/detach, scale changes, lid changes, sleep/wake, and lock/unlock to avoid crashes or stuck panels, so that a long-running menu-bar app remains reliable.
22. As a user using clamshell mode, I want the surface to hide or suppress rather than render arbitrarily on an external display, so that built-in-display-first behavior is honest.
23. As a user, I want failed panel recovery to leave the menu bar, Settings, and Diagnostics reachable, so that a panel failure is recoverable.
24. As a developer, I want a debug overlay showing surface state, target display, computed frame, interaction flags, collection behavior, suppression reason, and recovery outcome, so that real macOS issues are diagnosable.
25. As a developer, I want the debug overlay controlled by an F2-only menu/debug control, so that F2 does not prematurely require the Action Registry.
26. As a maintainer, I want exactly one component to create, order, frame, show, hide, and destroy the native panel, so that native window ownership cannot drift.
27. As a maintainer, I want every unsupported state transition to be rejected or safely ignored, so that timing and OS notifications cannot produce undefined presentation behavior.
28. As a maintainer, I want recovery to attempt at most twice with a 250 ms backoff before hiding and recording a warning, so that failure cannot create a hot loop.
29. As a reviewer, I want the implementation to preserve the SwiftUI/AppKit boundary, so that no view, Module, or App shell code owns an `NSPanel`.
30. As a reviewer, I want the initial display policy to remain built-in-display-first, so that F2 does not claim multi-display placement support before it is validated.
31. As a quality engineer, I want pure state and geometry behavior testable without an `NSPanel`, so that deterministic failures are caught without interactive macOS automation.
32. As a quality engineer, I want F2 manual evidence on a physical-notch MacBook, so that mocks and builds are not mistaken for windowing proof.
33. As a future F3/F4 developer, I want F2 values to be injectable but not persistent settings, so that validation, migration, and UI policy remain in their intended phases.
34. As a future F6 developer, I want F2 menu intents to remain local user intents, so that typed Actions and shortcuts can be introduced without backporting an incomplete registry.
35. As a future Module author, I want F2 to expose no Module-specific panel ownership or content path, so that Module isolation remains a later platform contract.

## Implementation Decisions

- Preserve the canonical terms **App shell**, **Notch surface**, and **Detail view**. A Detail view is a separate, explicitly requested window or scene and is never a `SurfaceState`.
- Integrate F2 with the App shell's existing Toggle Notch Surface intent. The App shell remains usable if surface creation or recovery fails.
- Introduce `NotchPanelController` inside the NotchSurface boundary as the sole owner of the native `NSPanel`: creation, configuration, screen assignment, frame, level, collection behavior, ordering, hit-testing, destruction, and recreation. No SwiftUI view, Module, NotchCore owner, or App shell object may access that panel directly.
- Use SwiftUI for hosted placeholder views and AppKit only behind the NotchSurface boundary for panel, screen, input, and lifecycle behavior, preserving ADR-0002.
- Use the existing domain `SurfaceState` set exactly: `hidden`, `collapsed`, `compact`, `expanded`, `suppressed`, and `recovering`. Keep state transition logic AppKit-free and reject or normalize undeclared transitions.
- Introduce a single `SurfaceCoordinator` seam that accepts surface intents plus injected panel, screen-topology, pointer/click-outside, scheduler, and lifecycle adapters. It owns translation from observable platform/user input to state-machine events; it does not own arbitrary product content or Module logic.
- Implement `ScreenTopology` and `NotchGeometry` for the built-in display. Prefer physical notch geometry when available; otherwise use a safe top-center fallback. Do not assume the target is `NSScreen.main` and never place the foundation surface on an arbitrary external screen.
- Join all Spaces when the surface is otherwise eligible. Suppress by default when another app is full-screen, then return to collapsed when suppression clears. F3/F4 may later add a validated preference; F2 has no Settings UI or persistence.
- Scope the collapsed hit-test region to visible content plus an 8 pt margin. Hidden and suppressed surface states have no pointer target. Never install a full-screen transparent input-catching window.
- In F2, use dependency-injected defaults: hover delay 150 ms and auto-collapse 3 seconds. Interaction resets the timer. Values are testable but not stored; hover/timeout/full-screen preferences are deferred to F3/F4.
- Use the menu-bar toggle as the F2 control path. Do not implement a global shortcut, shortcut recorder, Action Registry, or `ActionID` dispatch in this phase; those are F6 work.
- Add one deterministic placeholder flow in expanded content that emits a local user-navigation intent to `DetailWindowCoordinator`. The coordinator owns one reusable/focusable placeholder Detail view. Closing it must not mutate the Notch surface into a nonexistent detail state.
- Keep passive compact updates non-activating. Allow explicit click/keyboard expansion to establish predictable focus. Return focus to the prior application/control where practical after collapse; a Detail view may receive normal window focus.
- On display/panel invalidation, enter `recovering`, revalidate topology and geometry, and attempt recreation/reframe at most twice with a 250 ms backoff. On exhaustion, send the permanent-failure transition, hide the surface, and surface a sanitized diagnostic warning through the available recovery path.
- Pause native animation and interaction through sleep; on wake, revalidate topology before normal surface behavior resumes. Treat lock/unlock, Space changes, display changes, and full-screen transitions as ordinary inputs, not exceptional control flow.
- Add a development-only debug overlay controlled by an F2 menu/debug control. It reports sanitized state, computed geometry, selected screen, hit-test/interaction flags, window level/collection behavior, suppression reason, and recovery count/outcome. It is disabled by default in release-like builds.
- Keep only deterministic placeholder content. Settings persistence, operational Diagnostics retention/export, Presentation policy, EventBus, permissions, ModuleRuntime, real Modules, IPC, and real integrations remain outside F2.

## Testing Decisions

- The primary automated seam is `SurfaceCoordinator` with a real AppKit-free state machine and injected recording/fake adapters for native panel effects, topology, input, scheduler, and lifecycle. A good test asserts observable intents, stable state, requested panel effects, and recovery outcomes—not private AppKit calls or SwiftUI view internals.
- Test every declared state transition and major invalid/rejected event. Verify auto-collapse is suppressed or reset during active interaction; visible states suppress correctly; `recovering` always converges to collapsed, suppressed, or hidden.
- Test geometry invariants with synthetic topology: physical-notch target, no-notch fallback, invalid/zero bounds, resolution and scale changes, built-in display unavailable, and external attach/detach. Assert safe on-screen bounds, correct target selection, and no menu-bar overlap rather than hard-coded pixels.
- Test hit-testing and input as external behavior: the 8 pt trigger margin opens after 150 ms; exit-before-delay cancels; hidden/suppressed exposes no target; click, Escape, click-outside, and inactivity yield the documented state changes; focus policy does not make passive content active.
- Test full-screen default suppression, Space reachability intent, sleep/wake revalidation, two-attempt 250 ms recovery, permanent failure warning, and continued App shell recovery availability.
- Test Detail view behavior through its coordinator contract: only explicit user navigation opens it, repeated requests reuse/focus it, close leaves the Notch surface in a non-detail state, and recovery never restores it automatically.
- Extend the existing Swift Testing package suite and use its `@Test` style, existing domain state assertion, and AppCoordinator fake-adapter tests as prior art. The F2 seam is intentionally one coordinator-level seam rather than per-view test hooks.
- Run the existing composite verification command after implementation changes. It remains the repository-level seam for formatter, boundaries, build, tests, Markdown links, and secret scan.
- Require manual macOS evidence on the supported physical-notch MacBook for launch/relaunch; collapsed hit-testing; hover/click/Escape/click-outside; detail route; full-screen; Space changes; sleep/wake; lock/unlock; attach/detach; lid; resolution/scale; debug overlay; and repeated open/close. No-notch fallback requires automated geometry coverage and manual evidence only when hardware is available, with any limitation recorded.
- Do not treat a successful build, mocked adapter test, rendered SwiftUI view, or accessibility tree alone as proof of F2 manual windowing and lifecycle behavior.

## Out of Scope

- Full Settings information architecture, persisted Notch behavior preferences, schema migration, reset, import/export, and any settings storage.
- Global shortcut registration, shortcut recorder, shared Action Registry, typed Action execution, confirmation, and `surface.toggleDebugOverlay` as an Action.
- Presentation policy, EventBus, IPC, `notchctl`, permissions, Keychain, operational diagnostics storage/export, performance profiling beyond F2 verification, and telemetry retention.
- ModuleRuntime, DemoModule, Module UI contributions, Module-specific content, real integration data, Xiaozhi, native audio, media, clipboard, files, calendar, reminders, and system controls.
- Multi-display placement parity, arbitrary external-display surface hosting, private APIs, dynamic plugins, privileged helpers, and any transparent full-screen event layer.

## Further Notes

- F0 and F1 are complete. This spec is ready for implementation after its issue-tracker publication.
- The specification concretizes existing ADR-0002 and ADR-0010 plus the already accepted Notch surface and interaction documents; it does not require a new ADR because it applies previously chosen boundaries to the first F2 slice.
- The F2 evidence record must distinguish unit/integration results from manual macOS results and identify actual Mac model, macOS version, Xcode version, tested display context, and any unrun scenario.

## Comments

- 2026-09-15: Đóng phase theo yêu cầu người dùng. Automated verification đã được ghi nhận; các scenario native/manual chưa chạy vẫn được giữ nguyên trong evidence artifact và checklist ticket.
