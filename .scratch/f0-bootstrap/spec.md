# F0 Bootstrap and Architecture

**Status:** ready-for-agent  
**Phase:** F0  
**Owner:** Foundation / Architecture

## Problem Statement

NotchHub đã có product boundary, requirements, glossary và 12 ADR được chấp nhận, nhưng chưa có application scaffold có thể build/test lặp lại. Nếu bắt đầu F1 hoặc một Module ngay bây giờ, nhóm sẽ phải tự suy đoán package graph, toolchain, quality gate và domain boundary; điều đó tạo drift ngay từ foundation.

## Solution

Hoàn thành F0 bằng một foundation scaffold chạy được trên macOS 14+: một root Swift package cung cấp sáu platform target, một Xcode application host, toolchain/formatter được pin, CI cho pull request, và các pure-domain contract tối thiểu. Một pipeline CI cho pull request là seam kiểm thử cao nhất và duy nhất của F0: nó thực thi đúng các lệnh mà clean clone phải chạy được, thay vì test từng lựa chọn scaffold bằng các cơ chế riêng lẻ.

## User Stories

1. As a maintainer, I want a clean clone to resolve, build, and test with documented commands, so that a contributor can begin work without local assumptions.
2. As a maintainer, I want the Xcode/Swift toolchain pinned and matched by CI, so that local and pull-request results are reproducible.
3. As a platform developer, I want the six foundation targets to have an acyclic dependency graph, so that later work cannot accidentally couple the Notch surface to business features.
4. As a domain developer, I want `NotchDomain` to remain pure Swift, so that contracts can be tested without SwiftUI, AppKit, I/O, or a running macOS UI.
5. As a platform developer, I want identifiers, state types, errors, event envelopes, actions, and module contracts available as typed domain concepts, so that later phases extend stable contracts rather than introduce ad-hoc strings.
6. As a module author, I want the Module contract to be static and composition-root registered, so that module ownership and trust stay explicit.
7. As an interaction developer, I want the Notch surface boundary to exist without panel behavior, so that F1/F2 can add lifecycle and AppKit behavior without changing the domain model.
8. As a security reviewer, I want external Event envelopes and Actions represented as contracts but no listener or executor implemented, so that F0 cannot expose an arbitrary execution or network path.
9. As a contributor, I want one selected formatter with a documented command, so that formatting is deterministic and does not depend on editor defaults.
10. As a reviewer, I want pull-request CI to resolve dependencies, format, build, test, validate documentation links, and scan changed content for accidental secrets, so that baseline regressions are visible before merge.
11. As a reviewer, I want CI to be the same high-level verification seam used by contributors, so that a green pull request is evidence of the documented clean-clone workflow.
12. As a documentation maintainer, I want setup instructions to name the exact commands introduced by the scaffold, so that provisional commands cannot be mistaken for supported ones.
13. As a project maintainer, I want the canonical glossary reflected in domain names and tests, so that Action, Event envelope, Module, Capability, Notch surface, and Detail view do not drift into conflicting terms.
14. As a security and performance reviewer, I want the initial scaffold to preserve the accepted ADR boundaries, so that dynamic plugins, LAN listeners, private APIs, speculative permissions, and unbounded producers cannot enter by convenience.
15. As a maintainer, I want at least one pure-domain test to pass in CI, so that F0 proves the package/test path rather than only compiling project metadata.
16. As a future F1+ developer, I want the foundation status and F0 evidence recorded when the gate closes, so that later phases know which guarantees are real rather than merely documented.

## Implementation Decisions

