# 02: Bounded surface interaction

**What to build:** Người dùng có thể mở Notch surface bằng hover hoặc click, thoát an toàn bằng Escape/click-outside/timeout, và không bị panel thụ động chặn menu bar hay lấy focus. F2 dùng hover 150 ms, margin hit-test 8 pt, auto-collapse 3 giây và F2-only menu/debug control; không đưa Settings, shortcut hay Action Registry vào sớm.

**Blocked by:** 01 — Native Notch surface baseline.

**Status:** resolved

- [x] Hover, click, Escape, click-outside và timeout dẫn đến các SurfaceState đã công bố; tương tác thực sự reset timeout.
- [x] Hidden/suppressed không có pointer target; collapsed chỉ bắt input trong visible region cộng 8 pt và không có transparent overlay toàn màn hình.
- [x] Compact/collapsed không cướp focus; user-triggered expansion có focus keyboard/VoiceOver dự đoán được.
- [x] Các default F2 có test seam nhưng không persist hoặc xuất hiện như Settings/shortcut/Action behavior.

## Comments

- 2026-09-14: Hoàn tất interaction slice với hover 150 ms, auto-collapse 3 giây, click/Escape/click-outside, timer reset qua `SurfaceCoordinator` scheduler seam và native panel event monitors. `swift test`, lint, domain-boundary và Debug build pass; manual macOS QA thuộc ticket 06, chưa chạy ở ticket 02.
