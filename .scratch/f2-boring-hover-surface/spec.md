# Boring-inspired animated Notch Surface

**Status:** complete
**Phase:** F2 follow-up
**Owner:** Platform / Architecture / Design / Quality

## Problem Statement

NotchHub F2 vẫn dùng placeholder capsule có text, SwiftUI host bị thay theo state, hover mặc định 150 ms, và native panel nhận input theo hình chữ nhật. Người dùng chưa có một Notch surface morph liên tục, shape-aware click-through, hoặc cách phân biệt topology thiếu diện tích với native panel failure. Animation đẹp cũng không đủ nếu Surface cướp focus, làm VoiceOver mắc kẹt, đóng giữa lúc điều khiển đang active, hay chặn ứng dụng khác qua transparent region.

## Solution

Xây dựng một Notch surface clean-room lấy cảm hứng từ Boring Notch: persistent SwiftUI hierarchy morph từ collapsed geometry theo display sang visible expanded Surface cố định 640 × 190 pt trong host 640 × 210 pt. SurfaceCoordinator giữ snapshot, capability admission, interaction session và timer authoritative; NotchPanelController giữ toàn bộ NSPanel/native input. Thiết kế giữ built-in-display-first, recovery, Detail view, focus và accessibility contract của NotchHub.

## User Stories

1. As a MacBook user, I want collapsed geometry to follow my physical notch when valid, so that the resting Surface feels attached to the display.
2. As a user without physical-notch geometry, I want a safe minimal top-center fallback, so that the Surface remains predictable.
3. As a user, I want no persistent product text in collapsed state, so that it stays calm at rest.
4. As a user, I want hover to wait 300 ms, so that incidental cursor passes do not expand the Surface.
5. As a user, I want collapsed Surface expansion to require hover dwell while compact content remains clickable, so that an incidental collapsed click cannot replay the opening animation.
6. As a keyboard user, I want menu and shortcut paths to remain available, so that pointer precision is optional.
7. As a user, I want expanded visual geometry fixed at 640 × 190 pt, so that layout is predictable.
8. As a user, I want a shoulder-inset notch shape with larger bottom corners, so that it does not resemble a rounded rectangle.
9. As a user, I want continuous geometry/radius morphing, so that opening never jumps between unrelated views.
10. As a user, I want content to enter from the top with scale and opacity, so that motion follows the notch attachment.
11. As a user with Reduce Motion enabled, I want short non-spring feedback, so that state remains understandable without excess motion.
12. As a hover-open user, I want 100 ms exit grace, so that minor pointer slips do not immediately collapse the Surface.
13. As a keyboard, popover, drag, confirmation, or assistive-technology user, I want active interaction to hold the Surface open, so that closing does not interrupt me.
14. As a user who re-enters during grace, I want pending collapse canceled, so that the panel does not flicker.
15. As a click-inside/shortcut user, I want the bounded inactivity policy preserved, so that deliberate interaction is not treated as transient hover.
16. As a user on an undersized valid topology, I want Surface to remain collapsed or compact rather than scale/crop, so that controls stay honest.
17. As a hover user on an unsupported topology, I want no automatic Detail route, so that passive movement does not navigate me.
18. As a compact-click/keyboard user on an unsupported topology, I want bounded accessible feedback and an explicit Detail path where appropriate, so that access remains possible.
19. As a user changing displays or resolution, I want expanded availability refreshed for the current topology, so that stale geometry cannot decide a new interaction.
20. As a user, I want invalid topology and native panel failure to recover safely, so that they remain distinct from ordinary capacity limits.
21. As a user, I want transparent corners and shadow envelope to click through, so that NotchHub does not block other macOS UI.
22. As a user returning to a click-through shape, I want native hit testing to reactivate, so that Surface remains usable.
23. As a user dragging a native control, I want event ownership retained during the gesture, so that click-through cannot break it.
24. As a user, I want Escape and click-outside to remain safe exits, so that interaction is reversible.
25. As a keyboard and VoiceOver user, I want predictable deliberate focus and safe restoration on collapse, so that invisible panels never trap me.
26. As a developer, I want Diagnostics to distinguish admission rejection from recovery, so that topology limits are not misdiagnosed.
27. As a quality engineer, I want deterministic coordinator tests and real macOS evidence, so that mocks are not mistaken for window-server proof.
28. As a future Module author, I want this primitive to remain module-agnostic, so that feature-specific state does not enter Surface core.

## Implementation Decisions

