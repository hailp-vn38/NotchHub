# F1 App Shell and Lifecycle

**Status:** ready-for-agent
**Phase:** F1
**Owner:** Platform / Architecture

## Problem Statement

NotchHub đã hoàn tất F0, nhưng application host hiện chỉ mở một cửa sổ scaffold. Người dùng chưa có một App shell chạy lâu dài trong menu bar, chưa có đường recovery độc lập khi Notch surface không tồn tại hoặc không khả dụng, và chưa có bằng chứng lifecycle cho launch, quit, relaunch, sleep/wake hay activation. Nếu F2 bắt đầu từ scaffold này, panel và module tương lai sẽ phải tự gánh lifecycle, làm vi phạm ownership đã chốt.

## Solution

Xây dựng F1 như một App shell menu-bar-first có `AppCoordinator` là chủ sở hữu duy nhất của lifecycle trong pha này. Menu phải luôn cho phép mở hai placeholder scene độc lập là Settings và Diagnostics, đồng thời trả về trạng thái unavailable rõ ràng cho các intent thuộc pha sau. App shell xử lý lifecycle idempotent, quan sát activation/deactivation và sleep/wake, có abstraction launch-at-login dựa trên `SMAppService`, và có evidence tự động + manual macOS trước khi đóng F1.

## User Stories

1. As a MacBook user, I want NotchHub to start as a menu-bar-first utility, so that I can reach its controls without a normal scaffold window becoming the product surface.
2. As a user, I want the menu bar to remain reachable even when the Notch surface is unavailable, so that I always have a recovery path.
3. As a user, I want to open Settings from the menu, so that I can confirm the future configuration entry point is independently reachable.
4. As a user, I want to open Diagnostics from the menu, so that I can confirm the future troubleshooting entry point is independently reachable.
5. As a user, I want Settings and Diagnostics to be clearly labelled placeholders in F1, so that I do not mistake them for persisted settings or operational diagnostics.
6. As a user, I want Toggle Notch Surface to state that the surface is unavailable before F2, so that the app never creates an unreviewed panel early.
7. As a user, I want Show Demo State to state that it is unavailable before the relevant platform capability exists, so that a demo intent does not imply a Module or Notch surface implementation.
8. As a user, I want Restart App Shell to recover only the app-shell coordination owned by F1, so that it never starts a future ModuleRuntime by accident.
9. As a user, I want Quit to stop F1-owned work cleanly, so that no process, observer, or task is left hanging.
10. As a user, I want a quit and relaunch to leave one usable menu-bar entry, so that repeated launches do not create duplicate in-process state.
11. As a user, I want sleep and wake to preserve a usable menu-bar recovery path, so that laptop lifecycle changes do not crash or expose an unintended UI.
12. As a user, I want activation and deactivation to be safe and quiet, so that the app does not steal focus or trigger permissions.
13. As a user, I want F1 to make no privacy-sensitive request at launch, so that future capabilities do not create a first-launch permission storm.
14. As a user, I want the application to use normal macOS app-bundle behavior for launch delivery, so that it behaves like a native macOS utility rather than inventing a fragile lock protocol.
15. As a user, I want launch-at-login capability to be isolated from the menu implementation, so that its system integration can be tested without changing the actual login-item state in tests.
16. As a maintainer, I want `AppCoordinator` to be the lifecycle owner, so that later containers do not acquire competing startup or shutdown behavior.
17. As a maintainer, I want repeated lifecycle delivery to be idempotent, so that one process does not duplicate menu resources or observers.
18. As a maintainer, I want later-phase menu intents to have explicit unavailable outcomes, so that phase boundaries are observable and do not silently expand scope.
19. As a maintainer, I want the app shell to shut down resources in reverse ownership order, so that teardown is predictable and testable.
20. As a reviewer, I want F1 to preserve ADR-0004's independent menu-bar recovery surface, so that control paths do not become dependent on the future Notch surface.
21. As a reviewer, I want F1 to preserve ADR-0002's AppKit boundary, so that F1 does not create an `NSPanel` or move window ownership outside NotchSurface.
22. As a reviewer, I want F1 to avoid a custom process lock, IPC handoff, or local listener, so that there is no premature endpoint ownership or trust boundary.
23. As a quality engineer, I want a high-level coordinator seam with injected lifecycle and launch-at-login adapters, so that observable App shell behavior is testable without interactive macOS UI manipulation.
24. As a quality engineer, I want manual macOS evidence for cold launch, scene reachability, relaunch, sleep/wake, and activation, so that the phase does not treat mocks as proof of system behavior.
25. As a future F2 developer, I want F1 to report the surface unavailable rather than simulate it, so that introducing the sole `NotchPanelController` owner remains a clean vertical slice.
26. As a future F3/F4 developer, I want placeholder scenes without preference persistence, so that typed settings, migration, and reset policy are not pre-empted.
27. As a future F7/F9 developer, I want no ModuleRuntime or Diagnostics store in F1, so that runtime isolation and operational retention remain owned by their intended phases.
28. As a release reviewer, I want F1 evidence to record the machine/environment and unrun scenarios, so that a passing build is not confused with manual macOS lifecycle validation.

