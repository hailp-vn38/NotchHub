# 04: Built-in display geometry

**What to build:** Notch surface neo đúng vào physical notch của built-in MacBook display hoặc safe top-center fallback, và giữ geometry an toàn khi display topology hay scale thay đổi. Khi built-in display không khả dụng, surface hide/suppress thay vì xuất hiện tùy tiện trên external display.

**Blocked by:** 01 — Native Notch surface baseline.

**Status:** resolved

- [x] Built-in display được chọn mà không giả định main screen; physical-notch và no-notch fallback đều tạo frame an toàn.
- [x] Scale/resolution và attach/detach yêu cầu revalidation/reframe không để frame off-screen hoặc chồng menu bar.
- [x] Clamshell/built-in-unavailable dẫn đến hide hoặc suppress, không phải multi-display hosting.
- [x] Geometry tests kiểm tra invariants bằng synthetic topology, gồm invalid bounds và fallback, không phụ thuộc pixel hard-code.

## Answer

`NotchSurfaceGeometry` chọn duy nhất display built-in, neo ngang theo physical notch khi AppKit cung cấp auxiliary safe areas, và đặt frame trong `visibleFrame` để tránh menu bar. Không có built-in hợp lệ sẽ trả `nil`; `NotchPanelController` vì vậy không tạo panel mới hoặc order out panel hiện có khi topology đổi. `NSApplication.didChangeScreenParametersNotification` kích hoạt revalidation/reframe.

## Comments

- 2026-09-14: Hoàn tất geometry policy và native revalidation. `swift test --filter NotchPackageSpineTests` pass (25 tests); full verification được chạy trước commit.
