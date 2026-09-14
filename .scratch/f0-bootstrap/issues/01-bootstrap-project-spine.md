# 01: Bootstrap project spine

**What to build:** Một clean checkout có thể build foundation macOS tối thiểu bằng root Swift package, sáu platform target, Xcode application host, toolchain pin và formatter đã chọn. Contributor có một lệnh local được ghi nhận để kiểm chứng scaffold mà không cần suy đoán môi trường.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [x] Toolchain pin và formatter configuration được commit, có lệnh local chạy được.
- [x] Root package, sáu target và application host build thành công từ clean checkout.
- [x] Hướng dependency vẫn một chiều về NotchDomain và không có hành vi F1+.

## Answer

Đã thêm package spine, Xcode host composition, formatter và `./Scripts/verify.sh`. CI và pure-domain contracts tiếp tục thuộc tickets 03 và 02.
