# 04: Hover interaction session and holds

**What to build:** Người dùng nhận được hover mở sau 300 ms và close grace 100 ms không flicker, nhưng Surface không đóng trong keyboard focus, popover, drag, confirmation hoặc accessibility interaction; click/shortcut-origin vẫn tuân inactivity policy hiện hành.

**Blocked by:** 01 — Coordinator admission contract; 03 — Native shape-aware click-through.

**Status:** ready-for-human

- [x] Hover-origin expansion chỉ close sau 100 ms khi pointer outside và không có active Surface interaction hold; re-entry hủy close đang chờ.
- [x] Coordinator sở hữu typed lease registry theo interaction-session generation; stale release vô hại và mọi departure từ expanded clear session, holds, timer close.
- [x] Final hold release chỉ restart grace khi pointer vẫn outside; click/shortcut origin tiếp tục bounded auto-collapse thay vì hover-close.
- [x] Deterministic scheduler tests cover dwell, grace, re-entry, stale task, mỗi hold kind và recovery/suppression invalidation.

## Implementation Notes

- Implemented in commit `34f1d0b` (`feat(surface): add hover interaction session holds`).
- Added `SurfaceInteractionHoldKind` and generation-scoped `SurfaceInteractionHoldLease` to `SurfaceCoordinator`.
- `swift test` passes all 43 tests; `swift build` and `git diff --check` pass.
- Manual macOS lifecycle/accessibility verification remains for ticket 05; production call-sites acquire/release holds there.
