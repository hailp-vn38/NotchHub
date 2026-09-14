# 01: Native Notch surface baseline

**What to build:** Người dùng có thể dùng menu-bar Toggle NotchHub để mở và đóng một Notch surface collapsed có placeholder deterministic trên built-in display. `NotchPanelController` là chủ sở hữu duy nhất của native panel; state machine và `SurfaceCoordinator` cung cấp một seam cao để kiểm thử intent, state và panel effects mà không để App shell, view hay Module can thiệp trực tiếp vào panel.

**Blocked by:** None (can start immediately).

**Status:** resolved

- [x] Toggle từ App shell tạo, hiển thị và ẩn Notch surface qua đúng một owner, trong khi App shell vẫn usable nếu panel không tạo được.
- [x] State machine chỉ dùng các SurfaceState chuẩn và từ chối hoặc chuẩn hóa transition không khai báo.
- [x] Coordinator seam có fake adapters để test intent, state và panel effects mà không cần native panel thật.
- [x] Không có SwiftUI view, Module hoặc App shell object nào sở hữu hay thao tác native panel trực tiếp.

## Comments

- 2026-09-14: Hoàn tất baseline với `NotchPanelController` là sole `NSPanel` owner và seam `SurfaceCoordinator`; `./Scripts/verify.sh` pass (13 Swift tests, Xcode Debug build). Manual macOS panel QA thuộc ticket 06, chưa chạy ở ticket 01.
