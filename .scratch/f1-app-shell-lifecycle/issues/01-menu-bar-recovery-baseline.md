# 01: Menu-bar recovery baseline

**What to build:** Người dùng có thể chạy NotchHub như một App shell menu-bar-first và luôn có đường recovery độc lập với Notch surface. Menu cung cấp Toggle Notch Surface, Show Demo State, Restart App Shell và Quit; hai intent thuộc pha sau trả trạng thái unavailable rõ ràng, còn restart/quit chỉ quản lý tài nguyên F1. Lặp lại startup trong cùng tiến trình không tạo menu resource hoặc lifecycle state trùng.

**Blocked by:** None (can start immediately).

**Status:** resolved

- [x] App shell có một `AppCoordinator` sở hữu startup, restart và teardown F1, với startup idempotent.
- [x] Menu bar luôn reachable và các intent surface/demo không tạo `NSPanel`, ModuleRuntime, IPC hay permission request.
- [x] Restart App Shell và Quit dừng tài nguyên F1 theo ownership; không được đặt tên hay hoạt động như ModuleRuntime restart.
- [x] Test ở coordinator seam chứng minh observable menu outcomes, startup lặp, restart và teardown mà không phụ thuộc chi tiết SwiftUI/AppKit.
