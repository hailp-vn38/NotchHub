# 02: F4 import/export/reset và evidence gate

**What to build:** Người dùng có thể di chuyển hoặc xóa cấu hình F4 non-secret một cách an toàn: export chỉ chứa snapshot đã sanitize; import validate toàn bộ rồi atomically replace đúng F4-owned state; reset thường không đụng credentials. Reviewer có evidence tự động và macOS rõ ràng cho các flow này, recovery, và relaunch trước khi F4 được đóng.

**Blocked by:** 01 — F4 Settings store, persistence và recovery; F2 ticket 06 — F2 end-to-end verification and evidence (external prerequisite).

**Status:** ready-for-human

- [x] Export chứa schema và F4 non-secret Appearance/Notch Behavior settings, nhưng loại trừ Keychain values, credentials, tokens, raw user content, raw payloads, sensitive paths, và quarantine.
- [x] Import decode/validate complete F4 snapshot, tóm tắt thay đổi khi phù hợp, rồi atomically replace Appearance/Notch Behavior; không merge individual fields, future-phase scopes, hoặc secrets.
- [x] Invalid import, malformed input, hay persistence failure không thay đổi active last-known-good snapshot và trả về typed user-facing outcome.
- [x] Normal reset chỉ xóa non-secret F4 settings; credential deletion là flow xác nhận riêng và không được gộp vào reset thông thường.
- [x] Tests bao phủ sanitized export, valid/invalid import, secret exclusion, reset boundary, và recoverable outcomes thay vì serializer hoặc UI-layout internals.
- [x] Repository verification, F4 evidence, và documentation privacy/retention được cập nhật với kết quả thật; build/mock không được tuyên bố là native macOS proof.
- [ ] Manual macOS QA ghi nhận relaunch persistence, recovery notice, import/export scope, normal reset, và credential-deletion separation; mọi scenario unrun phải được ghi rõ.

## Comments

2026-09-15 — `./Scripts/verify.sh` PASS: format/lint, boundary and secret checks (including their
intentional negative fixtures), package build/test (65 tests), Debug macOS build, and Markdown checks.
Manual macOS relaunch, recovery notice, import/export scope, normal reset, and the future
Secret-owner credential-deletion separation remain unrun; this ticket is ready for human
verification, not phase closure.
