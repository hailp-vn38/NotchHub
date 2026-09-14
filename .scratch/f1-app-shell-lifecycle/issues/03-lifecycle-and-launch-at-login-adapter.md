# 03: Lifecycle and launch-at-login adapter

**What to build:** App shell xử lý an toàn activation, deactivation, sleep, wake, lock, unlock và termination mà không lộ UI ngoài ý muốn. Launch-at-login có abstraction fakeable với production adapter dùng `SMAppService`, nhưng F1 chưa cung cấp toggle, persistence hay hidden helper.

**Blocked by:** 01 — Menu-bar recovery baseline.

**Status:** resolved

- [x] Lifecycle event chỉ tác động tài nguyên F1 và giữ menu bar usable; không tạo panel, module, IPC hoặc permission prompt.
- [x] Teardown theo thứ tự ownership, không để task/observer F1 treo sau Quit.
- [x] Launch-at-login adapter có thể kiểm thử bằng fake mà không thay đổi đăng ký login item thật của máy.
- [x] Test tại coordinator seam bao phủ activation/deactivation, sleep/wake, termination và các outcome của adapter.

## Comments

- Hoàn thành 2026-09-14: `AppCoordinator` nhận lifecycle observer và launch-at-login controller qua seam có thể fake. App target quan sát activation/deactivation, sleep/wake, session lock/unlock và termination; observer được gỡ theo thứ tự ngược khi teardown. Production launch-at-login chỉ đọc `SMAppService.mainApp.status`, không đăng ký/hủy login item. `swift test`, Swift-format, Xcode macOS build và `./Scripts/verify.sh` đều pass; manual macOS evidence vẫn thuộc ticket 04.
