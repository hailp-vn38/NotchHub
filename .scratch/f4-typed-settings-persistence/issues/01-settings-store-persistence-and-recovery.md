# 01: F4 Settings store, persistence và recovery

**What to build:** Người dùng có thể thay đổi các Setting F4 v1 trong Settings và nhận một hành vi hoàn chỉnh: theme, Reduced Motion override, hover delay, và auto-collapse timeout được validate, áp dụng an toàn vào runtime, tồn tại sau relaunch, và không ảnh hưởng full-screen suppression invariant. Khi snapshot cũ, corrupt, hoặc mới hơn app, NotchHub migrate/recover một cách rõ ràng thay vì mất settings hoặc ghi đè dữ liệu không hiểu được.

**Blocked by:** F2 ticket 06 — F2 end-to-end verification and evidence (external prerequisite).

**Status:** resolved

- [x] Settings store là boundary typed duy nhất cho F4 v1 Appearance/Notch Behavior snapshot; Settings UI không đọc raw persistence API hoặc Keychain.
- [x] Theme chỉ nhận System/Light/Dark; Reduced Motion chỉ Follow System/Reduce Motion; hover delay chỉ 150/300/500 ms; auto-collapse chỉ 2/3/5 seconds. Defaults giữ System, Follow System, 300 ms, và 3 seconds.
- [x] Setting hợp lệ được persist bằng versioned Application Support snapshot với atomic replacement, áp dụng qua coordinator seam, và survive app relaunch; invalid mutation giữ last-known-good state.
- [x] Full-screen suppression, always-on eligibility, và collapsed startup state vẫn là invariants, không xuất hiện như F4 preference.
- [x] Migration fixture của mọi schema đã phát hành chạy deterministic, offline và không partial-mutate active snapshot.
- [x] Corrupt/invalid current-schema snapshot được quarantine trước khi safe defaults được ghi atomically; quarantine giữ tối đa ba file 1 MiB, tổng 3 MiB, xoay vòng file cũ nhất, không active/importable/exportable.
- [x] Unknown future schema giữ nguyên bytes, trả về read-only Settings recovery outcome, và không tự ghi defaults.
- [x] Failed write/interrupted replacement giữ active last-known-good snapshot và đưa lỗi/recovery typed tới Settings session; F4 không tạo F9 Diagnostics persistence.
- [x] Tests chứng minh external outcomes tại Settings store và coordinator seams: validation, relaunch persistence, migration, corruption/quarantine, future schema, atomic-write failure, và recovery presentation.

## Comments

2026-09-15 — Automated F4 implementation and build evidence complete. Physical macOS relaunch,
recovery, import/export, and reset UX scenarios remain ready for human confirmation.

2026-09-15 — Maintainer confirmed the applicable native F4 behavior as complete. Ticket 01 is
resolved; the separate F2 evidence record remains independently owned.
