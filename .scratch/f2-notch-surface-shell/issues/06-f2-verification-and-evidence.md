# 06: F2 end-to-end verification and evidence

**What to build:** Người dùng và reviewer có bằng chứng rằng Notch surface F2 hoạt động trên MacBook notch thật, ngoài các contract tests tự động. Evidence phân biệt build/test với QA macOS và ghi rõ mọi giới hạn phần cứng hoặc scenario chưa chạy.

**Blocked by:** 02 — Bounded surface interaction; 03 — Explicit Detail view route; 05 — Context suppression and bounded recovery.

**Status:** ready-for-human

- [x] Composite repository verification và automated coordinator/geometry tests pass cho toàn bộ F2 slice.
- [ ] Manual QA ghi nhận interaction, Detail view, geometry, Spaces, full-screen, sleep/wake, lock/unlock, attach/detach, lid, scale, debug overlay và repeated open/close trên supported MacBook notch.
- [x] No-notch fallback có automated geometry proof; manual limitation được ghi rõ nếu không có hardware.
- [x] F2 evidence ghi Mac model, macOS, Xcode, build context, result từng scenario và mọi scenario unrun; không coi build hoặc mock là manual proof.

## Comments

- 2026-09-14: `VERIFY_BASE_REF=69d58a5^ ./Scripts/verify.sh` passed, including 32 Swift Testing tests and the Debug macOS build. `docs/quality/f2-evidence.md` records the physical-notch host and the no-notch automated proof. Native scenarios remain unrun because this session lacks Computer Use/accessibility permission to operate or inspect the app; the ticket is ready for human QA rather than resolved.
