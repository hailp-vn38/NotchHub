# 03: Lifecycle and launch-at-login adapter

**What to build:** App shell xử lý an toàn activation, deactivation, sleep, wake, lock, unlock và termination mà không lộ UI ngoài ý muốn. Launch-at-login có abstraction fakeable với production adapter dùng `SMAppService`, nhưng F1 chưa cung cấp toggle, persistence hay hidden helper.

**Blocked by:** 01 — Menu-bar recovery baseline.

**Status:** ready-for-agent

- [ ] Lifecycle event chỉ tác động tài nguyên F1 và giữ menu bar usable; không tạo panel, module, IPC hoặc permission prompt.
- [ ] Teardown theo thứ tự ownership, không để task/observer F1 treo sau Quit.
- [ ] Launch-at-login adapter có thể kiểm thử bằng fake mà không thay đổi đăng ký login item thật của máy.
- [ ] Test tại coordinator seam bao phủ activation/deactivation, sleep/wake, termination và các outcome của adapter.