- Target macOS 14 as the minimum deployment target. The build-host toolchain is pinned independently of that deployment target, as established by ADR-0001.
- Use SwiftUI for scenes and views, and reserve AppKit ownership for the future Notch surface boundary, as established by ADR-0002. F0 does not create a panel or implement interaction behavior.
- Use one root Swift package with six targets: NotchDomain, NotchCore, NotchSurface, NotchUI, NotchActions, and NotchIPC. Use an Xcode application host for signing, entitlements, launch configuration, and composition. Modules are static and dynamic loading is excluded, as established by ADR-0003.
- Enable a Swift 6 strict-concurrency setting selected by the F0 scaffold and ensure the selected toolchain supports it. Record both the toolchain pin and CI image as project configuration.
- Select one formatter and check in its configuration. Do not make SwiftLint mandatory until a small, reviewed rule set is available, as established by ADR-0012.
- Define only the minimum pure-domain contracts necessary to name identities, state, errors, an Event envelope, Action identity/definition, and the Module contract. Contracts must use the canonical glossary vocabulary.
- Keep NotchDomain independent of SwiftUI, AppKit, networking, persistence, and process execution. Higher targets consume the domain package only in the permitted dependency direction.
- Add a macOS application host with no F1 menu-bar behavior, F2 Notch surface behavior, permission request, IPC listener, or real Module registration.
- CI runs on pull requests and is the authoritative composite verification seam. It resolves dependencies, runs the selected formatter, builds the package/application, runs tests, validates local Markdown links, and performs a changed-file secret check appropriate to the chosen CI platform.
- Replace setup-guide placeholders with the exact build, test, format, and CI-equivalent commands once the scaffold exists.
- Preserve ADR-0004 through ADR-0011 as constraints: no recovery UI implementation yet, no network listener, no raw external input, no arbitrary Action executor, no direct permission prompting, bounded-by-design resource defaults, built-in-display-only future scope, and public APIs only.

## Testing Decisions

- The single highest seam is the pull-request CI workflow. A good F0 test verifies observable repository behavior: a clean checkout can resolve, format, build, test, and validate docs. It must not assert Xcode project internals or implementation-specific file layout beyond the public package boundary.
- Add pure-domain unit tests for representative identifiers/contracts and invalid/rejected input where such validation exists. The first test demonstrates that domain logic has a real test target.
- Add an import-boundary assertion or equivalent repository check proving NotchDomain does not import SwiftUI or AppKit. This tests the architectural outcome, not a class’s internal implementation.
- Use the documented local commands as the prior art for CI; CI must invoke the same workflow at its highest practical seam. The existing testing strategy’s unit, package-integration, and pull-request-check model guides the checks.
- Test formatter configuration through its public command, not by asserting formatter configuration syntax.
- Test documentation through local Markdown-link validation. The check must fail for a broken local target and pass for the repository’s current documentation map.
- Treat signed application smoke testing, panel lifecycle QA, multi-display behavior, permission prompts, IPC authentication, performance profiling, and Module failure isolation as later-phase tests, not F0 substitutes.

## Out of Scope

- Menu-bar controls, AppCoordinator lifecycle, launch-at-login, Settings, Diagnostics, `NSPanel`, Notch surface transitions, Detail view navigation, shortcuts, and global event monitoring.
- Permission requests, Permission Coordinator implementation, Keychain secrets, persistence, EventBus, Presentation policy, IPC transport, `notchctl`, Action executors, and any network or LAN listener.
- DemoModule, Xiaozhi, media, clipboard, files, calendar, reminders, system controls, native audio, embedded tooling, IoT telemetry, and device control.
- Dynamic plugins, private APIs, privileged helpers, release signing/notarization, production privacy policy, F10 performance profiling, and F2/F10 manual QA.

## Further Notes

- The current documentation/ADR baseline is already accepted. This spec turns that baseline into implementation evidence; it does not reopen settled architecture decisions.
- The issue tracker status is `ready-for-agent`; implementation work may begin without additional design discovery. Any scope change to package topology, trust boundary, or platform policy requires the corresponding ADR review.
- F0 closes only after the spec’s clean-build, unit-test, import-boundary, CI, formatting, and documentation evidence is recorded. A documentation-only or local-only scaffold is insufficient.
