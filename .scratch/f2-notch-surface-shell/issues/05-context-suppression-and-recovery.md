# 05: Context suppression and bounded recovery

**What to build:** Notch surface hành xử dự đoán được trên Spaces, full-screen, sleep/wake, lock/unlock và panel/display invalidation. Nó join Spaces khi eligible, suppress mặc định trong full-screen, và recovery hữu hạn trong khi menu-bar recovery path vẫn luôn hoạt động.

**Blocked by:** 01 — Native Notch surface baseline; 04 — Built-in display geometry.

**Status:** resolved

- [x] Space/full-screen policy đưa surface về collapsed hoặc suppressed nhất quán, không tự mở lại expanded sau khi context clear.
- [x] Sleep/wake và lock/unlock pause/revalidate native interaction an toàn, không tạo stuck panel hay duplicate work.
- [x] Recovery revalidate topology/geometry, thử tối đa 2 lần với backoff 250 ms, rồi hide và cung cấp warning/recovery path.
- [x] Debug overlay F2-only hiển thị state, geometry, interaction/window flags, suppression reason và recovery outcome mà không yêu cầu Action Registry.

## Answer

`SurfaceCoordinator` owns full-screen suppression, lifecycle pause/resume, and a two-attempt recovery loop with a 250 ms injected backoff. It preserves active full-screen suppression across sleep/wake and lock/unlock, restores a valid prior interaction state only when policy permits, then hides with a warning snapshot after permanent recovery failure. `NotchPanelController` observes display and Space context, owns native monitor teardown, and exposes a Debug-only F2 overlay through the menu bar without Action Registry wiring.

## Comments

- 2026-09-14: Hoàn tất và commit `7e8802b`. `swift test` pass (32 tests); formatter, composite verification, và Debug macOS build pass. Manual QA physical-notch cho Space/full-screen/sleep-wake/lock-unlock chưa chạy.
