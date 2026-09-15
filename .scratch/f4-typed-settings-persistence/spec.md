# F4 Typed Settings and Persistence

**Status:** ready-for-agent
**Phase:** F4
**Owner:** Architecture / Security / Quality

## Problem Statement

NotchHub có Settings shell và các giá trị interaction/appearance đang chỉ tồn tại trong phiên, nên
người dùng không có cấu hình bền vững, an toàn khi nâng cấp, hay cơ chế recovery rõ ràng nếu dữ
liệu hỏng. Thiết kế trước đây còn mơ hồ về backend, import semantics, future schema, ranh giới
secret, và retention của dữ liệu lỗi. F4 cần biến các preference nền tảng đã có owner thành một
**Settings snapshot** typed, versioned và recoverable mà không kéo Permission, Action, Module,
hay Diagnostics runtime vào sớm.

## Solution

Xây dựng một **Settings store** làm boundary typed duy nhất cho snapshot F4 v1. Snapshot được lưu
trong một file versioned tại Application Support bằng atomic replacement; secrets ở Keychain và
không bao giờ là một phần của snapshot. F4 v1 chỉ sở hữu Appearance và Notch Behavior: theme,
Reduced Motion override, hover delay và auto-collapse timeout. UI gửi typed intents qua projection
của Settings store; runtime nhận projection hợp lệ, không đọc raw persistence API.

Import validate toàn bộ F4-owned snapshot trước khi atomically replace. Corrupt current-schema data
được quarantine có giới hạn trước khi defaults an toàn thay thế nó; schema mới hơn ứng dụng chuyển
sang read-only recovery và không bị ghi đè. Mọi recovery được thể hiện qua **Settings recovery
outcome** trong phiên; F9 mới có thể persist diagnostics đã sanitize về sau.

## User Stories

1. As a NotchHub user, I want my supported appearance preferences to survive relaunch, so that the app feels consistent.
2. As a user, I want System, Light, or Dark theme choices, so that the Settings appearance follows my preference.
3. As a motion-sensitive user, I want to follow system Reduced Motion or request reduced motion, so that feedback remains comfortable without overriding a stricter system preference.
4. As a Notch surface user, I want a selectable hover delay of 150, 300, or 500 ms, so that incidental pointer movement is balanced against responsiveness.
5. As a Notch surface user, I want a selectable auto-collapse timeout of 2, 3, or 5 seconds, so that the surface clears itself at a pace I understand.
6. As a user, I want the existing safe defaults of 300 ms hover and 3 seconds auto-collapse, so that an upgrade changes no interaction behavior until I opt in.
7. As a user in a full-screen app, I want the Surface to remain suppressed, so that F4 never introduces an intrusive full-screen preference without native validation.
8. As a user, I want the Notch surface to remain always on when eligible and start collapsed, so that Settings cannot accidentally disable the recovery surface or change lifecycle policy.
9. As a user, I want invalid settings values rejected before they become active, so that a malformed value cannot make the Surface unsafe or unreadable.
10. As a user, I want safe setting changes applied to runtime behavior without a relaunch, so that supported preferences take effect predictably.
11. As a user, I want a failed write to preserve my last known-good configuration, so that storage failure does not silently erase a working setup.
12. As a user updating NotchHub, I want older settings migrated deterministically, so that a release does not discard my valid preferences.
13. As a user opening a newer settings snapshot with an older app, I want read-only recovery and an update/reset route, so that the older app never overwrites data it cannot understand.
14. As a user whose current settings become corrupt, I want NotchHub to start with safe defaults and explain recovery, so that configuration damage never blocks access to the app.
15. As a user, I want corrupt settings quarantined before defaults replace them, so that recovery does not silently destroy the original data.
16. As a privacy-conscious user, I want quarantine capped at three 1 MiB files (3 MiB total), so that failure recovery cannot become an unbounded local archive.
17. As a user, I want normal reset to affect non-secret F4 settings only, so that credentials are never removed by surprise.
18. As a user, I want export to contain only sanitized non-secret settings, so that sharing a configuration cannot reveal credentials or private content.
19. As a user, I want import to validate the entire F4 snapshot before replacing it atomically, so that partial or invalid configuration never leaks into my live state.
20. As a user, I want an invalid import to leave the active snapshot unchanged, so that I can recover without manually rebuilding settings.
21. As a keyboard and VoiceOver user, I want saved, rejected, and recovery states exposed through the Settings UI, so that persistence feedback is usable without relying on F9 Diagnostics.
22. As a future shortcut, module, or diagnostics author, I want F4 not to create placeholder values for my feature, so that each owner introduces its own schema and migration with its behavior.
23. As a security reviewer, I want secrets kept out of Settings snapshots, fixtures, exports, logs, and ordinary reset, so that the storage boundary is auditable.
24. As a quality engineer, I want deterministic migration, corruption, atomic-write, import, and recovery tests, so that a green test run represents observable settings behavior rather than persistence internals.

## Implementation Decisions

