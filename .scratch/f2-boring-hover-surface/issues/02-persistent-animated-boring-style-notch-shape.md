# 02: Persistent animated Boring-style Notch shape

**What to build:** Người dùng thấy collapsed Surface dựa trên physical-notch hoặc fallback an toàn, sau đó morph liên tục thành fixed expanded Surface với silhouette Boring-style, radii và animation đã chốt; không còn capsule có text hoặc hosting root bị thay theo state.

**Blocked by:** 01 — Coordinator admission contract.

**Status:** ready-for-human

- [x] Closed shape có top shoulder/bottom radius 6/14; expanded shape có 19/24; cùng một clean-room shape animate được giữa hai trạng thái và không là rounded rectangle.
- [x] Một persistent presentation hierarchy render projection từ coordinator, dùng fixed expanded visual 640 × 190 pt trong host admitted 640 × 210 pt, top seam/shadow, và collapsed physical-notch/fallback geometry.
- [x] Open dùng spring 0.42/0.80, close 0.45/1.00, expanded content scale 0.8 từ top kèm opacity, và Reduce Motion thay bằng feedback ngắn không overshoot.
- [x] Automated geometry/state tests xác nhận collapsed physical-notch/fallback geometry và fixed expanded/host sizes.
- [ ] Native visual QA xác nhận không frame jump, không host swap, không stale settle resize sau reopen.

## Comments

- Implementation: `d7a9ae5 feat(surface): add animated notch shape` and `67d5d09 fix(surface): retain presentation task ownership`.
- Evidence: `2fb3870 docs(surface): record animated shape evidence`; `swift build`, focused package tests, and `Scripts/verify.sh` passed.
- Manual QA remains required on a physical-notch Mac, including shape/morph, rapid reopen during host settle, and Reduce Motion. The ticket therefore awaits a human QA run rather than being marked closed.