- Preserve the glossary terms **Notch surface**, **Detail view**, **Surface interaction hold**, and **Surface interaction session**. Detail view remains a separate route, never a SurfaceState.
- Use a clean-room custom notch shape. Closed radii are top shoulder 6 and bottom corner 14; expanded radii are 19 and 24. The same shape defines rendering, clipping, and SwiftUI interaction; do not use a capsule, ordinary rounded rectangle, or copied upstream path.
- Keep one persistent SwiftUI presentation hierarchy with SwiftUI shadow/top seam. It renders a latest snapshot projection and transient geometry only; it must not own a separate mutable SurfaceState.
- SurfaceCoordinator.snapshot is the sole authoritative presentation state. Native apply failure reports back to it for recovery; presentation never self-rolls back.
- NotchPanelController remains sole NSPanel owner for host, frame/order, native event monitoring, click-through, and mouse capture.
- Derive collapsed size from valid physical notch plus tolerance, otherwise use safe fallback. Expanded visual is fixed 640 × 190 pt and host is fixed 640 × 210 pt.
- Validate fixed-host admission before expanded transition. Never scale/crop or choose an alternative expanded size. Valid but undersized topology is capability unavailable, not recovering.
- Version expandedAvailability by topologyRevision. Invalidate before revalidation. Keep rejection feedback transient to request/topology revision; retain historical rejection only as bounded Diagnostics events.
- Hover delay is 300 ms. Hover-origin exit uses 100 ms grace only when pointer is outside and the Surface interaction session has no active hold. Click/shortcut origin retains bounded inactivity.
- SurfaceCoordinator owns typed, generation-scoped interaction-hold leases. Keyboard focus, popover, drag/control tracking, confirmation, and accessibility interaction acquire/release leases. Leaving expanded invalidates session, clears holds, cancels close work, and makes stale release harmless.
- A panel-owned SurfacePointerMonitor observes local/global pointer movement, compares screen-space pointer to visible shape, and controls ignoresMouseEvents independently of SwiftUI hover. It recomputes synchronously after geometry/state/capture changes; an active native mouse-capture lease is the only exception.
- Preserve F2 recovery, suppression, built-in-display-first, Detail route, Escape, click-outside, and focus policy. Respect Reduce Motion, VoiceOver, focus restoration, and no-input hidden/collapsed/suppressed hosts as completion requirements.
- Follow ADR-0002, ADR-0010, ADR-0011, ADR-0012, and ADR-0013. Do not copy Boring Notch's permanently large collapsed host, private APIs, or feature-specific state.

## Testing Decisions

- Use the existing AppKit-free SurfaceCoordinator with injected recording panel, scheduler, topology/admission, input, and lifecycle adapters as the highest primary seam. Assert intent, snapshot, requested effect, capability result, and Diagnostics event—not view internals or raw AppKit calls.
- Extend existing deterministic scheduler/recording panel prior art for hover dwell, grace, re-entry, click-origin inactivity, stale task cancellation, state rejection, recovery, and focus intents.
- Test typed interaction-hold leases: holds defer hover-close; final release restarts grace only if pointer remains outside; stale releases do nothing; every exit from expanded clears session state.
- Test synthetic physical-notch, no-notch, invalid, undersized, resolution-changed, and scale-changed topology. Assert fixed-size admission and revision freshness; distinguish unsupported capacity from invalid topology/native failure.
- Test the native-controller adapter contract for transparent corners, shadow envelope, pointer re-entry after ignored events, synchronous recomputation, and capture leases; do not test monitor internals.
- Require physical-notch manual QA for shape/morph, size, grace/re-entry, click-through, focus restoration, Escape, VoiceOver, Reduce Motion, full-screen, Space, sleep/wake, lock/unlock, display invalidation, and rapid reopen during host settle.
- Exercise explicit rejected admission on undersized safe geometry: hover stays silent, click/keyboard get accessible bounded feedback, Diagnostics records it, and recovery does not start.
- A build, preview, adapter unit test, or accessibility tree alone is not proof of native window-server behavior; record real hardware/topology evidence separately.

## Out of Scope

- Media, shelf, Xiaozhi, battery, sharing, Module runtime/content, Actions, IPC, Settings persistence, and real integration UI.
- User-configurable hover delay, expanded size, radius/theme controls, or Settings work.
- Arbitrary external-display placement, private APIs, event taps, privileged helpers, or new permission/entitlement requirements.
- Replacing F2 recovery/full-screen behavior with Boring Notch policy, retaining a large transparent host while collapsed, or copying upstream implementation.
- Compact-content redesign beyond using the persistent presentation infrastructure.

## Further Notes

- Current source still has 150 ms hover, state-specific hosts, clipped preferred geometry, and rectangular native hit testing; these are migration targets, not completed behavior.
- The implementation plan and ADR-0013 are the reviewed authority for admission, state ownership, interaction holds, and native click-through.
- The chosen seams reflect the confirmed design: coordinator tests cover policy, while one panel-owned native pointer adapter covers AppKit-specific hit testing. No per-view seam is introduced.

## Comments

- 2026-09-15: Đóng phase theo yêu cầu người dùng. Automated verification đã được ghi nhận; native visual/input/accessibility/lifecycle QA chưa chạy vẫn được giữ nguyên trong evidence và checklist ticket.
