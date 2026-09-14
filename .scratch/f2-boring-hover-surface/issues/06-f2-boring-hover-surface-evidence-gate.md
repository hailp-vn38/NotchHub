# 06: F2 Boring-hover Surface evidence gate

**What to build:** Maintainer có evidence đủ mạnh để xác nhận Boring-inspired hover Surface hoàn tất: contract tests, native visual/input/accessibility/lifecycle QA và F2 evidence phân biệt rõ kết quả tự động với proof trên macOS thật.

**Blocked by:** 01 — Coordinator admission contract; 02 — Persistent animated Boring-style Notch shape; 03 — Native shape-aware click-through; 04 — Hover interaction session and holds; 05 — Accessible Surface lifecycle integration.

**Status:** ready-for-agent

- [ ] Full automated suite cover admission/capability revision, shape/animation state, pointer click-through, holds, recovery và regressions F2.
- [ ] Manual evidence trên physical-notch hardware cover visual morph, fixed size, no frame jump, hover grace/re-entry, click-through, focus, VoiceOver, Reduce Motion, Spaces/full-screen/sleep/display behavior và rapid reopen.
- [ ] Undersized valid topology evidence chứng minh hover silent, click/keyboard accessible feedback, Diagnostics event và không recovery; no-notch behavior được xác nhận hoặc giới hạn được ghi rõ.
- [ ] F2 evidence artifact ghi command/result, hardware/macOS/display context, các gate chưa chạy và không đồng nhất build/unit pass với native runtime pass.
