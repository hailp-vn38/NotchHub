# 03: Native shape-aware click-through

**What to build:** Người dùng có thể click xuyên transparent corner và shadow envelope của Notch surface mà vẫn quay lại mở/tương tác visible shape đáng tin cậy, kể cả sau khi panel đã chuyển sang ignore mouse events.

**Blocked by:** 02 — Persistent animated Boring-style Notch shape.

**Status:** ready-for-human

- [x] Panel-owned pointer monitoring dùng local/global pointer state và visible shape geometry thay vì chỉ dựa vào SwiftUI hover.
- [x] Native panel ignore mouse events ngoài visible shape, re-enable khi pointer vào lại, và re-evaluate đồng bộ sau thay đổi state, geometry hoặc capture.
- [x] Native mouse-capture lease giữ event ownership trong drag/control tracking rồi trả click-through an toàn khi interaction kết thúc.
- [ ] Adapter tests và manual QA cover transparent corners, shadow envelope, re-entry, collapsed/suppressed safety và không chặn UI của app khác.

## Implementation Notes

- Implemented in commit `4ce7c85`.
- Added pure shape hit-testing coverage for visible center, transparent corner, and host envelope.
- `swift test` passes all 38 tests and `Scripts/verify.sh` passes.
- Remaining: manual QA on physical-notch hardware for pointer re-entry, collapsed/suppressed safety, and unrelated-app click-through.
