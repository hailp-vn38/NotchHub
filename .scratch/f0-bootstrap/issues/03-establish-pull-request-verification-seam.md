# 03: Establish pull-request verification seam

**What to build:** Mỗi pull request có một CI workflow chung chứng minh clean checkout resolve được dependency, format, build, test, kiểm tra Markdown links và rà secret trong phần thay đổi; một green run là evidence cho workflow mà contributor chạy local.

**Blocked by:** 01 — Bootstrap project spine; 02 — Deliver pure NotchDomain contracts.

**Status:** ready-for-agent

- [x] CI dùng toolchain pin tương ứng và chạy trên pull request.
- [x] CI chạy formatter, build, pure-domain test, Markdown-link validation và changed-file secret check.
- [x] Lệnh local documented và lệnh CI cho cùng kết quả tại composite verification seam.

## Comments

- Implemented in the pull-request workflow and `Scripts/verify.sh`. Ticket 04 records the phase-level F0 evidence gate.
