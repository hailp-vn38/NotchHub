# 04: F1 verification and evidence gate

**What to build:** Nhóm có bằng chứng đáng tin cậy để quyết định F1 hoàn thành: test tự động đi qua composite verification seam và manual macOS QA chứng minh App shell vẫn usable trong các lifecycle scenario. Evidence phân biệt rõ kết quả đã pass, scenario bị bỏ qua và phần ngoài phạm vi F1.

**Blocked by:** 02 — Independent placeholder scenes; 03 — Lifecycle and launch-at-login adapter.

**Status:** ready-for-human

- [x] Composite verification hiện có chạy xanh sau thay đổi F1, bao gồm build, test, documentation checks và secret scan.
- [x] Automated coordinator/menu/lifecycle tests pass và chỉ kiểm tra observable behavior.
- [ ] Manual macOS evidence ghi Mac model, macOS/Xcode version, ngày, tester và kết quả cold launch, scene reachability, unavailable intents, restart, quit/relaunch, sleep/wake, activation/deactivation. Còn thiếu sleep/wake thực tế do cần human-controlled wake check.
- [x] F1 evidence không đánh dấu complete khi một scenario áp dụng còn pending hoặc không có lý do/evidence.

## Comments

- 2026-09-14: Đã chạy `VERIFY_BASE_REF=HEAD^ ./Scripts/verify.sh` (exit 0) và `swift test` (8 Swift Testing tests pass). Interactive macOS QA trên MacBookPro18,3/macOS 26.5.1/Xcode 26.0.1 đã pass cold launch, menu recovery, Settings/Diagnostics độc lập, unavailable intents, restart, quit/relaunch và activate/deactivate. Sleep/wake thật chưa chạy để không ép shared desktop ngủ; F1 vẫn mở và cần người dùng hoàn tất scenario đó trước khi đóng phase.
