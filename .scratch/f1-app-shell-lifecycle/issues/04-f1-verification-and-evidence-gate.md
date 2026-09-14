# 04: F1 verification and evidence gate

**What to build:** Nhóm có bằng chứng đáng tin cậy để quyết định F1 hoàn thành: test tự động đi qua composite verification seam và manual macOS QA chứng minh App shell vẫn usable trong các lifecycle scenario. Evidence phân biệt rõ kết quả đã pass, scenario bị bỏ qua và phần ngoài phạm vi F1.

**Blocked by:** 02 — Independent placeholder scenes; 03 — Lifecycle and launch-at-login adapter.

**Status:** ready-for-agent

- [ ] Composite verification hiện có chạy xanh sau thay đổi F1, bao gồm build, test, documentation checks và secret scan.
- [ ] Automated coordinator/menu/lifecycle tests pass và chỉ kiểm tra observable behavior.
- [ ] Manual macOS evidence ghi Mac model, macOS/Xcode version, ngày, tester và kết quả cold launch, scene reachability, unavailable intents, restart, quit/relaunch, sleep/wake, activation/deactivation.
- [ ] F1 evidence không đánh dấu complete khi một scenario áp dụng còn pending hoặc không có lý do/evidence.
