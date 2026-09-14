# 04: Close the F0 evidence gate

**What to build:** Foundation F0 có evidence kiểm chứng được cho build, unit test, import boundary, formatter, documentation và CI; documentation trạng thái nói đúng những gì đã được triển khai để phase tiếp theo không dựa vào giả định.

**Blocked by:** 02 — Deliver pure NotchDomain contracts; 03 — Establish pull-request verification seam.

**Status:** resolved

- [x] Evidence cho clean build, pure-domain test, import boundary, formatter, Markdown links và CI được ghi nhận với lệnh/run thực tế.
- [x] Setup guide dùng lệnh build/test/format thực tế thay cho placeholder.
- [x] README, documentation index và F0 spec phản ánh F0 hoàn thành chỉ khi toàn bộ exit gate đạt.

## Comments

`VERIFY_BASE_REF=HEAD^ ./Scripts/verify.sh` passed on 2026-09-14 with Xcode 26.0.1. The
command covers the F0 build, pure-domain tests, boundary, formatter, Markdown-link, and
changed-file-secret gates. The pull-request workflow invoked the same seam successfully in
[run 34806909974](https://github.com/hailp-vn38/NotchHub/actions/runs/34806909974). Full results
and scope limits are recorded in [F0 evidence](../../../docs/quality/f0-evidence.md).
