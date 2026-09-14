# 03: Explicit Detail view route

**What to build:** Người dùng có thể mở một Detail view placeholder từ expanded Notch surface để xem nội dung dài, và lặp lại yêu cầu sẽ focus/tái sử dụng cửa sổ thay vì tạo panel hoặc cửa sổ không giới hạn. Detail view giữ đúng vai trò cửa sổ riêng, không phải Notch surface state.

**Blocked by:** 01 — Native Notch surface baseline.

**Status:** resolved

- [x] Chỉ explicit user-navigation intent từ placeholder expanded content mới mở Detail view.
- [x] Repeated request tái sử dụng/focus Detail view phù hợp; close/back không làm hỏng state của Notch surface.
- [x] Detail view có focus, Escape/back và lifecycle riêng; surface không bao giờ có detail state.
- [x] Automated coordinator tests xác nhận route, reuse và invariant non-detail state.

## Answer

Implemented `DetailWindowCoordinator` as the owner of a separate native Detail window. The expanded placeholder emits a typed `DetailNavigationRequest` only from its explicit `View detail` button; opening/focusing and closing the Detail window do not change `SurfaceSnapshot`. Coordinator tests cover route, repeated focus/reuse, user close/back lifecycle, and the surface-state invariant. Verified with `swift test` (21 tests) and the Debug macOS Xcode build.