- Use the glossary terms **Setting**, **Settings store**, **Settings snapshot**, **Settings recovery outcome**, and **Secret**. Do not call the Settings shell a backend or treat session-only UI state as a Setting.
- Respect ADR-0014: Notch surface eligibility and collapsed startup state are invariants, not F4 controls. Full-screen suppression remains an invariant until another safe policy has native QA.
- Respect ADR-0015: one versioned Application Support snapshot is the ordinary-settings backend; it is atomically replaced only after validation. Keychain remains the only secret boundary.
- The F4 v1 snapshot contains Appearance theme, Reduced Motion override, Notch Behavior hover delay, and Notch Behavior auto-collapse timeout. Its defaults are System, Follow System, 300 ms, and 3 seconds respectively.
- Theme accepts only System, Light, and Dark. Reduced Motion accepts Follow System or Reduce Motion and never forces motion when macOS requests reduction. Hover accepts only 150, 300, or 500 ms; auto-collapse accepts only 2, 3, or 5 seconds.
- General owns configuration entry points such as import, export, reset, and recovery presentation, but F4 creates no General preference value. Launch-at-login, material/opacity, layout density, indicator style, shortcut, module, and diagnostics configuration are deferred to their owning validated phases.
- `SettingsStore` is the highest settings seam and the sole authority for loading, validating, migrating, mutating, persisting, resetting, importing, exporting, and publishing a Settings recovery outcome. Views use a projection or view model over this boundary and never access raw persistence or Keychain APIs.
- Apply runtime-safe changes only through existing coordinator seams: the Settings store publishes a typed valid projection, and the existing app/surface coordinators apply it. No Settings view owns `NSPanel`, `SurfaceState`, timers, or a second persisted copy.
- Migration is deterministic, ordered, offline, and fixture-backed. A failed migration never mutates active settings partially. An unknown future schema preserves its bytes and enters read-only recovery until update or explicitly confirmed reset.
- A corrupt or invalid current-schema snapshot moves to timestamped local quarantine before safe defaults are atomically written. Quarantine is never active, importable, or exportable; it keeps at most three files, each at most 1 MiB, for a 3 MiB total, deleting the oldest before admitting another file.
- Normal reset targets non-secret F4 settings. Credential deletion remains a distinct confirmed secret flow and is never bundled with normal reset.
- Import decodes and validates the complete F4-owned snapshot, summarizes changes where practical, and atomically replaces Appearance and Notch Behavior only after validation. It neither merges individual fields nor changes secrets or future-phase scopes.
- F4 presents typed saved/error/recovery feedback in the current Settings session. It does not construct an F9 Diagnostics store; F9 may later persist a sanitized diagnostics record.
- F4 implementation and phase closure remain blocked on the recorded F2 physical macOS manual gate. Documentation and deterministic fixtures may be prepared beforehand, but no evidence may represent F4 as executed before that prerequisite is met.

## Testing Decisions

- Test external outcomes at the `SettingsStore` boundary: loaded snapshot/projection, validated mutation result, runtime projection request, persisted replacement outcome, import/export result, reset scope, and Settings recovery outcome. Do not test raw serializer helpers, temporary-file names, or view layout internals as primary behavior.
- Introduce one injectable `SettingsBackend` adapter beneath the Settings store for deterministic file, write-failure, interrupted-replacement, corrupt-data, future-schema, and quarantine scenarios. It is a test double boundary, not a second public state owner.
- Use existing `SettingsShellModel` tests as UI prior art: assert settings routes express saved, rejected, and recovery states and that UI has no raw storage side effects. Keep persistence behavior in Settings store tests rather than per-view tests.
- Use the existing injected `SurfaceInteractionConfiguration` and `SurfaceCoordinator` seam as prior art for applying validated hover/timeout changes. Assert observed interaction configuration, not timer implementation details or AppKit calls.
- Cover every v1 default and accepted/rejected discrete value. Confirm a rejected mutation leaves the last known-good projection and snapshot unchanged.
- Cover every released migration with before/after fixtures, migration ordering, validation after migration, and failure without partial activation or network access.
- Cover malformed, truncated, and invalid current-schema snapshots: they quarantine original bytes, retain the defined 3-file/3 MiB rotation, write safe defaults atomically, and publish a Settings recovery outcome without blocking startup.
- Cover an unknown newer schema: it returns read-only recovery, preserves original bytes, writes no defaults, and offers no silent reinterpretation.
- Cover write failure and interrupted atomic replacement: the active configuration remains last-known-good and the user-facing projection reports recoverable failure.
- Cover sanitized export and import: exports exclude secrets, raw user content, raw payloads, sensitive paths, and quarantine; invalid import changes nothing; valid import atomically replaces only F4-owned state; import never overwrites secrets.
- Cover normal reset versus explicit credential deletion boundary, including that normal reset cannot delete secrets.
- Run existing repository format, domain-boundary, secret, package-test, macOS build, and Markdown checks. Record F4 results in the evidence template; do not substitute a build or mock for the required manual macOS relaunch/recovery/import UX evidence.

## Out of Scope

- Completing F2 physical-notch manual QA; it is a prerequisite, not part of F4 implementation.
- Launch-at-login preference UI, general startup preferences, material/opacity, layout density, animation intensity, and collapsed indicator style.
- Any full-screen policy other than existing suppression.
- Permission requests or status persistence, Action Registry behavior, shortcut capture/bindings, module lifecycle/settings payloads, local IPC configuration, and F9 Diagnostics persistence.
- Persisting transcripts, clipboard, file, calendar, screen, camera, audio, or any other user content.
- Secret import/export, ordinary credential reset, raw-log viewing, unbounded history, cloud sync, LAN/API control, or a new database.
- Creating a separate settings state machine, UI-owned persistence, direct `UserDefaults`/Keychain access from views, or ownership of native `NSPanel` operations.

## Further Notes

- The current Settings shell is presentation-only; it must remain honest until the Settings store is wired.
- The primary seam is the Settings store. `SettingsBackend` is injected only to make failure and filesystem behavior deterministic; runtime application stays at existing coordinator seams.
- F4 has a prepared evidence template, but no implementation/manual evidence is claimed. The physical F2 native gate remains pending and is an explicit execution dependency.