## Implementation Decisions

- Use the canonical term **App shell** for the menu-bar-first application host. `AppCoordinator` owns F1 composition, startup, lifecycle observation, restart, and teardown.
- Build the menu-bar entry with the supported SwiftUI menu-bar API or an `NSStatusItem` wrapper only if the former cannot satisfy the required observable behavior. Keep native panel ownership out of F1.
- Expose six F1 menu intents: Toggle Notch Surface, Show Demo State, Open Settings, Open Diagnostics, Restart App Shell, and Quit.
- Settings and Diagnostics are independent placeholder scenes. They must state their limited F1 role and must not persist Settings, expose operational records, start modules, or create a Notch surface.
- Surface-toggle and demo-state intents produce an explicit unavailable result until their owning capabilities exist. Restart App Shell restarts only F1-owned in-memory coordination; it must not be named or implemented as a ModuleRuntime restart.
- Treat normal macOS app-bundle/LaunchServices behavior as the F1 single-instance foundation. Make startup idempotent inside the process. Do not add a custom lock, socket, second-launch handoff, or endpoint cleanup policy in F1.
- Introduce a small fakeable launch-at-login capability abstraction whose production adapter uses `SMAppService`. F1 has no preference control, durable setting, hidden helper, or automatic registration.
- Observe launch, termination, activation, deactivation, sleep, wake, lock, and unlock only to the extent needed to keep F1 resources safe and menu-bar reachability intact. No event may trigger a permission request, panel creation, module startup, IPC startup, or focus steal.
- Model observable outcomes at one high seam: a coordinator-facing App-shell snapshot plus menu intents and lifecycle events, with injected adapters for lifecycle notification, menu/scene presentation, and launch-at-login. This is the preferred seam; do not create separate test-only seams inside every SwiftUI view.
- Preserve the accepted architecture: the Notch surface remains the sole future `NSPanel` owner; Settings persistence, operational diagnostics, ModuleRuntime, Actions, IPC, permissions, and detail views remain in their documented later phases.
- Keep the F1 evidence record as the phase gate. It must distinguish automated verification from manual macOS results and explicitly name skipped/unrun scenarios.

## Testing Decisions

- A good F1 automated test asserts externally visible App-shell behavior at the coordinator seam: menu intents reach the correct result, placeholder scenes are independently requested, lifecycle transitions are safe, and owned resources start once then stop cleanly. It must not assert SwiftUI `body` internals, menu implementation details, or AppKit objects.
- Use injected fake lifecycle, scene-presentation, and launch-at-login adapters. The production `SMAppService` integration is exercised only through its adapter contract; automated tests must never modify the machine's real login-item registration.
- Cover idempotent startup, reverse-order teardown, Quit, Restart App Shell, activation/deactivation, sleep/wake, unavailable surface/demo outcomes, and absence of permission/panel/module/IPC startup.
- Add app-shell tests in the existing Swift Testing style. The existing pure-domain `@Test` suite is prior art for test naming and execution; the existing composite verification script is prior art for the highest repository-level build/test seam.
- Run the existing composite verification command after F1 changes, preserving formatter, package boundary, build, test, documentation-link, and secret-scan checks.
- Record manual macOS evidence for cold launch, independent Settings/Diagnostics reachability, unavailable surface/demo intents, Restart App Shell, quit/relaunch, sleep/wake, and activation/deactivation. Record Mac model, macOS version, Xcode version, date, and tester.
- Do not treat a build, mocked coordinator test, or UI screenshot as proof of the manual lifecycle gate. Any manual scenario not run must remain explicitly pending with a reason.

## Out of Scope

- `NSPanel`, `NotchPanelController`, surface state transitions, geometry, hit-testing, display topology, full-screen/Spaces panel policy, global shortcuts, and detail-view navigation.
- Full Settings information architecture, design system, typed persistence, schema migration, reset, import/export, and any stored preference UI.
- Operational Diagnostics store, export, retention, logging contract, module health, event history, or performance metrics.
- ModuleRuntime, DemoModule, Actions registry/executors, EventBus, presentation policy, permissions, Keychain access, local IPC, `notchctl`, custom process locks, and cross-process handoff.
- Dynamic plugins, private APIs, privileged helpers, Xiaozhi, native audio, media, clipboard, files, calendar, reminders, and system controls.

## Further Notes

- F0 is closed with recorded local and green pull-request verification. F1 may begin immediately under this spec.
- This spec concretizes ADR-0004 and ADR-0002; it does not create a new ADR because the selected F1 boundaries are reversible phase scoping, not a new durable platform shape.
- The authoritative phase documentation, lifecycle contract, container view, requirements, testing strategy, and F1 evidence template were updated before this spec was published. Any change that introduces a panel, persistence, module runtime, IPC, or a custom interprocess mechanism requires a scope review before implementation.
