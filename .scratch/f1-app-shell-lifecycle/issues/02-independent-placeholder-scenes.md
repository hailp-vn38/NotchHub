# 02: Independent placeholder scenes

**What to build:** Người dùng mở được Settings và Diagnostics từ menu bar ngay cả khi Notch surface không tồn tại. Mỗi scene là placeholder được gắn nhãn rõ giới hạn F1, có thể mở độc lập với scene còn lại, và không làm người dùng hiểu nhầm rằng Settings persistence hay operational Diagnostics đã tồn tại.

**Blocked by:** 01 — Menu-bar recovery baseline.

**Status:** resolved

- [x] Menu mở được hai placeholder scene độc lập cho Settings và Diagnostics.
- [x] Mỗi scene công bố giới hạn F1 và không khởi tạo persistence, `NSPanel`, ModuleRuntime, IPC listener hay Diagnostics store.
- [x] Lỗi/đóng một scene không làm menu bar hoặc scene kia mất reachable.
- [x] Test ở coordinator/scene-presentation seam xác minh hành vi mở độc lập thay vì cấu trúc `body` của SwiftUI.

## Comments

- Implemented 2026-09-14: `AppCoordinator` routes Settings and Diagnostics through an injected scene-presenter seam. The SwiftUI App shell opens separate `WindowGroup` placeholder scenes; both disclose the F1 boundary. `swift test`, `xcodebuild`, and `./Scripts/verify.sh` passed.
